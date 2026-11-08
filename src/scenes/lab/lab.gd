## The Combat Lab screen (docs/COMBAT_LAB.md Part 1): fight list, party picker,
## preset picker and the Levers panel. Fights run in a throwaway run; the real
## one is parked in LabSession and comes back when you leave.
extends Control

const Session := preload("res://src/core/lab/lab_session.gd")
const Setup := preload("res://src/core/lab/lab_setup.gd")
const Rules := preload("res://src/core/combat/rules.gd")
const LeverPanel := preload("res://src/scenes/lab/lever_panel.gd")
const Modal := preload("res://src/scenes/ui/modal.gd")
const CardRules := preload("res://src/core/card.gd")
const SCENE := "res://src/scenes/lab/lab.tscn"

var _db: Dictionary
var _left: VBoxContainer
var _middle: VBoxContainer
var _levers: LeverPanel
var _preset_box: HFlowContainer
var _save_edit: LineEdit


func _ready() -> void:
	_db = DataDB.all()
	Session.reset_ab()
	if Session.fight_id == "":
		Session.fight_id = str(Setup.cfg(_db).get("defaultFight", ""))
	if Session.preset_id == "":
		Session.preset_id = str(Setup.cfg(_db).get("defaultPreset", "cl_base"))
	var bg := ColorRect.new()
	bg.color = UiTheme.color("bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var view := Display.size_f()
	var title := UiTheme.role_label(Strings.t("lab.title"), "title", UiTheme.ACCENT)
	title.position = Vector2(6, 2)
	add_child(title)
	var back := UiTheme.button(Strings.t("lab.back"), leave)
	back.position = Vector2(view.x - 60, 2)
	add_child(back)
	var third := (view.x - 2.0 * 8.0) / 3.0
	var top := 24.0
	_left = _column(Vector2(4, top), Vector2(third, view.y - top - 4))
	_middle = _column(Vector2(8 + third, top), Vector2(third, view.y - top - 4))
	var right := _column(Vector2(12 + 2 * third, top), Vector2(third, view.y - top - 4))
	_levers = LeverPanel.new()
	_levers.changed.connect(_on_lever)
	right.add_child(UiTheme.label(Strings.t("lab.levers"), UiTheme.ACCENT))
	right.add_child(_levers)
	_fill()
	Audio.play_music("title")


func _column(pos: Vector2, size_in: Vector2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = size_in
	p.size = size_in
	add_child(p)
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.custom_minimum_size = size_in - Vector2(8, 8)
	p.add_child(s)
	var b := VBoxContainer.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(b)
	return b


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _fill() -> void:
	_fill_fights()
	_fill_party_and_presets()
	var base := Rules.values_for(_db, Session.preset_id)
	var vals := base.duplicate()
	vals.merge(Session.overrides, true)
	_levers.show_levers(vals, base)


func _select(b: Button, on: bool) -> void:
	b.theme_type_variation = "SelectedButton" if on else ""


func _wrap_button(text: String, cb: Callable) -> Button:
	var b := UiTheme.button(text, cb)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.x = 8
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _fill_fights() -> void:
	_clear(_left)
	_left.add_child(UiTheme.label(Strings.t("lab.fights"), UiTheme.ACCENT))
	for f in Setup.fights(_db):
		var fid := str(f["id"])
		var b := _wrap_button(str(f.get("name", fid)), func() -> void:
			Session.fight_id = fid
			Session.picks = []
			_fill())
		b.tooltip_text = str(f.get("text", ""))
		_select(b, fid == Session.fight_id)
		_left.add_child(b)
	var cur := Setup.fight(_db, Session.fight_id)
	if not cur.is_empty():
		var t := UiTheme.label(str(cur.get("text", "")), UiTheme.DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_left.add_child(t)
	var play := UiTheme.button(Strings.t("lab.play"), func() -> void: start_fight())
	play.name = "PlayButton"
	_left.add_child(play)
	_left.add_child(UiTheme.button(Strings.t("lab.play_ab"), _ask_ab))
	var series: Array = _db.get("lab/lab", {}).get("abShortlist", {}).get("steps", [])
	if not series.is_empty() and series.all(func(st: Dictionary) -> bool: return str(st["a"]) == "winner" or not Rules.preset_rec(_db, str(st["a"])).is_empty()):
		var sb := UiTheme.button(Strings.t("lab.play_shortlist"), func() -> void:
			if Session.start_series(series):
				start_fight())
		sb.tooltip_text = str(_db.get("lab/lab", {}).get("abShortlist", {}).get("text", ""))
		_left.add_child(sb)
	play.grab_focus.call_deferred()


func _picks() -> Array:
	if Session.picks.is_empty():
		Session.picks = Setup.picks_for(_db, Setup.fight(_db, Session.fight_id)).duplicate(true)
	return Session.picks


func _fill_party_and_presets() -> void:
	_clear(_middle)
	_middle.add_child(UiTheme.label(Strings.t("lab.presets"), UiTheme.ACCENT))
	for p in Rules.presets(_db):
		var pid := str(p["id"])
		var b := _wrap_button(str(p.get("name", pid)), func() -> void:
			Session.preset_id = pid
			Session.overrides = {}
			_fill())
		b.tooltip_text = str(p.get("text", ""))
		_select(b, pid == Session.preset_id)
		_middle.add_child(b)
	if not Session.overrides.is_empty():
		_middle.add_child(UiTheme.label(Strings.t("lab.levers_changed") % Session.overrides.size(), UiTheme.GOOD))
		_save_edit = LineEdit.new()
		_save_edit.placeholder_text = Strings.t("lab.save_name")
		_middle.add_child(_save_edit)
		_middle.add_child(UiTheme.button(Strings.t("lab.save_preset"), _save_preset))
	_middle.add_child(UiTheme.label(Strings.t("lab.party"), UiTheme.ACCENT))
	var classes: Array = []
	for c in _db.get("classes", {}).get("classes", []):
		if int(c.get("tier", 1)) == 1:
			classes.append(str(c["id"]))
	var picks := _picks()
	for i in picks.size():
		var pick: Dictionary = picks[i]
		var idx := i
		var r := HFlowContainer.new()
		r.add_child(UiTheme.button(str(pick.get("class", "?")).capitalize(), func() -> void:
			pick["class"] = classes[(classes.find(str(pick.get("class", ""))) + 1) % classes.size()]
			pick.erase("deck")
			_fill()))
		r.add_child(UiTheme.button("-", func() -> void:
			pick["level"] = maxi(1, int(pick.get("level", 1)) - 1)
			_fill()))
		r.add_child(UiTheme.label(Strings.t("lab.level") % int(pick.get("level", 1))))
		r.add_child(UiTheme.button("+", func() -> void:
			pick["level"] = mini(int(Setup.cfg(_db).get("maxLevel", 10)), int(pick.get("level", 1)) + 1)
			_fill()))
		r.add_child(UiTheme.button(Strings.t("lab.deck"), func() -> void: _edit_deck(idx)))
		if picks.size() > 1:
			r.add_child(UiTheme.button("x", func() -> void:
				picks.remove_at(idx)
				_fill()))
		_middle.add_child(r)
	if picks.size() < int(Setup.cfg(_db).get("partySize", 4)):
		_middle.add_child(UiTheme.button(Strings.t("lab.add_member"), func() -> void:
			picks.append({ "class": classes[picks.size() % classes.size()], "level": 3 })
			_fill()))


func _on_lever(key: String, value: Variant) -> void:
	var base := Rules.values_for(_db, Session.preset_id)
	if base.get(key) == value:
		Session.overrides.erase(key)
	else:
		Session.overrides[key] = value
	_fill_party_and_presets()


## Save the changed levers as a new preset, in user://lab/presets.json (loaded on top of the data file).
func _save_preset() -> void:
	var nm := _save_edit.text.strip_edges()
	if nm == "":
		return
	var id := nm.to_lower().replace(" ", "_")
	var vals: Dictionary = _db.get("lab/presets", {})
	var rec := { "id": id, "name": nm, "text": Strings.t("lab.saved_from") % Session.preset_id, "levers": Rules.diff({}, _merged()), "saved": true }
	var list: Array = vals.get("presets", [])
	for i in list.size():
		if str(list[i].get("id", "")) == id:
			list.remove_at(i)
			break
	list.append(rec)
	preload("res://src/core/lab/lab_presets.gd").save(list)
	Session.preset_id = id
	Session.overrides = {}
	_fill()


func _merged() -> Dictionary:
	var vals := Rules.values_for(_db, Session.preset_id)
	vals.merge(Session.overrides, true)
	return vals


## Quick-edit a member's deck: tap a card to take it out, or add from the list.
func _edit_deck(idx: int) -> void:
	var pick: Dictionary = _picks()[idx]
	var rules: RefCounted = Rules.build(_db, Session.preset_id, Session.overrides)
	var fake := { "deck": _db.get("classes", {}).get("classes", []).filter(func(c: Dictionary) -> bool: return str(c["id"]) == str(pick.get("class", "")))[0].get("starterDeck", []) }
	var deck: Array = Setup.deck_for(_db, pick, rules, fake)
	var m := Modal.new()
	m.build(Strings.t("lab.deck_title") % str(pick.get("class", "")).capitalize(), 420)
	var draw := func(self_ref: Callable) -> void:
		m.clear_body()
		m.text(Strings.t("lab.deck_cards") % deck.size(), UiTheme.ACCENT)
		var inn := m.row()
		for i in deck.size():
			var k := i
			var c := CardRules.resolve(_db, str(deck[i]))
			var b := UiTheme.button(str(c.get("name", deck[i])), func() -> void:
				deck.remove_at(k)
				self_ref.call(self_ref))
			b.tooltip_text = str(c.get("text", ""))
			inn.add_child(b)
		m.text(Strings.t("lab.deck_add"), UiTheme.ACCENT)
		var out := m.row()
		for c in _addable():
			var cid := str(c["id"])
			var b := UiTheme.button(str(c.get("name", cid)), func() -> void:
				deck.append(cid)
				self_ref.call(self_ref))
			b.tooltip_text = str(c.get("text", ""))
			out.add_child(b)
		m.add_button(Strings.t("lab.deck_done"), func() -> void: m.finish(deck))
		m.add_button(Strings.t("lab.deck_reset"), func() -> void: m.finish(null))
	draw.call(draw)
	var r: Variant = await Flow.show_modal(m)
	if r == null:
		pick.erase("deck")
	else:
		pick["deck"] = r
	_fill()


func _addable() -> Array:
	var out: Array = []
	for key in ["cards/lab_cards", "cards/basic_cards"]:
		out.append_array(_db.get(key, {}).get("cards", []))
	return out


func _ask_ab() -> void:
	var m := Modal.new()
	m.build(Strings.t("lab.ab_title"), 300)
	m.text(Strings.t("lab.ab_pick"))
	var chosen: Array = []
	for p in Rules.presets(_db):
		var pid := str(p["id"])
		var b := m.add_button(str(p.get("name", pid)), func() -> void: pass)
		b.pressed.connect(func() -> void:
			if chosen.has(pid):
				return
			chosen.append(pid)
			_select(b, true)
			if chosen.size() == 2:
				m.finish(chosen))
	m.add_button(Strings.t("lab.back"), func() -> void: m.finish(null))
	var r: Variant = await Flow.show_modal(m)
	if r != null:
		Session.start_ab(Session.fight_id, str(r[0]), str(r[1]))
		start_fight()


func leave() -> void:
	exit_lab()


## Back where the Lab was opened from, with the real run restored.
static func exit_lab() -> void:
	GameState.pending_combat = {}
	var dest := Session.parked_scene
	if Session.has_parked:
		GameState.run = Session.parked
	Session.parked = {}
	Session.has_parked = false
	Session.parked_scene = ""
	SceneRouter.goto(dest if dest != "" else "res://src/scenes/title/title.tscn")


## Open the Lab from anywhere, parking the current run.
static func open_lab() -> void:
	if not Session.has_parked:
		Session.parked = GameState.run
		Session.has_parked = true
		var cur := GameState.get_tree().current_scene
		Session.parked_scene = cur.scene_file_path if cur != null else ""
	SceneRouter.goto(SCENE)


## Start the selected fight (or the A/B stage) in a throwaway run.
static func start_fight(seed_override: int = -1) -> void:
	var db: Dictionary = DataDB.all()
	var preset := Session.ab_preset() if not Session.ab.is_empty() else Session.preset_id
	var over: Dictionary = {} if not Session.ab.is_empty() else Session.overrides
	var built := Setup.build(db, Session.fight_id, preset, over, Session.picks, seed_override, { "mastery": Session.mastery, "labRelics": Session.relics })
	GameState.run = built["run"]
	GameState.start_combat(built["setup"], SCENE)

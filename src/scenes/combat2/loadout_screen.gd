## The Combat 2.0 loadout screen (docs/COMBAT_2.md Part 4): one page per
## character, slots on the left, the collection on the right with filters
## (Vector, shape, tag), hover to compare, synergy hints and three saved
## loadouts. At a rest room each character may swap once; then the night goes on.
extends Control

const Flow := preload("res://src/scenes/combat2/c2_flow.gd")
const Loadout := preload("res://src/core/combat2/loadout.gd")
const Kits := preload("res://src/core/combat2/kits.gd")
const C2Rules := preload("res://src/core/combat2/c2_rules.gd")

const KINDS := ["moves", "spells", "perks", "ultimate", "weapon", "armor", "trinket1", "trinket2"]

var _db: Dictionary
var _rules: C2Rules
var _char := ""
var _kind := "moves"
var _filter := { "vector": "", "shape": "", "tag": "" }
var _left: VBoxContainer
var _right: VBoxContainer
var _note: Label


func _ready() -> void:
	_db = DataDB.all()
	_rules = C2Rules.build(_db) as C2Rules
	var ids: Array = Flow.party_ids(_db)
	_char = str(ids[0]) if not ids.is_empty() else ""
	var bg := ColorRect.new()
	bg.color = UiTheme.color("bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var view := Display.size_f()
	var title := UiTheme.role_label(Strings.t("c2.loadout_title") % Flow.level, "title", UiTheme.ACCENT)
	title.position = Vector2(6, 2)
	add_child(title)
	var done_text := Strings.t("c2.leave_rest") if Flow.at_rest else Strings.t("lab.back")
	var done := UiTheme.button(done_text, func() -> void:
		if Flow.at_rest:
			Flow.leave_rest()
		else:
			SceneRouter.goto(Flow.MENU))
	done.name = "DoneButton"
	done.position = Vector2(view.x - 90, 2)
	add_child(done)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(6, 22)
	tabs.name = "CharTabs"
	add_child(tabs)
	for cid in ids:
		var c := str(cid)
		tabs.add_child(UiTheme.button(str(Kits.character(_db, c).get("name", c)), func() -> void:
			_char = c
			_fill()))
	_note = UiTheme.label("", UiTheme.DIM)
	_note.position = Vector2(6, 38)
	_note.size = Vector2(view.x - 12, 22)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_note)
	var half := (view.x - 18.0) / 2.0
	_left = _column(Vector2(6, 62), Vector2(half, view.y - 66))
	_right = _column(Vector2(12 + half, 62), Vector2(half, view.y - 66))
	_fill()


func _column(pos: Vector2, size_in: Vector2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = size_in
	add_child(p)
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(s)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(box)
	return box


func _lo() -> Dictionary:
	return Flow.loadout(_db, _char)


func _can_change() -> bool:
	return Loadout.can_swap(Flow.swap_place(), int(Flow.rest_swaps.get(_char, 0)))


func _fill() -> void:
	for box in [_left, _right]:
		for c in box.get_children():
			c.queue_free()
	var lo := _lo()
	var sl := Kits.slots(_rules, Flow.level)
	var syn := Loadout.synergies(_db, lo)
	var hints: Array = syn.slice(0, 3).map(func(s: Dictionary) -> String: return "%s + %s (%s)" % [s["a"], s["b"], s["tag"]])
	_note.text = (Strings.t("c2.synergy") % ", ".join(PackedStringArray(hints)) if not hints.is_empty() else Strings.t("c2.no_synergy"))
	if Flow.at_rest:
		_note.text += "  " + (Strings.t("c2.rest_swap_left") if _can_change() else Strings.t("c2.rest_swap_used"))
	_left.add_child(UiTheme.label(Strings.t("c2.equipped") % str(Kits.character(_db, _char).get("name", _char)), UiTheme.ACCENT))
	for kind in ["moves", "spells", "perks"]:
		var list: Array = lo.get(kind, [])
		_left.add_child(UiTheme.label("%s %d/%d" % [Strings.t("c2.kind_" + kind), list.size(), int(sl[kind])], UiTheme.DIM))
		for id in list:
			_left.add_child(_piece_button(kind, str(id), true))
	_left.add_child(UiTheme.label(Strings.t("c2.kind_ultimate"), UiTheme.DIM))
	_left.add_child(_piece_button("ultimate", str(lo.get("ultimate", "")), true))
	for slot in ["weapon", "armor", "trinket1", "trinket2"]:
		_left.add_child(UiTheme.label(Strings.t("c2.kind_" + slot.rstrip("12")), UiTheme.DIM))
		var gid := str(lo.get("gear", {}).get(slot, ""))
		_left.add_child(_piece_button(slot, gid, true) if gid != "" else UiTheme.label("-", UiTheme.DIM))
	var saves := HBoxContainer.new()
	for i in Loadout.SAVED_MAX:
		var idx := i
		saves.add_child(UiTheme.button(Strings.t("c2.save_n") % (i + 1), func() -> void:
			Flow.saved = Loadout.save_slot(Flow.saved, _char, idx, _lo())
			Flow.save_file()
			_fill()))
		var slot_lo: Dictionary = (Flow.saved.get(_char, [{}, {}, {}]) as Array)[i] if (Flow.saved.get(_char, []) as Array).size() > i else {}
		var lb := UiTheme.button(Strings.t("c2.load_n") % (i + 1), func() -> void:
			if Loadout.problems(_db, _rules, _char, Flow.level, slot_lo).is_empty() and _can_change():
				_apply(slot_lo))
		lb.disabled = slot_lo.is_empty()
		saves.add_child(lb)
	_left.add_child(saves)
	_fill_collection(lo)


func _fill_collection(lo: Dictionary) -> void:
	var kinds := HFlowContainer.new()
	for k in KINDS:
		var kk := str(k)
		var b := UiTheme.button(Strings.t("c2.kind_" + kk.rstrip("12")), func() -> void:
			_kind = kk
			_fill())
		b.disabled = kk == _kind
		kinds.add_child(b)
	_right.add_child(kinds)
	var col := Loadout.collection(_db, _char)
	var ids: Array
	match _kind:
		"moves", "spells", "perks":
			ids = col[_kind]
		"ultimate":
			ids = col["ultimates"]
		_:
			ids = col["gear"][_kind.rstrip("12")]
	var filters := HFlowContainer.new()
	for spec in [["vector", ["", "heat", "cold", "lightning", "force", "sound", "shadow", "poison"]], ["tag", ["", "wall-slammer", "protector", "weakness hunter", "terrain controller", "back-stabber", "scout", "baton conductor", "tempo"]]]:
		var key := str(spec[0])
		for v in spec[1]:
			var val := str(v)
			var b := UiTheme.button(val if val != "" else Strings.t("c2.any_" + key), func() -> void:
				_filter[key] = val
				_fill())
			b.disabled = str(_filter[key]) == val
			filters.add_child(b)
	_right.add_child(filters)
	if _kind in ["moves", "spells", "perks"]:
		ids = Loadout.filter(_db, ids, _kind, _filter)
	for id in ids:
		_right.add_child(_piece_button(_kind, str(id), false))


func _record(kind: String, id: String) -> Dictionary:
	match kind:
		"moves":
			return Kits.move(_db, id)
		"spells":
			return Kits.spell(_db, id)
		"perks":
			return Kits.perk(_db, id)
		"ultimate":
			return Kits.ultimate(_db, id)
	return Kits.gear(_db, id)


func _piece_button(kind: String, id: String, equipped: bool) -> Button:
	var r := _record(kind, id)
	var b := UiTheme.button(("- " if equipped else "+ ") + str(r.get("name", id)), func() -> void: _toggle(kind, id))
	var tip := str(r.get("text", ""))
	if tip == "":
		tip = "%s %s, power %s, cooldown %s" % [str(r.get("shape", "")), str(r.get("type", ", ".join(PackedStringArray(r.get("vectors", []))))), str(r.get("power", r.get("heal", r.get("shield", "-")))), str(r.get("cooldown", 0))]
	if kind == "spells" and not r.is_empty():
		tip += "\n%d charges a night" % Kits.charges_for(_db, _rules, r, Kits.effects_of(_db, _lo()))
	b.tooltip_text = tip
	if not equipped:
		var lo := _lo()
		var on: bool = (lo.get(kind, []) as Array).has(id) if kind in ["moves", "spells", "perks"] else (str(lo.get("ultimate", "")) == id if kind == "ultimate" else str(lo.get("gear", {}).get(kind, "")) == id)
		b.disabled = on or not _can_change()
	return b


func _toggle(kind: String, id: String) -> void:
	if not _can_change():
		return
	var out := Loadout.toggle(_db, _rules, _char, Flow.level, _lo(), kind, id)
	if out.is_empty():
		_note.text = Strings.t("c2.no_room")
		return
	_apply(out)


func _apply(lo: Dictionary) -> void:
	Flow.set_loadout(_char, lo)
	if Flow.at_rest:
		Flow.rest_swaps[_char] = int(Flow.rest_swaps.get(_char, 0)) + 1
	_fill()

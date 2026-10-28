## Title screen: New run (pick a class, optional seed), Continue, Quit.
## The Narrator's Journal and other meta options hook in via `extra_buttons`.
extends Control

const Modal := preload("res://src/scenes/ui/modal.gd")
const Char := preload("res://src/core/character.gd")
const TOWN_SCENE := "res://src/scenes/town/town.tscn"

static var extra_buttons: Array = []   # [{ "label", "run": Callable }]

var _menu: VBoxContainer
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Flow.set_hud(false)
	var title := UiTheme.role_label(Strings.t("title.project_vector"), "title", UiTheme.ACCENT)
	title.position = Vector2((Display.base.x - 180) / 2.0, 50)
	title.size = Vector2(180, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := UiTheme.label(Strings.t("title.a_small_town_a_big"), UiTheme.DIM)
	sub.position = Vector2((Display.base.x - 300) / 2.0, 74)
	sub.size = Vector2(300, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	_menu = VBoxContainer.new()
	_menu.position = Vector2((Display.base.x - 120) / 2.0, 110)
	_menu.custom_minimum_size = Vector2(120, 0)
	add_child(_menu)
	_menu.add_child(UiTheme.button(Strings.t("title.new_run"), _new_run))
	var cont := UiTheme.button(Strings.t("title.continue"), _continue)
	cont.disabled = not SaveSystem.has_save()
	_menu.add_child(cont)
	for extra in extra_buttons:
		var e: Dictionary = extra
		_menu.add_child(UiTheme.button(str(e["label"]), func() -> void: e["run"].call()))
	_menu.add_child(UiTheme.button(Strings.t("title.endless_arena"), _arena))
	_menu.add_child(UiTheme.button(Strings.t("title.narrator_s_journal"), _show_journal))
	_menu.add_child(UiTheme.button(Strings.t("title.quit"), func() -> void: get_tree().quit()))
	(_menu.get_child(1 if not cont.disabled else 0) as Button).grab_focus()
	Audio.play_music("title")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var view := Display.size_f()
	var ground := roundf(view.y * 0.73)
	var bands := 14
	var band_h := ceilf(view.y / float(bands))
	for i in bands:
		var c := Color("120c22").lerp(Color("4a2c5e"), float(i) / float(bands - 1))
		draw_rect(Rect2(0, i * band_h, view.x, band_h + 1), c)
	draw_rect(Rect2(0, ground, view.x, view.y - ground), Color("0d0a14"))
	var x := 0.0
	var i := 0
	while x < view.x:
		var w := 18.0 + float((i * 37) % 21)
		var h := 18.0 + float((i * 53) % 34)
		draw_rect(Rect2(x, ground - h, w - 2, h), Color("1d1530"))
		if (i * 7) % 3 == 0:
			var glow := 0.5 + 0.5 * sin(_t * 1.7 + float(i))
			draw_rect(Rect2(x + 4, ground - h + 5, 3, 3), Color("ffd966").darkened(0.6 - glow * 0.3))
		x += w
		i += 1
	# The town's reflection: the Upside-Down, faintly, below the line.
	x = 0.0
	i = 0
	while x < view.x:
		var w := 18.0 + float((i * 37) % 21)
		var h := 18.0 + float((i * 53) % 34)
		draw_rect(Rect2(x, ground + 2, w - 2, h * 0.6), Color("2a0f22", 0.6 + 0.2 * sin(_t + float(i))))
		x += w
		i += 1


func _continue() -> void:
	if SaveSystem.load_run():
		SceneRouter.goto(str(GameState.run.get("resume_scene", TOWN_SCENE)))


func _new_run() -> void:
	var m := Modal.new()
	m.build(Strings.t("title.who_are_you_new_kid"), 420)
	var db: Dictionary = DataDB.all()
	m.text(Strings.t("title.pick_a_starting_class_you"), UiTheme.DIM)
	var seed_row := m.row()
	seed_row.add_child(UiTheme.label(Strings.t("title.seed_blank_random")))
	var seed_edit := LineEdit.new()
	seed_edit.custom_minimum_size = Vector2(100, 0)
	seed_row.add_child(seed_edit)
	# Combat difficulty (data/combat_rules.json "difficulties"): Hard enemies move, then attack.
	var diff := { "id": str(db.get("combat_rules", {}).get("difficulty", "normal")) }
	var diff_row := m.row()
	diff_row.add_child(UiTheme.label(Strings.t("title.combat")))
	var diff_buttons: Array = []
	var diffs: Dictionary = db.get("combat_rules", {}).get("difficulties", {})
	for d in diffs:
		if str(d) == "comment":
			continue
		var did := str(d)
		var b := UiTheme.button(str(diffs[d].get("name", did.capitalize())), func() -> void:
			diff["id"] = did
			for x in diff_buttons:
				(x as Button).theme_type_variation = "SelectedButton" if x.get_meta("id") == did else "")
		b.set_meta("id", did)
		b.theme_type_variation = "SelectedButton" if did == diff["id"] else ""
		b.tooltip_text = Strings.t("title.enemies_show_what_they_ll") % (Strings.t("title.move_and_attack_chance") % roundi(100.0 * _chance(diffs[d].get("enemyMoveAndActChance", 0.0))))
		diff_buttons.append(b)
		diff_row.add_child(b)
	for cls in db.get("classes", {}).get("classes", []):
		if int(cls.get("tier", 1)) != 1:
			continue
		var cid := str(cls["id"])
		var growth: Dictionary = cls.get("growth", {})
		var tops: Array = growth.keys()
		tops.sort_custom(func(a: Variant, b: Variant) -> bool: return float(growth[a]) > float(growth[b]))
		var tip := Strings.t("title.grows_starts_with_vector_s") % [cls["name"], ", ".join(PackedStringArray(tops.slice(0, 3).map(func(s: Variant) -> String: return str(s).to_upper()))),
			int(cls.get("startVectors", 1)), ", ".join(PackedStringArray(cls.get("startForms", []))), str(cls.get("perk", {}).get("text", ""))]
		m.add_button("%s: %s" % [cls["name"], str(cls.get("perk", {}).get("text", ""))], func() -> void:
			var s := -1
			if seed_edit.text.strip_edges().is_valid_int():
				s = int(seed_edit.text.strip_edges())
			m.finish({ "class": cid, "seed": s }), false, tip)
	var unlocked: Array = Journal.unlocked_traits()
	var trait_pick := { "id": "" }
	if not unlocked.is_empty():
		m.text(Strings.t("title.starting_trait_unlocked_by_the"), UiTheme.DIM)
		var trow := HFlowContainer.new()
		trow.custom_minimum_size = Vector2(400, 0)
		m.body.add_child(trow)
		for t in [""] + unlocked:
			var tid := str(t)
			var rec := DataDB.record("traits", tid)
			var b := UiTheme.button(str(rec.get("name", "None")), func() -> void: trait_pick["id"] = tid)
			b.tooltip_text = str(rec.get("text", Strings.t("title.no_trait")))
			trow.add_child(b)
	m.add_button(Strings.t("title.back"), func() -> void: m.finish(null))
	var r: Variant = await Flow.show_modal(m)
	if r == null:
		return
	var pick: Dictionary = r
	SaveSystem.delete_save()
	var traits: Array = [] if str(trait_pick["id"]) == "" else [str(trait_pick["id"])]
	GameState.new_run(int(pick["seed"]), str(pick["class"]), Strings.t("title.new_kid"), { "traits": traits })
	GameState.combat_difficulty = str(diff["id"])
	Narrator.say(Strings.t("title.new_kid_in_a_small"))
	SceneRouter.goto(TOWN_SCENE)


## Endless Arena from the title: a preset party (your class plus others) or the
## party from your save, copied so the story save is never touched.
func _arena() -> void:
	var m := Modal.new()
	m.build(Strings.t("title.endless_arena"), 420)
	var db: Dictionary = DataDB.all()
	m.text(Strings.t("title.fight_wave_after_wave_new"), UiTheme.DIM)
	var size := { "n": 4 }
	var srow := m.row()
	srow.add_child(UiTheme.label(Strings.t("title.party_size")))
	var sbtns: Array = []
	for n in [1, 2, 3, 4]:
		var nn: int = n
		var b := UiTheme.button(str(nn), func() -> void:
			size["n"] = nn
			for x in sbtns:
				(x as Button).theme_type_variation = "SelectedButton" if int(x.get_meta("n")) == nn else "")
		b.set_meta("n", nn)
		b.theme_type_variation = "SelectedButton" if nn == 4 else ""
		sbtns.append(b)
		srow.add_child(b)
	m.text(Strings.t("title.preset_party_pick_your_class"), UiTheme.DIM)
	for cls in db.get("classes", {}).get("classes", []):
		if int(cls.get("tier", 1)) != 1:
			continue
		var cid := str(cls["id"])
		m.add_button(Strings.t("title.play_as") % cls["name"], func() -> void: m.finish({ "class": cid }))
	m.add_button(Strings.t("title.import_the_party_from_my"), func() -> void: m.finish({ "import": true }), not SaveSystem.has_save(),
		Strings.t("title.uses_a_copy_your_story") if SaveSystem.has_save() else Strings.t("title.no_save_yet"))
	m.add_button(Strings.t("title.back"), func() -> void: m.finish(null))
	var r: Variant = await Flow.show_modal(m)
	if r == null:
		return
	var pick: Dictionary = r
	start_arena(pick, int(size["n"]), Rng.stream("creation").randi_range(1, 999999), 3)


## Start an arena run (also used by the --arena dev flag).
static func start_arena(pick: Dictionary, size: int, seed_value: int, level: int, waves_cap: int = 999) -> void:
	const ArenaRules := preload("res://src/core/arena/arena.gd")
	const ArenaParty := preload("res://src/core/arena/arena_party.gd")
	if bool(pick.get("import", false)) and SaveSystem.load_run():
		GameState.run = GameState.run.duplicate(true)
		GameState.run["mode"] = "arena"
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		GameState.new_run(seed_value, str(pick.get("class", "mage")))
		GameState.run = ArenaParty.preset_run(DataDB.all(), seed_value, str(pick.get("class", "mage")), size, level, rng)
	GameState.run.erase("rift")
	GameState.run["arena"] = ArenaRules.new_arena(seed_value, false)
	GameState.run["devArenaWaves"] = waves_cap
	SceneRouter.goto("res://src/scenes/arena/arena.tscn")


func _show_journal() -> void:
	var m := Modal.new()
	m.build(Strings.t("title.the_narrator_s_journal"), 420)
	var j: Dictionary = Journal.data
	m.text(Strings.t("title.runs_furthest_week_endings_seen") % [int(j.get("runs", 0)), int(j.get("bestWeek", 0)), ", ".join(PackedStringArray(j.get("endings", {}).keys())) if not j.get("endings", {}).is_empty() else "none"], UiTheme.DIM)
	m.text(Strings.t("title.lore"), UiTheme.ACCENT)
	if j.get("lore", {}).is_empty():
		m.text(Strings.t("title.nothing_yet_the_narrator_taps"), UiTheme.DIM)
	for k in j.get("lore", {}):
		m.text("- " + str(j["lore"][k]))
	m.text(Strings.t("title.creatures"), UiTheme.ACCENT)
	for k in j.get("enemies", {}):
		var e: Dictionary = j["enemies"][k]
		m.text(Strings.t("title.defeated") % [e.get("name", k), int(e.get("defeated", 0)), e.get("text", "")])
	m.text(Strings.t("title.starting_traits_unlocked") % (", ".join(PackedStringArray(Journal.unlocked_traits())) if not Journal.unlocked_traits().is_empty() else "none"), UiTheme.DIM)
	m.text(Strings.t("title.endless_arena_best_wave") % int(j.get("arena", {}).get("bestWave", 0)), UiTheme.DIM)
	m.add_button(Strings.t("title.close"), func() -> void: m.finish(null))
	await Flow.show_modal(m)


## A difficulty's move-and-attack chance for normal enemies (a number or one per tier).
func _chance(c: Variant) -> float:
	if c is Dictionary:
		return float((c as Dictionary).get("normal", (c as Dictionary).get("default", 0.0)))
	return float(c)

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
	var title := UiTheme.label("Project Vector", UiTheme.ACCENT, UiTheme.TITLE_SIZE)
	title.position = Vector2(150, 50)
	title.size = Vector2(180, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := UiTheme.label("A small town. A big week. Five of them, actually.", UiTheme.DIM)
	sub.position = Vector2(90, 74)
	sub.size = Vector2(300, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	_menu = VBoxContainer.new()
	_menu.position = Vector2(180, 110)
	_menu.custom_minimum_size = Vector2(120, 0)
	add_child(_menu)
	_menu.add_child(UiTheme.button("New run", _new_run))
	var cont := UiTheme.button("Continue", _continue)
	cont.disabled = not SaveSystem.has_save()
	_menu.add_child(cont)
	for extra in extra_buttons:
		var e: Dictionary = extra
		_menu.add_child(UiTheme.button(str(e["label"]), func() -> void: e["run"].call()))
	_menu.add_child(UiTheme.button("Quit", func() -> void: get_tree().quit()))
	(_menu.get_child(1 if not cont.disabled else 0) as Button).grab_focus()
	Audio.play_music("title")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for i in 14:
		var c := Color("120c22").lerp(Color("4a2c5e"), float(i) / 13.0)
		draw_rect(Rect2(0, i * 14, 480, 15), c)
	draw_rect(Rect2(0, 196, 480, 74), Color("0d0a14"))
	var x := 0.0
	var i := 0
	while x < 480.0:
		var w := 16.0 + float((i * 37) % 21)
		var h := 18.0 + float((i * 53) % 34)
		draw_rect(Rect2(x, 196 - h, w - 2, h), Color("1d1530"))
		if (i * 7) % 3 == 0:
			var glow := 0.5 + 0.5 * sin(_t * 1.7 + float(i))
			draw_rect(Rect2(x + 4, 196 - h + 5, 3, 3), Color("ffd966").darkened(0.6 - glow * 0.3))
		x += w
		i += 1
	# The town's reflection: the Upside-Down, faintly, below the line.
	x = 0.0
	i = 0
	while x < 480.0:
		var w := 16.0 + float((i * 37) % 21)
		var h := 18.0 + float((i * 53) % 34)
		draw_rect(Rect2(x, 198, w - 2, h * 0.6), Color("2a0f22", 0.6 + 0.2 * sin(_t + float(i))))
		x += w
		i += 1


func _continue() -> void:
	if SaveSystem.load_run():
		SceneRouter.goto(str(GameState.run.get("resume_scene", TOWN_SCENE)))


func _new_run() -> void:
	var m := Modal.new()
	m.build("Who are you, new kid?", 420)
	var db: Dictionary = DataDB.all()
	m.text("Pick a starting class. You can advance into others at levels 5 and 12.", UiTheme.DIM)
	var seed_row := m.row()
	seed_row.add_child(UiTheme.label("Seed (blank = random):"))
	var seed_edit := LineEdit.new()
	seed_edit.custom_minimum_size = Vector2(100, 0)
	seed_row.add_child(seed_edit)
	for cls in db.get("classes", {}).get("classes", []):
		if int(cls.get("tier", 1)) != 1:
			continue
		var cid := str(cls["id"])
		var growth: Dictionary = cls.get("growth", {})
		var tops: Array = growth.keys()
		tops.sort_custom(func(a: Variant, b: Variant) -> bool: return float(growth[a]) > float(growth[b]))
		var tip := "%s\nGrows: %s\nStarts with: %d Vector(s), %s\nPerk: %s" % [cls["name"], ", ".join(PackedStringArray(tops.slice(0, 3).map(func(s: Variant) -> String: return str(s).to_upper()))),
			int(cls.get("startVectors", 1)), ", ".join(PackedStringArray(cls.get("startForms", []))), str(cls.get("perk", {}).get("text", ""))]
		m.add_button("%s: %s" % [cls["name"], str(cls.get("perk", {}).get("text", ""))], func() -> void:
			var s := -1
			if seed_edit.text.strip_edges().is_valid_int():
				s = int(seed_edit.text.strip_edges())
			m.finish({ "class": cid, "seed": s }), false, tip)
	m.add_button("Back", func() -> void: m.finish(null))
	var r: Variant = await Flow.show_modal(m)
	if r == null:
		return
	var pick: Dictionary = r
	SaveSystem.delete_save()
	GameState.new_run(int(pick["seed"]), str(pick["class"]))
	Narrator.say("New kid in a small town. The narrator clears their throat. That's me. Hi.")
	SceneRouter.goto(TOWN_SCENE)

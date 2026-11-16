## The Combat 2.0 slice menu, opened from the Lab's "Combat 2.0 slice" button
## (docs/COMBAT_2.md Part 5): the six slice fights, the night mode, the level
## (1 or 6) and the loadout screen.
extends Control

const Flow := preload("res://src/scenes/combat2/c2_flow.gd")
const C2Setup := preload("res://src/core/combat2/c2_setup.gd")
const LAB := "res://src/scenes/lab/lab.tscn"

var _db: Dictionary
var _box: VBoxContainer


func _ready() -> void:
	_db = DataDB.all()
	var bg := ColorRect.new()
	bg.color = UiTheme.color("bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var view := Display.size_f()
	var title := UiTheme.role_label(Strings.t("c2.title"), "title", UiTheme.ACCENT)
	title.position = Vector2(6, 2)
	add_child(title)
	var back := UiTheme.button(Strings.t("lab.back"), func() -> void: SceneRouter.goto(LAB))
	back.name = "BackButton"
	back.position = Vector2(view.x - 60, 2)
	add_child(back)
	var panel := PanelContainer.new()
	panel.position = Vector2(6, 24)
	panel.custom_minimum_size = Vector2(view.x - 12, view.y - 30)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	_fill()


func _fill() -> void:
	for c in _box.get_children():
		c.queue_free()
	if Flow.last_result != "":
		_box.add_child(UiTheme.label(Strings.t("c2.last_" + Flow.last_result), UiTheme.GOOD if Flow.last_result == "win" else UiTheme.BAD))
	_box.add_child(UiTheme.label(Strings.t("c2.intro"), UiTheme.DIM))
	var lv := HBoxContainer.new()
	lv.add_child(UiTheme.label(Strings.t("c2.level")))
	for n in [1, 6]:
		var b := UiTheme.button(Strings.t("c2.level_n") % n, func() -> void:
			Flow.level = n
			_fill())
		b.disabled = Flow.level == n
		lv.add_child(b)
	lv.add_child(UiTheme.button(Strings.t("c2.loadouts"), func() -> void:
		Flow.at_rest = false
		SceneRouter.goto(Flow.LOADOUT)))
	_box.add_child(lv)
	_box.add_child(UiTheme.label(Strings.t("c2.fights"), UiTheme.ACCENT))
	for f in C2Setup.fights(_db):
		var fid := str(f["id"])
		var row := HBoxContainer.new()
		var b := UiTheme.button(str(f.get("name", fid)), func() -> void: Flow.start_fight(fid))
		b.name = "Fight_" + fid
		b.tooltip_text = str(f.get("teaches", ""))
		row.add_child(b)
		var t := UiTheme.label(str(f.get("teaches", "")), UiTheme.DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		_box.add_child(row)
	_box.add_child(UiTheme.label(Strings.t("c2.nights"), UiTheme.ACCENT))
	for n in C2Setup.nights(_db):
		var nid := str(n["id"])
		var row := HBoxContainer.new()
		row.add_child(UiTheme.button(str(n.get("name", nid)), func() -> void: Flow.start_night(_db, nid)))
		var t := UiTheme.label(str(n.get("text", "")), UiTheme.DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		_box.add_child(row)

## F1 debug menu, available everywhere. Sections are buttons on the left; each
## fills the content area on the right. Debug actions go through GameState and
## the other autoloads like normal play would.
extends CanvasLayer

const CharSheet := preload("res://src/scenes/ui/character_sheet.gd")
const Lv := preload("res://src/core/progression/leveling.gd")

var _root: PanelContainer
var _content: VBoxContainer
var _sections: Array = []


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = PanelContainer.new()
	_root.position = Vector2(4, 4)
	_root.size = Vector2(472, 262)
	_root.visible = false
	add_child(_root)
	var h := HBoxContainer.new()
	_root.add_child(h)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(70, 0)
	h.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	left.add_child(UiTheme.label("DEBUG (F1)", UiTheme.ACCENT))
	add_section("Character", _show_character, left)
	add_section("Leveling", _show_leveling, left)
	_dev_args.call_deferred()


## Dev hook for screenshots from the command line (after `--`):
##   --scene=res://path.tscn  --debug  --shot=C:/out.png  --frames=30
## --debug opens this menu; --shot saves the viewport after N frames and quits.
func _dev_args() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := str(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if args.has("scene"):
		SceneRouter.goto(str(args["scene"]))
	if args.has("debug"):
		toggle.call_deferred()
	if args.has("shot"):
		for i in int(args.get("frames", "30")):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(str(args["shot"]))
		get_tree().quit()


func add_section(title: String, fill: Callable, parent: Control = null) -> void:
	_sections.append({ "title": title, "fill": fill })
	if parent == null:
		parent = _root.get_child(0).get_child(0)
	parent.add_child(UiTheme.button(title, func() -> void: _open(fill)))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.is_action_pressed("cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		if GameState.player.is_empty():
			GameState.new_run()
		_open(_sections[0]["fill"])


func is_open() -> bool:
	return _root.visible


func _open(fill: Callable) -> void:
	for c in _content.get_children():
		c.queue_free()
	fill.call(_content)


func _show_character(box: VBoxContainer) -> void:
	var sheet := CharSheet.new()
	box.add_child(sheet)
	sheet.show_character(GameState.player, GameState.cards)


func _show_leveling(box: VBoxContainer) -> void:
	var p: Dictionary = GameState.player
	box.add_child(UiTheme.label("Level %d, XP %d / %d" % [int(p.get("level", 1)), int(p.get("xp", 0)), Lv.xp_to_next(DataDB.all(), int(p.get("level", 1)))]))
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(UiTheme.button("+1 level", func() -> void:
		var reports := GameState.give_xp("player", Lv.xp_to_next(DataDB.all(), int(GameState.player["level"])) - int(GameState.player["xp"]))
		Narrator.say(_level_text(reports))
		_open(_show_leveling)))
	row.add_child(UiTheme.button("+50 XP", func() -> void:
		Narrator.say(_level_text(GameState.give_xp("player", 50)))
		_open(_show_leveling)))
	for cls in DataDB.table("classes").get("classes", []):
		var cid := str(cls["id"])
		if int(cls.get("tier", 1)) != 1:
			continue
		box.add_child(UiTheme.button("New run as %s (seed 1234)" % cls["name"], func() -> void:
			GameState.new_run(1234, cid)
			_open(_show_character)))
	var pending: Array = p.get("pendingPerks", [])
	if not pending.is_empty():
		box.add_child(UiTheme.label("Choose a perk (level %d):" % int(pending[0]), UiTheme.ACCENT))
		for perk_id in Lv.perk_options(DataDB.all(), p, int(pending[0])):
			var perk: Dictionary = DataDB.record("perks", str(perk_id))
			var pid := str(perk_id)
			box.add_child(UiTheme.button("%s: %s" % [perk.get("name", pid), perk.get("text", "")], func() -> void:
				Lv.choose_perk(DataDB.all(), GameState.player, pid)
				_open(_show_leveling)))


func _level_text(reports: Array) -> String:
	if reports.is_empty():
		return "XP gained."
	var parts: Array = []
	for r in reports:
		var gains: Array = []
		for s in r["stats"]:
			gains.append("%s+%d" % [str(s).to_upper(), int(r["stats"][s])])
		var text := "Level %d: %s" % [int(r["level"]), " ".join(PackedStringArray(gains))]
		if not r["learned"].is_empty():
			text += ", learned " + ", ".join(PackedStringArray(r["learned"]))
		parts.append(text)
	return ". ".join(PackedStringArray(parts))

## UI audit (final check pass): opens every screen and main scene with a run
## and checks each visible button has a handler (or is disabled on purpose),
## has text or an icon, fits on screen, and that screens give keyboard focus
## to something. Prints every problem with the screen and the button text.
## Run: godot --headless --path . -s res://tests/smoke_ui.gd (exit 0 = pass)
extends SceneTree

var _passes := 0
var _failures := 0
var _issues: Array = []

## Screens to open as modals: script, properties to set first.
const SCREENS := [
	["res://src/scenes/ui/options_modal.gd", {}],
	["res://src/scenes/ui/phone_screen.gd", {}],
	["res://src/scenes/ui/board_screen.gd", {}],
	["res://src/scenes/ui/equipment_screen.gd", {}],
	["res://src/scenes/ui/smith_screen.gd", {}],
	["res://src/scenes/ui/party_panel.gd", {}],
	["res://src/scenes/ui/compendium_screen.gd", {}],
	["res://src/scenes/ui/spark_quiz_screen.gd", {}],
	["res://src/scenes/ui/spark_quiz_screen.gd", { "allow_choose": true }],
	["res://src/scenes/ui/workbench_screen.gd", {}],
	["res://src/scenes/ui/forge_screen.gd", {}],
	["res://src/scenes/ui/technique_screen.gd", {}],
	["res://src/scenes/ui/point_buy_screen.gd", { "class_id": "mage" }],
	["res://src/scenes/ui/owner_pick.gd", { "card_id": "sp:heat:bolt:standard", "active_ids": ["player"] }],
	["res://src/scenes/ui/schedule_screen.gd", {}],
	["res://src/scenes/ui/class_screen.gd", {}],
	["res://src/scenes/ui/night_screen.gd", {}],
	["res://src/scenes/ui/party_screen.gd", {}],
	["res://src/scenes/ui/class_change_screen.gd", {}],
	["res://src/scenes/ui/dialogue_screen.gd", { "npc_id": "gary" }],
	["res://src/scenes/ui/event_screen.gd", { "event": { "title": "Test", "text": "A test event.", "choices": [{ "label": "Fine", "effects": {} }] } }],
]

## Workbench pages reached by calling their builder methods.
const WORKBENCH_PAGES := ["_menu", "_design", "_copy_menu", "_deck_editor"]

const SCENES := [
	"res://src/scenes/title/title.tscn",
	"res://src/scenes/town/town.tscn",
	"res://src/scenes/arena/arena.tscn",
]


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("FAIL ui: " + msg)


func _node(name: String) -> Node:
	return root.get_node_or_null(name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await process_frame
	var gs := _node("GameState")
	var flow := _node("Flow")
	for s in SCREENS:
		gs.call("new_run", 4, "mage")
		var script: GDScript = load(str(s[0]))
		var m: Control = script.new()
		for k in s[1]:
			m.set(str(k), s[1][k])
		var label := str(s[0]).get_file().get_basename()
		flow.call("show_modal", m)
		await _frames(6)
		_audit(m, label, true)
		if label == "workbench_screen":
			for page in WORKBENCH_PAGES:
				m.call(str(page))
				await _frames(4)
				_audit(m, "%s %s" % [label, page], true)
		if is_instance_valid(m) and m.has_method("finish"):
			m.call("finish", null)
		await _frames(3)
		_clear_modals()
	for path in SCENES:
		gs.call("new_run", 4, "mage")
		if path.contains("arena"):
			(load("res://src/scenes/title/title.gd") as GDScript).call("start_arena", { "class": "mage" }, 4, 4, 3, 999)
			await _frames(30)
		else:
			change_scene_to_file(path)
			await _frames(30)
		_clear_modals()
		await _frames(2)
		if current_scene != null:
			_audit(current_scene, path.get_file().get_basename(), false)
	for i in _issues:
		printerr("  " + str(i))
	print("ui audit: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _clear_modals() -> void:
	for c in root.get_children():
		if c is Control and c.has_signal("closed") and c.has_method("finish"):
			c.call("finish", null)
	var flow := _node("Flow")
	if flow != null:
		for c in flow.get_children():
			if c.has_method("finish"):
				c.call("finish", null)


func _buttons(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is BaseButton:
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)


func _in_scroll(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _audit(root_node: Node, label: String, modal: bool) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(_node("Display").get("base")))
	var buttons: Array = []
	_buttons(root_node, buttons)
	var bad := 0
	for b in buttons:
		var btn: BaseButton = b
		if btn.mouse_filter == Control.MOUSE_FILTER_IGNORE and btn.focus_mode == Control.FOCUS_NONE:
			continue
		var name: String = str(btn.get("text")) if btn.get("text") != null else str(btn.name)
		var has_handler := not btn.pressed.get_connections().is_empty() or not btn.toggled.get_connections().is_empty() \
			or not btn.button_down.get_connections().is_empty() or not btn.gui_input.get_connections().is_empty() or btn.toggle_mode
		if not btn.disabled and not has_handler:
			_issues.append("%s: button '%s' does nothing" % [label, name])
			bad += 1
		var icon: Variant = btn.get("icon")
		if btn is Button and str(name).strip_edges() == "" and icon == null and not btn.has_method("setup"):
			_issues.append("%s: a button has no text or icon" % label)
			bad += 1
		var r := btn.get_global_rect()
		if not _in_scroll(btn) and r.size.x > 0 and not view.grow(1).encloses(r):
			_issues.append("%s: button '%s' is off screen at %s" % [label, name, str(r)])
			bad += 1
	check(bad == 0, "%s: %d buttons are usable and on screen" % [label, buttons.size()])
	if modal and not buttons.is_empty():
		var focus := root_node.get_viewport().gui_get_focus_owner()
		check(focus != null, "%s: something has keyboard focus" % label)

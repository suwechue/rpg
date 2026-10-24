## Scene smoke tests: loads real scenes with the autoloads and drives them the
## way input would, to catch runtime errors the pure tests cannot see.
## Run: godot --headless --path . -s res://tests/smoke_scenes.gd (exit 0 = pass)
extends SceneTree

var _passes := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("FAIL smoke: " + msg)


func _run() -> void:
	await process_frame
	_parse_all("res://src")
	await _smoke_combat()
	for m in get_script().get_script_method_list():
		var n := str(m["name"])
		if n.begins_with("smoke_"):
			await call(n)
	print("smoke: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


## Load every script so parse errors in scenes that no test visits still fail.
func _parse_all(path: String) -> void:
	var dir := DirAccess.open(path)
	for f in dir.get_files():
		if str(f).ends_with(".gd"):
			var s: GDScript = load(path + "/" + str(f))
			check(s != null and s.can_instantiate(), "script parses: %s/%s" % [path, f])
	for d in dir.get_directories():
		_parse_all(path + "/" + str(d))


func _root_node(name: String) -> Node:
	return root.get_node_or_null(name)


func _goto(path: String) -> Node:
	change_scene_to_file(path)
	await process_frame
	await process_frame
	return current_scene


## The newest modal Flow is showing, or null.
func _top_modal() -> Node:
	var flow: Node = _root_node("Flow")
	for i in range(flow.get_child_count() - 1, -1, -1):
		var c: Node = flow.get_child(i)
		if c.has_signal("closed") and not c.is_queued_for_deletion():
			return c
	return null


## Press the first enabled button in a modal whose text contains `needle`.
func _press(modal: Node, needle: String = "") -> bool:
	for b in modal.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn != null and not btn.disabled and btn.is_visible_in_tree() and (needle == "" or btn.text.find(needle) >= 0):
			btn.pressed.emit()
			return true
	return false


func smoke_week_of_school() -> void:
	var gs: Node = _root_node("GameState")
	var cal: Node = _root_node("Calendar")
	var flow: Node = _root_node("Flow")
	_root_node("SaveSystem").call("delete_save")
	gs.call("new_run", 777, "bard")
	await _goto("res://src/scenes/main.tscn")
	var stats0: Dictionary = gs.get("player")["stats"].duplicate()
	var guard := 0
	var seen := {}
	while int(cal.call("week")) == 1 and guard < 400:
		guard += 1
		await process_frame
		var m := _top_modal()
		if m != null:
			var script_name := str(m.get_script().resource_path.get_file())
			seen[script_name] = true
			if script_name == "class_screen.gd" and m.get("_event").is_empty() and m.find_children("*", "Button", true, false).size() >= 2 and not seen.has("attended_%d" % guard):
				_press(m, "Attend")
			elif script_name == "night_screen.gd":
				_press(m, "Go to sleep")
			elif script_name == "schedule_screen.gd":
				_press(m, "Confirm")
			else:
				_press(m)
			await process_frame
			continue
		if not flow.call("is_busy"):
			flow.call("end_part")
	check(int(cal.call("week")) == 2, "a whole week passes through the UI (guard %d)" % guard)
	check(seen.has("schedule_screen.gd") and seen.has("class_screen.gd") and seen.has("night_screen.gd"), "schedule, class and night screens appeared: %s" % str(seen.keys()))
	var changed := 0
	for s in stats0:
		if int(gs.get("player")["stats"][s]) != int(stats0[s]):
			changed += 1
	check(changed >= 2, "stats changed over the week (%d)" % changed)
	check(_root_node("SaveSystem").call("has_save"), "autosave written at part changes")


func _smoke_combat() -> void:
	var gs: Node = _root_node("GameState")
	gs.call("new_run", 4242, "mage")
	gs.call("add_debug_ally", "healer")
	gs.set("pending_combat", gs.call("combat_setup", ["pom_pom_wisp", "megaphone_mimic"], "open_field"))
	var scene: Node = await _goto("res://src/scenes/combat/combat.tscn")
	check(scene != null and scene.name == "Combat", "combat scene loads")
	var st: Object = scene.get("state")
	check(st != null, "combat state exists")
	var guard := 0
	while not scene.call("_player_turn") and guard < 200 and str(st.get("result")) == "":
		await create_timer(0.05).timeout
		guard += 1
	check(scene.call("_player_turn"), "reaches a player turn")
	var u: Object = st.get("current")
	var hand: Array = u.get("deck").get("hand")
	var played := false
	for i in hand.size():
		var card: Dictionary = st.call("card_of", u, i)
		var targets: Array = st.call("card_targets", u, card)
		if targets.is_empty() or int(st.call("card_cost", u, card)) > int(u.get("mp")):
			continue
		scene.call("_on_card", i)
		if str(scene.get("mode")) == "card":
			scene.set("hover_cell", targets[0])
			scene.call("_refresh_overlays")
			var before := int(u.get("mp"))
			scene.call("_click_cell", targets[0])
			await create_timer(1.5).timeout
			played = int(u.get("mp")) < before or str(st.get("result")) != ""
		else:
			played = true
		break
	check(played, "a card can be selected, previewed and played")
	if scene.call("_player_turn"):
		scene.call("_on_button", "guard")
		await create_timer(0.5).timeout
		check(bool(u.get("free_action_used")), "guard uses the free basic action")
		scene.call("_on_button", "wheel")
		check(scene.get("_wheel") != null, "the Vector Wheel opens")
		scene.call("_cancel")
		scene.call("_on_button", "end")
		await create_timer(0.3).timeout
		check(st.get("current") != u or str(st.get("result")) != "", "end turn passes the turn")
	gs.set("dev_autoplay", true)
	scene.call("_play_events")
	guard = 0
	while str(st.get("result")) == "" and guard < 600:
		await create_timer(0.05).timeout
		guard += 1
	check(str(st.get("result")) != "", "the fight reaches a result on autopilot (%s)" % st.get("result"))
	guard = 0
	while scene.get("_result_panel") == null and guard < 100:
		await create_timer(0.05).timeout
		guard += 1
	check(scene.get("_result_panel") != null, "result panel shows")
	gs.set("dev_autoplay", false)

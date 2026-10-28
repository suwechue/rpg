## Scene smoke tests: loads real scenes with the autoloads and drives them the
## way input would, to catch runtime errors the pure tests cannot see.
## Run: godot --headless --path . -s res://tests/smoke_scenes.gd (exit 0 = pass)
extends SceneTree

var _passes := 0
var _failures := 0
var _last_dungeon_step := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("FAIL smoke: " + msg)


func _run() -> void:
	Engine.time_scale = 4.0
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


## VD Part 5: in demo mode the run ends with the thanks screen and the survey,
## saved as a feedback zip, then the title.
func smoke_demo_end() -> void:
	var gs := _root_node("GameState")
	var fb := _root_node("Feedback")
	gs.call("new_run", 9, "mage")
	fb.set("force_demo", true)
	fb.set("last_zip", "")
	# Not awaited: _drive presses through the thanks screen, the survey and the run's end.
	fb.call("end_demo")
	await _drive(func() -> bool: return str(fb.get("last_zip")) != "" and current_scene != null and current_scene.name == "Title" and _top_modal() == null, [], 60.0)
	fb.set("force_demo", false)
	check(str(fb.get("last_zip")) != "" and FileAccess.file_exists(str(fb.get("last_zip"))), "the demo survey is saved as a feedback zip")
	check(current_scene != null and current_scene.name == "Title", "the demo ends at the title")
	var z := ZIPReader.new()
	if z.open(str(fb.get("last_zip"))) == OK:
		check(z.get_files().has("survey.json") and z.get_files().has("summary.json"), "the zip has the survey and the summary: %s" % str(z.get_files()))
		z.close()


func smoke_week_of_school() -> void:
	var gs: Node = _root_node("GameState")
	var cal: Node = _root_node("Calendar")
	var flow: Node = _root_node("Flow")
	_root_node("SaveSystem").call("delete_save")
	gs.call("new_run", 777, "fighter")
	gs.set("dev_autoplay", true)
	# The smoke checks the week's flow, not balance: a sturdier player keeps the AI from losing the boss.
	gs.get("player")["stats"]["con"] = int(gs.get("player")["stats"]["con"]) + 12
	preload("res://src/core/character.gd").full_restore(_root_node("DataDB").call("all"), gs.get("player"))
	var recruited := false
	await _goto("res://src/scenes/town/town.tscn")
	var stats0: Dictionary = gs.get("player")["stats"].duplicate()
	var guard := 0
	var seen := {}
	var kind := ["Attend", "Go to sleep", "Confirm", "Ignore her", "Put it away", "Let her carry", "long way", "Look at me", "Continue"]
	var start := Time.get_ticks_msec()
	while int(cal.call("week")) == 1 and Time.get_ticks_msec() - start < 900000:
		guard += 1
		await process_frame
		if not recruited and gs.call("flag", "story_done_w1_evening"):
			recruited = true
			for id in ["theo", "mara"]:
				gs.get("run")["bonds"][id] = 45.0
				preload("res://src/core/social/bonds.gd").recruit(_root_node("DataDB").call("all"), gs.get("run"), id, RandomNumberGenerator.new())
		if current_scene != null and current_scene.name == "Title":
			break
		var m := _top_modal()
		if m != null:
			seen[str(m.get_script().resource_path.get_file())] = true
			var pressed := false
			for n in kind:
				if _press(m, str(n)):
					pressed = true
					break
			if not pressed:
				_press(m)
			await process_frame
			continue
		var sc := current_scene
		if sc != null and sc.name == "Combat" and sc.get("_result_panel") != null:
			_press(sc.get("_result_panel"))
		if sc != null and sc.name == "Dungeon":
			_dungeon_step(sc)
		if sc != null and sc.name == "Town" and not flow.call("is_busy"):
			flow.call("end_part")
	check(int(cal.call("week")) == 2, "a whole week passes through the UI (guard %d)" % guard)
	check(seen.has("schedule_screen.gd") and seen.has("class_screen.gd") and seen.has("night_screen.gd"), "schedule, class and night screens appeared: %s" % str(seen.keys()))
	var changed := 0
	for s in stats0:
		if int(gs.get("player")["stats"][s]) != int(stats0[s]):
			changed += 1
	check(changed >= 2, "stats changed over the week (%d)" % changed)
	check(_root_node("SaveSystem").call("has_save"), "autosave written at part changes")
	check(gs.call("flag", "story_done_w1_evening"), "Monday night's story played inside the week")
	check(gs.call("flag", "week1_cleared"), "M7: The Hollow Mascot is beaten and week 1 is cleared")
	check(gs.get("run")["encounter_log"].size() >= 6, "fights Tuesday to Thursday were logged (%d)" % gs.get("run")["encounter_log"].size())
	check(not _root_node("Journal").get("data")["enemies"].is_empty(), "the Narrator's Journal recorded creatures")
	gs.set("dev_autoplay", false)


func _wait_modal(needle_script: String, frames: int = 30) -> Node:
	for i in frames:
		await process_frame
		var m := _top_modal()
		if m != null and str(m.get_script().resource_path).ends_with(needle_script):
			return m
	return null


## M5 "Done when": walk the town, buy, train and meet NPCs on schedule.
func smoke_town() -> void:
	var gs: Node = _root_node("GameState")
	var cal: Node = _root_node("Calendar")
	gs.call("new_run", 4321, "fighter")
	gs.get("run")["schedule_week"] = 1
	cal.call("reset", { "week": 1, "day_index": 0, "part_index": 5, "ap": -1 })
	var town: Node = await _goto("res://src/scenes/town/town.tscn")
	check(town != null and str(town.get("map_id")) == "school", "after school starts at the school")
	var c0: Vector2i = town.get("cell")
	await town.call("step", Vector2i.LEFT)
	await town.call("step", Vector2i.LEFT)
	check(town.get("cell") != c0, "walking moves the player")
	check(int(cal.call("ap")) == 3, "walking is free")
	town.call("_load_map", "downtown", false, "", Vector2i(21, 14))
	town.set("facing", Vector2i.UP)
	await town.call("interact")
	check(bool(town.get("interior")) and str(town.get("interior_loc")) == "garys_deli", "the deli door leads inside")
	check(town.get("npcs").values().has("gary"), "Gary is at his deli after school")
	var money0: int = int(gs.get("money"))
	town.call("location_menu", "garys_deli")
	var menu := await _wait_modal("modal.gd")
	check(menu != null and _press(menu, "Shop"), "the deli has a shop")
	var shop := await _wait_modal("shop_screen.gd")
	check(shop != null and _press(shop, "Breakfast"), "buy breakfast")
	await process_frame
	_press(shop, "Done")
	await process_frame
	check(int(gs.get("money")) < money0 and int(cal.call("ap")) == 2, "money spent and 1 AP for the visit")
	town.call("location_menu", "garys_deli")
	menu = await _wait_modal("modal.gd")
	var stats0: Dictionary = gs.get("player").get("statXp", {}).duplicate()
	check(menu != null and _press(menu, "Work a deli shift"), "train with a deli shift")
	await process_frame
	check(int(cal.call("ap")) == 0 and int(gs.get("run")["shifts"].get("deli_shifts", 0)) == 1, "the shift costs 2 AP and counts")
	check(gs.get("player").get("statXp", {}) != stats0, "training fills stat bars")
	var gary_cell: Vector2i = Vector2i(-1, -1)
	for at in town.get("npcs"):
		if str(town.get("npcs")[at]) == "gary":
			gary_cell = at
	town.call("_load_map", "deli", true, "garys_deli", gary_cell + Vector2i(0, 2))
	town.set("facing", Vector2i.UP)
	town.call("interact")
	var talk := await _wait_modal("dialogue_screen.gd")
	check(talk != null, "talking to Gary opens a conversation")
	if talk != null:
		_press(talk, "Bye")
	await process_frame
	check(bool(gs.get("run")["npcs"]["gary"]["met"]), "Gary is met")
	town.call("_load_map", "downtown", false, "", Vector2i(14, 25))
	town.set("facing", Vector2i.UP)
	town.call("interact")
	await process_frame
	check(str(_root_node("Narrator").get("last_line")).find("renovations") >= 0, "the closed cinema gives its door line")


## One step of auto-exploring a dungeon floor: fight, loot, rest, then leave.
## Never awaits the scene's own coroutines: leaving at the exit frees the
## scene mid-call, and an awaited coroutine on a freed scene never resumes.
## A step is taken at most every 0.3 s (real time) instead.
func _dungeon_step(sc: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_dungeon_step < 300 or sc.get("_moving") or _root_node("Flow").call("is_busy"):
		return
	_last_dungeon_step = now
	var r: Dictionary = sc.call("next_room")
	if not r.is_empty():
		var t := str(r["type"])
		if t in ["combat", "elite", "boss"]:
			sc.call("visit_room", int(r["id"]))
		else:
			sc.call("use_feature", int(r["id"]))


## Press through modals (choosing by needle where given) and combat result
## panels until `done` returns true or the guard runs out.
func _drive(done: Callable, needles: Array, seconds: float = 60.0) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		await process_frame
		if done.call():
			return true
		var m := _top_modal()
		if m != null:
			var pressed := false
			for n in needles:
				if _press(m, str(n)):
					pressed = true
					break
			if not pressed:
				_press(m)
			await process_frame
			continue
		var scene := current_scene
		if scene != null and scene.name == "Dungeon":
			_dungeon_step(scene)
		if OS.has_environment("SMOKE_TRACE") and (Time.get_ticks_msec() / 1000) % 3 == 0 and Engine.get_process_frames() % 60 == 0:
			print("[trace] scene=%s modal=%s pos=%s" % [scene.name if scene != null else "-", _top_modal(), _root_node("GameState").get("run").get("story_pos", {})])
			if scene != null and scene.name == "Combat":
				var st: Object = scene.get("state")
				print("[trace] result=%s busy=%s done=%s current=%s ai=%s round=%d" % [st.get("result"), scene.get("_busy"), scene.get("_done"), st.get("current").get("name"), scene.call("_is_ai", st.get("current")), st.get("round_num")])
		if scene != null and scene.name == "Combat" and scene.get("_result_panel") != null:
			_press(scene.get("_result_panel"))
	return done.call()


## M6 "Done when": the Kelly Monday scenario plays and tracks her Risk; both outcomes.
func smoke_kelly_monday() -> void:
	var gs: Node = _root_node("GameState")
	var cal: Node = _root_node("Calendar")
	var flow: Node = _root_node("Flow")
	for outcome in ["survive", "death"]:
		gs.call("new_run", 99 if outcome == "survive" else 98, "healer")
		gs.get("run")["schedule_week"] = 1
		gs.get("player")["stats"]["cha"] = 8
		gs.set("dev_autoplay", true)
		cal.call("reset", { "week": 1, "day_index": 0, "part_index": 3, "ap": -1 })
		await _goto("res://src/scenes/town/town.tscn")
		var kind := ["Your routine", "Let her carry", "long way", "Look at me", "Put it away", "Continue"]
		var cruel := ["personality", "Keep the lantern", "shortcut", "Pull it together", "Laugh along", "Continue"]
		var needles: Array = kind if outcome == "survive" else cruel
		var lunch_done := await _drive(func() -> bool: return gs.call("flag", "story_done_w1_lunch") and _top_modal() == null, needles, 10.0)
		check(lunch_done, "the Monday lunch scene plays (%s)" % outcome)
		if outcome == "death":
			gs.get("run")["kelly_risk"] = int(gs.get("run")["kelly_risk"]) + 3
		cal.call("reset", { "week": 1, "day_index": 0, "part_index": 6, "ap": -1 })
		flow.set("_busy", false)
		flow.call("_on_part_started")
		var ended := await _drive(func() -> bool:
			return gs.call("flag", "story_done_w1_evening") or (current_scene != null and current_scene.name == "Title"), needles, 900.0)
		check(ended, "the evening tutorial floor plays to the end (%s, Risk %d)" % [outcome, int(gs.get("run").get("kelly_risk", 0))])
		check(gs.call("flag", "cutscene_seen_kelly_floor_intro"), "M14: the Kelly floor intro cutscene played (playing: %s)" % str(_root_node("Cutscenes").get("playing")))
		if outcome == "survive":
			check(not gs.call("flag", "w1_shortcut"), "the long way: room 7 (Hot Floor) is played")
			check(gs.call("flag", "survived_w1_monday"), "kind night: you survive")
			check(gs.get("run").get("guests", []).is_empty(), "Kelly goes home after the night")
		else:
			check(current_scene != null and current_scene.name == "Title", "Risk 4+: the run ends and the title returns")
			check(not _root_node("SaveSystem").call("has_save"), "permadeath deletes the save")
	gs.set("dev_autoplay", false)


## Each crafting minigame finishes with a Performance score in 0..1.
func smoke_minigames() -> void:
	for arch in ["thermal", "precision", "alignment", "chemical"]:
		var rec: Dictionary = _root_node("DataDB").call("record", "minigames", arch)
		var mg: Control = (load(str(rec["script"])) as GDScript).new()
		mg.set("title", str(rec["name"]))
		root.add_child(mg)
		var result := { "perf": -1.0 }
		mg.connect("finished", func(p: float) -> void: result["perf"] = p)
		await process_frame
		var start := Time.get_ticks_msec()
		while float(result["perf"]) < 0.0 and Time.get_ticks_msec() - start < 20000:
			if arch == "chemical":
				var seq: Array = mg.get("_seq")
				var step := int(mg.get("_step"))
				if step < seq.size():
					var ev := InputEventAction.new()
					ev.action = ["move_up", "move_right", "move_down", "move_left"][int(seq[step])]
					ev.pressed = true
					mg.call("other_input", ev)
			elif arch != "thermal":
				mg.call("action_pressed")
			await create_timer(0.2).timeout
		check(float(result["perf"]) >= 0.0 and float(result["perf"]) <= 1.0, "%s minigame returns a Performance (%.2f)" % [arch, result["perf"]])
		if arch == "chemical":
			check(float(result["perf"]) > 0.5, "a correct chemical sequence scores well")


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
		check(bool(u.get("quick_used")), "Guard uses the Quick (PT Part 1)")
		scene.call("_on_button", "wheel")
		check(scene.get("_wheel") != null, "the Vector Wheel opens")
		scene.call("_cancel")
		scene.call("_on_button", "end")
		await create_timer(0.3).timeout
		check(st.get("current") != u or str(st.get("result")) != "", "end turn passes the turn")
	gs.set("dev_autoplay", true)
	scene.call("_play_events")
	var t0 := Time.get_ticks_msec()
	while str(st.get("result")) == "" and Time.get_ticks_msec() - t0 < 90000:
		await create_timer(0.05).timeout
	if str(st.get("result")) == "":
		var cur: Object = st.get("current")
		printerr("combat stuck: round=%d busy=%s current=%s ai=%s" % [st.get("round_num"), scene.get("_busy"), cur.get("name") if cur != null else "-", scene.call("_is_ai", cur) if cur != null else "-"])
	check(str(st.get("result")) != "", "the fight reaches a result on autopilot (%s)" % st.get("result"))
	guard = 0
	while scene.get("_result_panel") == null and guard < 100:
		await create_timer(0.05).timeout
		guard += 1
	check(scene.get("_result_panel") != null, "result panel shows")
	gs.set("dev_autoplay", false)


func smoke_gameplay_log() -> void:
	var pl := _root_node("PlayLog")
	var bus := _root_node("EventBus")
	var test_path := "user://smoke_gameplay_log.jsonl"
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)
	var was: bool = pl.get("enabled")
	var old_path: String = pl.get("path")
	pl.set("enabled", true)
	pl.set("path", test_path)
	bus.emit_signal("day_part_changed", 9, "Monday", "morning")
	bus.emit_signal("ap_spent", 2, "talk")
	bus.emit_signal("combat_finished", { "result": "win" })
	bus.emit_signal("day_part_changed", 9, "Tuesday", "morning")
	pl.set("enabled", was)
	pl.set("path", old_path)
	var text := FileAccess.get_file_as_string(test_path)
	var rec: Variant = JSON.parse_string(text.get_slice("\n", 0))
	check(rec is Dictionary and int(rec["ap"]["talk"]) == 2 and int(rec["won"]) == 1 and str(rec["day"]) == "Monday", "gameplay log writes a day line: %s" % text.strip_edges())
	DirAccess.remove_absolute(test_path)


func smoke_custom_art_hot_reload() -> void:
	var assets := _root_node("Assets")
	var display := _root_node("Display")
	var root := "user://custom_smoke"
	DirAccess.make_dir_recursive_absolute(root + "/portraits")
	DirAccess.make_dir_recursive_absolute(root + "/tiles")
	var face := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	face.fill(Color.RED)
	face.save_png(root + "/portraits/portrait_kelly.png")
	var tile_size: int = display.get("tile")
	var road := Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
	road.fill(Color.BLUE)
	road.save_png(root + "/tile_road_h_top.png")
	check(assets.call("source", "portrait_kelly") == "pack", "Kelly's portrait starts as pack art")
	assets.set("override_root", root)
	assets.call("reload")
	check(assets.call("source", "portrait_kelly") == "custom", "after a reload the custom portrait is used")
	var tex: Texture2D = assets.call("texture", "portrait_kelly")
	check(tex.get_image().get_pixel(10, 10).is_equal_approx(Color.RED), "the custom portrait is what's drawn")
	var city: Texture2D = assets.call("texture", "tileset_city")
	var spec: Dictionary = assets.call("spec", "tile_road_h_top")
	var cols := city.get_width() / tile_size
	var idx := int(spec["index"])
	var px := Vector2i((idx % cols) * tile_size + 3, (idx / cols) * tile_size + 3)
	check(city.get_image().get_pixel(px.x, px.y).is_equal_approx(Color.BLUE), "one custom tile replaces its cell in the tileset")
	check(city.get_width() == 2 * 192, "pack tilesets are scaled to the tile size (%d)" % city.get_width())
	var missing: Texture2D = assets.call("texture", "no_such_asset")
	check(missing != null and missing.get_image().get_pixel(missing.get_width() - 3, missing.get_height() - 3).is_equal_approx(Color(1, 0, 1)), "a missing id is a magenta placeholder")
	DirAccess.remove_absolute(root + "/portraits/portrait_kelly.png")
	DirAccess.remove_absolute(root + "/tile_road_h_top.png")
	assets.set("override_root", "")
	assets.call("reload")
	check(assets.call("source", "portrait_kelly") == "pack", "removing the file and reloading restores the pack art")


func smoke_ui_skin_restyles_everything() -> void:
	var ui := _root_node("UiTheme")
	var assets := _root_node("Assets")
	var theme: Theme = ui.get("theme")
	var root := "user://skin_smoke"
	DirAccess.make_dir_recursive_absolute(root + "/ui")
	var panel := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	panel.fill(Color(1, 0, 0))
	panel.save_png(root + "/ui/ui_panel.png")
	assets.set("override_root", root)
	assets.call("reload")
	var sb := theme.get_stylebox("panel", "PanelContainer") as StyleBoxTexture
	check(sb != null and sb.texture.get_image().get_pixel(12, 12).is_equal_approx(Color(1, 0, 0)), "a custom panel image restyles every PanelContainer")
	var colors: Dictionary = _root_node("DataDB").call("table", "ui")["colors"]
	var old_text: String = colors["text"]
	colors["text"] = "#00ff00"
	ui.call("rebuild")
	check(theme.get_color("font_color", "Label").is_equal_approx(Color("#00ff00")), "one color in ui.json changes every label")
	colors["text"] = old_text
	DirAccess.remove_absolute(root + "/ui/ui_panel.png")
	assets.set("override_root", "")
	assets.call("reload")
	check(theme.get_color("font_color", "Label").is_equal_approx(Color(old_text)), "restored")
	var was: bool = ui.get("colorblind")
	ui.set("colorblind", true)
	var cb: Color = ui.call("vector_color", "vitality")
	ui.set("colorblind", false)
	check(not cb.is_equal_approx(ui.call("vector_color", "vitality")), "the colorblind palette changes Vector colors")
	ui.set("colorblind", was)


## CU: in the real combat scene, a Force push lands an enemy in a hazard and a
## second push sends one sliding across ice; hovering a card previews it and
## enemies show telegraphs. Every action goes through the scene's own input code.
func smoke_cu_push_and_slide() -> void:
	var gs: Node = _root_node("GameState")
	gs.call("new_run", 777, "mage")
	var db: Dictionary = _root_node("DataDB").call("all")
	var ch: Dictionary = preload("res://src/core/character.gd").create(db, "mage", RandomNumberGenerator.new(), {
		"isPlayer": true, "knownVectors": ["force", "cold"], "stats": { "str": 5, "dex": 40, "con": 8, "int": 9, "per": 40, "wil": 6, "cha": 4 } })
	ch["mp"] = 30
	var idx := preload("res://src/core/data_tables.gd").index_under(db, "enemies/", "enemies")
	var tough: Dictionary = idx["bleacher_creeper"].duplicate(true)
	tough["hp"] = 200
	tough["maxHp"] = 200
	var tough2: Dictionary = tough.duplicate(true)
	gs.set("pending_combat", { "layout": { "map": [
		"P.Eh.....",
		".........",
		"P.Eiii...",
	] }, "party": [{ "char": ch }, { "char": ch.duplicate(true) }], "enemies": [tough, tough2] })
	var scene: Node = await _goto("res://src/scenes/combat/combat.tscn")
	var st: Object = scene.get("state")
	var guard := 0
	while not scene.call("_player_turn") and guard < 200:
		await create_timer(0.05).timeout
		guard += 1
	check(scene.call("_player_turn"), "CU: the player acts first")
	var planned := 0
	var attacking := 0
	for x in st.get("units"):
		if str(x.get("team")) == "enemy":
			var it: Dictionary = x.get("intent")
			if not it.is_empty():
				planned += 1
			if str(it.get("kind", "")) in ["attack", "special"]:
				attacking += 1
	check(planned == 2, "CU: every enemy shows an intent before the player's turn")
	var field: Object = scene.get("field")
	check((field.get("threat_cells") as Dictionary).size() >= attacking, "CU: attack telegraphs are drawn on the grid")
	var pushes := 0
	var slides := 0
	for turn in 2:
		var u: Object = st.get("current")
		u.get("deck").set("hand", ["sp:force:bolt:standard"])
		u.set("mp", 30)
		var foe_cell := Vector2i(2, 0) if turn == 0 else Vector2i(2, 2)
		scene.set("hover_cell", Vector2i(-1, -1))
		scene.call("_hover_card_changed", 0)
		check(not (field.get("target_cells") as Array).is_empty(), "CU: hovering a card shows its range (turn %d)" % turn)
		check(not (field.get("push_marks") as Array).is_empty(), "CU: hovering a Force card shows where the target lands")
		scene.call("_hover_card_changed", -1)
		scene.call("_on_card", 0)
		scene.call("_on_card", 0)
		check(str(scene.get("mode")) == "idle", "CU: clicking the selected card again deselects it")
		scene.call("_on_card", 0)
		scene.set("hover_cell", foe_cell)
		scene.call("_click_cell", foe_cell)
		var waited := 0
		while bool(scene.get("_busy")) and waited < 200:
			await create_timer(0.05).timeout
			waited += 1
		for line in scene.get("_log"):
			if str(line).contains("from the hazard"):
				pushes += 1
			if str(line).contains("slides across the ice"):
				slides += 1
		check(int(u.get("actions_left")) < 2 or bool(u.get("quick_used")), "the card used an Action or the Quick")
		if turn == 0:
			scene.call("_on_button", "end")
			waited = 0
			while not scene.call("_player_turn") and waited < 400 and str(st.get("result")) == "":
				await create_timer(0.05).timeout
				waited += 1
	check(pushes > 0, "CU: a push lands an enemy in a hazard")
	check(slides > 0, "CU: an enemy slides across ice")


## P2 1.1 and 1.2 in the real scene: Strike targeting after both Actions, and
## clicking card A then card B leaves A neither selected nor outlined.
func smoke_p2_quick_and_selection() -> void:
	var gs: Node = _root_node("GameState")
	gs.call("new_run", 777, "fighter")
	var setup: Dictionary = gs.call("combat_setup", ["pom_pom_wisp"], "open_field")
	setup["partyFirst"] = true
	gs.set("pending_combat", setup)
	var scene: Node = await _goto("res://src/scenes/combat/combat.tscn")
	var st: Object = scene.get("state")
	var guard := 0
	while not scene.call("_player_turn") and guard < 200:
		await create_timer(0.05).timeout
		guard += 1
	var u: Object = st.get("current")
	u.get("deck").set("hand", ["card_heavy_swing", "card_lunge", "card_brace"])
	u.set("mp", 10)
	scene.call("_refresh_hud")
	scene.call("_on_card", 0)
	scene.call("_on_card", 1)
	var hand_box: Node = scene.get("_hand")
	var a: Node = hand_box.get_child(0) if hand_box.get_child_count() > 0 else null
	check(a != null and not bool(a.get("selected")) and not (a as Control).has_focus(), "clicking card B clears card A's selected and focus look")
	scene.call("_cancel")
	u.set("actions_left", 0)
	u.set("action_used", true)
	u.set("quick_used", false)
	scene.call("_on_button", "strike")
	check(str(scene.get("mode")) == "strike", "Strike targeting starts after both Actions are spent (it's a Quick)")
	scene.call("_cancel")

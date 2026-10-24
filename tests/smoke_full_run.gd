## M8 "Done when": a full 5-week run can be completed. Plays a whole run in the
## real scenes with the AI fighting, kind dialogue choices, dungeons
## auto-explored, and recruits joining the way social play would bring them
## (two after Monday, a third in week 2). Long: run on its own.
## Run: godot --headless --path . -s res://tests/smoke_full_run.gd [-- --seed=N --class=fighter]
extends "res://tests/smoke_scenes.gd"

const BondRules := preload("res://src/core/social/bonds.gd")


func _run() -> void:
	Engine.time_scale = 8.0
	await process_frame
	var seed_value := 5150
	var cls := "fighter"
	for a in OS.get_cmdline_user_args():
		var kv := str(a).trim_prefix("--").split("=")
		if kv[0] == "seed":
			seed_value = int(kv[1])
		elif kv[0] == "class":
			cls = kv[1]
	await full_run(seed_value, cls)
	print("full run: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _recruit(gs: Node, id: String) -> void:
	if not gs.call("character", id).is_empty():
		return
	gs.get("run")["bonds"][id] = 50.0
	BondRules.recruit(_root_node("DataDB").call("all"), gs.get("run"), id, RandomNumberGenerator.new())


func full_run(seed_value: int, cls: String) -> void:
	var gs: Node = _root_node("GameState")
	var cal: Node = _root_node("Calendar")
	var flow: Node = _root_node("Flow")
	var journal: Node = _root_node("Journal")
	_root_node("SaveSystem").call("delete_save")
	var endings_before := int(journal.get("data")["endings"].get("alpha_complete", 0))
	gs.call("new_run", seed_value, cls)
	gs.set("dev_autoplay", true)
	await _goto("res://src/scenes/town/town.tscn")
	var kind := ["Attend", "Go to sleep", "Confirm", "Ignore her", "Put it away", "Let her carry", "long way", "Look at me",
		"Stick together", "Post it", "Trust your party", "Not if we stop", "Help", "Unplug", "Hold the light", "Continue"]
	var start := Time.get_ticks_msec()
	var weeks_seen := {}
	var last_sig := ""
	var last_change := Time.get_ticks_msec()
	var stalled := false
	while Time.get_ticks_msec() - start < 3600000:
		await process_frame
		var sc := current_scene
		if sc != null and sc.name == "Title":
			break
		if gs.call("has_run"):
			weeks_seen[int(cal.call("week"))] = true
			if gs.call("flag", "story_done_w1_evening"):
				_recruit(gs, "mara")
				_recruit(gs, "theo")
			if int(cal.call("week")) >= 2:
				_recruit(gs, "dex")
		var m := _top_modal()
		var sig := "%s|%s|%s|%s" % [cal.call("label") if gs.call("has_run") else "-", sc.name if sc != null else "-", m, gs.get("run").get("floor_pos", []) if gs.call("has_run") else "-"]
		if sc != null and sc.name == "Combat":
			var cst: Object = sc.get("state")
			sig += "|%d|%s" % [cst.get("round_num"), cst.get("current").get("name") if cst.get("current") != null else "-"]
			if int(cst.get("round_num")) > 40:
				printerr("STALL: stalemate, fight passed 40 rounds: %s" % sig)
				stalled = true
				break
		if sig != last_sig:
			last_sig = sig
			last_change = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - last_change > 60000:
			printerr("STALL for 60 s: %s" % sig)
			if sc != null and sc.name == "Combat":
				var cst2: Object = sc.get("state")
				printerr("STALL combat: busy=%s done=%s result=%s events=%d" % [sc.get("_busy"), sc.get("_done"), cst2.get("result"), cst2.get("events").size()])
			stalled = true
			break
		if OS.has_environment("SMOKE_TRACE") and Engine.get_process_frames() % 300 == 0:
			print("[trace] w%d %s %s scene=%s modal=%s flow_busy=%s dbusy=%s moving=%s" % [int(cal.call("week")), cal.call("day_name"), cal.call("part_id"),
				sc.name if sc != null else "-", m.get_script().resource_path.get_file() if m != null else "-", flow.call("is_busy"), _last_dungeon_step,
				sc.get("_moving") if sc != null and sc.name == "Dungeon" else "-"])
			if sc != null and sc.name == "Combat":
				var st: Object = sc.get("state")
				var cur: Object = st.get("current")
				var alive: Array = []
				for u in st.get("units"):
					if u.call("alive"):
						alive.append("%s:%d@%s" % [u.get("name"), u.get("hp"), u.get("cell")])
				print("[trace]   round=%d busy=%s done=%s current=%s mp=%d units=%s" % [st.get("round_num"), sc.get("_busy"), sc.get("_done"),
					cur.get("name") if cur != null else "-", cur.get("mp") if cur != null else 0, ", ".join(PackedStringArray(alive))])
		if m != null:
			var pressed := false
			for n in kind:
				if _press(m, str(n)):
					pressed = true
					break
			if not pressed:
				_press(m)
			await process_frame
			continue
		if sc != null and sc.name == "Combat" and sc.get("_result_panel") != null:
			_press(sc.get("_result_panel"))
		if sc != null and sc.name == "Dungeon":
			_dungeon_step(sc)
		if sc != null and sc.name == "Town" and not flow.call("is_busy"):
			flow.call("end_part")
	var finished := int(journal.get("data")["endings"].get("alpha_complete", 0)) > endings_before
	check(not stalled, "no stall longer than 60 s")
	check(weeks_seen.has(5), "the run reached week 5 (weeks seen: %s)" % str(weeks_seen.keys()))
	check(finished, "M8: the full 5-week run was completed (alpha ending recorded)")
	gs.set("dev_autoplay", false)

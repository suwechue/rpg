## AR smoke test: the Endless Arena on autoplay, in the real scenes, reaches
## wave 15 (PT done-when) with card picks, a Technique pick and checkpoints along
## the way. The preset party is strong (level 14): this checks the flow, not balance
## (tools/sim_arena.gd measures balance). Combat runs at
## "instant" speed; a watchdog fails the run if nothing changes for 60 s.
## Run: godot --headless --path . -s res://tests/smoke_arena.gd   (exit 0 = pass)
extends SceneTree

var _passes := 0
var _failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("FAIL arena smoke: " + msg)


func _initialize() -> void:
	_run.call_deferred()


func _node(name: String) -> Node:
	return root.get_node(name)


func _run() -> void:
	Engine.time_scale = 4.0
	await process_frame
	var db: Node = _node("DataDB")
	db.call("table", "ui")["combatSpeed"]["setting"] = "instant"
	var gs: Node = _node("GameState")
	gs.set("dev_autoplay", true)
	(load("res://src/scenes/title/title.gd") as GDScript).call("start_arena", { "class": "mage" }, 4, 1234, 14, 15)
	var last_change := Time.get_ticks_msec()
	var last_state := ""
	var started := Time.get_ticks_msec()
	var checkpoints := 0
	var mutators_seen := false
	while true:
		await create_timer(0.25).timeout
		var arena: Dictionary = gs.get("run").get("arena", {})
		if arena.is_empty():
			break
		var st := "%d:%s:%s" % [int(arena.get("wave", 0)), str(arena.get("phase", "")), str(arena.get("inFight", false))]
		var sc := current_scene
		if sc != null and sc.get("state") != null:
			st += ":%d" % int(sc.get("state").get("round_num"))
		if st != last_state:
			last_state = st
			last_change = Time.get_ticks_msec()
		if int(arena.get("ap", 0)) > 0 or int(arena.get("mutatorsTaken", 0)) > 0:
			checkpoints = maxi(checkpoints, int(arena.get("mutatorsTaken", 0)))
			mutators_seen = mutators_seen or int(arena.get("mutatorsTaken", 0)) > 0
		if int(arena.get("cleared", 0)) >= 15 or str(arena.get("phase", "")) == "over":
			break
		if Time.get_ticks_msec() - last_change > 60000:
			check(false, "stalled at %s" % st)
			break
		if Time.get_ticks_msec() - started > 1500000:
			check(false, "took too long (%s)" % st)
			break
	var arena: Dictionary = gs.get("run").get("arena", {})
	print("arena smoke: cleared %d waves, score %d, phase %s" % [int(arena.get("cleared", 0)), int(arena.get("score", 0)), str(arena.get("phase", ""))])
	check(int(arena.get("cleared", 0)) >= 14, "autoplay reaches wave 15 (cleared %d)" % int(arena.get("cleared", 0)))
	check(arena.get("picked", []).size() >= 10, "a card was picked after every wave (%d)" % arena.get("picked", []).size())
	check(not arena.get("perksTaken", []).is_empty(), "a Technique was picked at a checkpoint")
	check(mutators_seen, "a checkpoint mutator was picked")
	check(int(arena.get("score", 0)) > 0, "the score counts up")
	print("arena smoke: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)

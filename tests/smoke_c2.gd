## Combat 2.0 smoke (docs/COMBAT_2.md Part 5): autoplay clears every slice fight
## at levels 1 and 6 and the night mode under default levers, with no stalls;
## then the slice menu, the loadout screen and one fight run as real scenes.
## Run: godot --headless --path . -s res://tests/smoke_c2.gd (exit 0 = pass)
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const C2Setup := preload("res://src/core/combat2/c2_setup.gd")
const C2AI := preload("res://src/core/combat2/c2_ai.gd")
const Night := preload("res://src/core/combat2/night.gd")
const Kits := preload("res://src/core/combat2/kits.gd")
const C2Rules := preload("res://src/core/combat2/c2_rules.gd")

const STALL_ROUNDS := 30

var _passes := 0
var _failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("FAIL c2 smoke: " + msg)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var db: Dictionary = DT.tables("res://data")
	for f in C2Setup.fights(db):
		for lvl in [1, 6]:
			_autoplay(db, str(f["id"]), { "level": lvl })
	check(C2Setup.fights(db).size() >= 6, "6 slice fights")
	_night(db)
	await _scenes()
	print("c2 smoke: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _play(st: Object) -> int:
	var steps := 0
	while st.result == "" and steps < 3000 and st.round_num <= STALL_ROUNDS and st.current != null:
		steps += 1
		C2AI.take_turn(st, st.current)
		st.take_events()
	return steps


func _autoplay(db: Dictionary, fight_id: String, opts: Dictionary) -> Object:
	var st: Object = C2Setup.state(db, C2Setup.build(db, fight_id, opts))
	var steps := _play(st)
	check(st.result != "", "%s at level %d ends (round %d, %d steps)" % [fight_id, int(opts.get("level", 1)), st.round_num, steps])
	print("  %-18s L%d %-5s round %2d  knockdowns %d, One Mores %d, batons %d, All-Outs %d, spells %d, enemy hits %d of %d" % [fight_id, int(opts.get("level", 1)), st.result, st.round_num,
		int(st.tally["knockdowns"]), int(st.tally["oneMores"]), int(st.tally["batons"]), int(st.tally["allOuts"]), int(st.tally["spells"]), int(st.tally["enemyHits"]), int(st.tally["enemyAttacks"])])
	return st


func _night(db: Dictionary) -> void:
	var rules := C2Rules.build(db) as C2Rules
	for night in C2Setup.nights(db):
		for lvl in [1, 6]:
			var kits: Array = []
			for cid in db["combat2/fights"]["partyOrder"]:
				kits.append(Kits.build(db, rules, str(cid), lvl, C2Setup.default_loadout(db, str(cid), lvl)))
			var carry := Night.home(kits)
			var start := carry.duplicate(true)
			var known := {}
			var fights := 0
			var ended := true
			for step in night["steps"]:
				if str(step) == "rest":
					carry = Night.rest_room(carry, kits, rules)
					continue
				var st := _autoplay(db, str(step), { "level": lvl, "carry": carry, "known": known })
				fights += 1
				ended = ended and st.result != ""
				if st.result != "win":
					break
				carry = st.carry_out()
				known = st.known_marks
			var use := Night.charge_use(start, carry)
			check(ended and fights >= 1, "the night at level %d plays (%d fights)" % [lvl, fights])
			print("  night L%d: %d fights, charges spent %d of %d" % [lvl, fights, int(use["spent"]), int(use["max"])])


func _scenes() -> void:
	var game_state: Node = root.get_node("GameState")
	for path in ["res://src/scenes/combat2/c2_menu.tscn", "res://src/scenes/combat2/loadout_screen.tscn"]:
		var packed: PackedScene = load(path)
		check(packed != null, "%s loads" % path)
		var node := packed.instantiate()
		root.add_child(node)
		for i in 5:
			await process_frame
		check(node.get_child_count() > 0, "%s builds" % path)
		node.queue_free()
		await process_frame
	game_state.dev_autoplay = true
	Engine.time_scale = 8.0
	var flow: GDScript = load("res://src/scenes/combat2/c2_flow.gd")
	flow.fight_id = "c2_first_down"
	flow.night_id = ""
	flow.level = 1
	var packed: PackedScene = load("res://src/scenes/combat2/combat2.tscn")
	var fight := packed.instantiate()
	root.add_child(fight)
	var waited := 0.0
	while not fight.get("_done") == true and waited < 120.0:
		await create_timer(0.5, true, false, true).timeout
		waited += 0.5
	check(fight.get("_done") == true, "a slice fight plays to the end in the real scene (waited %.0f s)" % waited)
	fight.queue_free()
	Engine.time_scale = 1.0
	game_state.dev_autoplay = false

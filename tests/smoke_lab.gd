## Lab smoke (docs/COMBAT_LAB.md): AI plays every Lab fight under every preset with
## zero errors and no stall, then one fight runs through the real combat scene and
## saves its log line. Run: godot --headless --path . -s res://tests/smoke_lab.gd
## AI win rates aren't the point here, only that fights end.
extends SceneTree

const StateScript := preload("res://src/core/combat/combat_state.gd")
const Setup := preload("res://src/core/lab/lab_setup.gd")
const Rules := preload("res://src/core/combat/rules.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const DT := preload("res://src/core/data_tables.gd")
const Session := preload("res://src/core/lab/lab_session.gd")
const FightLog := preload("res://src/core/lab/fight_log.gd")

const STALL_ROUNDS := 40

var _passes := 0
var _failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("FAIL lab smoke: " + msg)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var db: Dictionary = DT.tables("res://data")
	for f in Setup.fights(db):
		for p in Rules.presets(db):
			_autoplay(db, str(f["id"]), str(p["id"]))
	check(Setup.fights(db).size() >= 12, "12 fights")
	check(Rules.presets(db).size() >= 7, "7 presets")
	await _through_the_scene()
	print("lab smoke: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _autoplay(db: Dictionary, fight_id: String, preset_id: String) -> void:
	var built := Setup.build(db, fight_id, preset_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(built["setup"]["seed"])
	var st: Object = StateScript.new(db, rng, built["setup"])
	for u in st.units:
		if u.team == "party":
			u.ai_controlled = true
	var guard := 0
	while st.result == "" and guard < 3000 and st.round_num <= STALL_ROUNDS:
		guard += 1
		if st.current == null:
			break
		AI.take_turn(st, st.current)
		st.take_events()
	var label := "%s under %s" % [fight_id, preset_id]
	check(st.result != "", "%s ends (round %d, %d steps)" % [label, st.round_num, guard])
	print("  %-16s %-14s %-5s round %d" % [fight_id, preset_id, st.result, st.round_num])


## One fight through the real scene under autoplay: it must save one valid line.
func _through_the_scene() -> void:
	var game_state: Node = root.get_node("GameState")
	game_state.dev_autoplay = true
	Engine.time_scale = 8.0
	if FileAccess.file_exists(FightLog.path()):
		DirAccess.remove_absolute(FightLog.path())
	Session.fight_id = "ledge_day"
	Session.preset_id = "cl_base"
	Session.has_parked = true
	# Loaded here: this script is parsed before the autoloads the Lab screen uses exist.
	var screen: GDScript = load("res://src/scenes/lab/lab.gd")
	check(screen != null and screen.can_instantiate(), "the Lab screen loads")
	screen.start_fight()
	var waited := 0.0
	while not FileAccess.file_exists(FightLog.path()) and waited < 240.0:
		await create_timer(0.5, true, false, true).timeout
		waited += 0.5
	var lines := FightLog.read_all()
	check(lines.size() == 1 and str(lines[0].get("preset", "")) == "cl_base" and not lines[0].get("turns", []).is_empty(), "the scene saves one valid line (%d lines, waited %.0f s)" % [lines.size(), waited])
	Engine.time_scale = 1.0
	game_state.dev_autoplay = false

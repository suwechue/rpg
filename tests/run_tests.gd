## Headless test runner for src/core (no addons needed).
## Run from the project folder:
##   godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all passed. Every method starting with test_ is run.
## GUT can replace this later; keep the tests pure (no autoloads).
extends SceneTree

const VO := preload("res://src/core/vector_ops.gd")
const Streams := preload("res://src/core/rng_streams.gd")
const CalLogic := preload("res://src/core/calendar_logic.gd")

var _passes := 0
var _failures := 0
var _current := ""


func _initialize() -> void:
	print("Project Vector core tests")
	for m in get_script().get_script_method_list():
		var method_name := str(m["name"])
		if method_name.begins_with("test_"):
			_current = method_name
			call(method_name)
	_run_suites()
	print("%d checks passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


## Every script in tests/suites/ (extending tests/suite.gd), in name order.
func _run_suites() -> void:
	var dir := DirAccess.open("res://tests/suites")
	if dir == null:
		return
	var files := Array(dir.get_files())
	files.sort()
	for f in files:
		if not str(f).ends_with(".gd"):
			continue
		var script: GDScript = load("res://tests/suites/" + str(f))
		if script == null or not script.can_instantiate():
			_failures += 1
			printerr("FAIL suite %s does not compile" % f)
			continue
		var suite: Object = script.new()
		for m in script.get_script_method_list():
			var method_name := str(m["name"])
			if method_name.begins_with("test_"):
				suite.set("current", method_name)
				suite.call(method_name)
		_passes += int(suite.get("passes"))
		_failures += int(suite.get("failures"))
		print("  %s: %d passed, %d failed" % [str(f).get_basename(), int(suite.get("passes")), int(suite.get("failures"))])


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("FAIL %s: %s" % [_current, msg])


func check_near(actual: float, expected: float, msg: String, eps: float = 0.001) -> void:
	check(absf(actual - expected) <= eps, "%s (got %.4f, expected %.4f)" % [msg, actual, expected])


func load_json(path: String) -> Variant:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data


# --- Worked examples from docs/vector_system.md -------------------------------

func test_example_1_specialization_blend() -> void:
	var base := { "heat": 20, "cold": 20, "force": 15, "motion": 15, "binding": 15, "light": 15 }
	var blended := VO.blend([base, { "force": 15, "motion": 15 }])
	check_near(VO.total(blended), 130.0, "blended total")
	var odds := VO.normalize_sum(blended)
	check_near(odds["heat"], 0.154, "heat share")
	check_near(odds["force"], 0.231, "force share")
	check_near(odds["binding"], 0.115, "binding share")
	check_near(odds["force"] / odds["heat"], 1.5, "force is 1.5x as likely as heat")


func test_example_2_invention() -> void:
	var input := { "heat": 12, "force": 4 }
	check_near(VO.complexity(input), 4.6, "complexity")
	check(VO.dominant_axis(input) == "heat", "dominant axis is heat (Thermal minigame)")
	var props: Array = []
	for p in load_json("res://data/properties.json")["properties"]:
		if p["id"] in ["searing_edge", "keen_balance", "frostbite"]:
			props.append(p)
	var performance := 0.5
	var weights := {}
	var cosines := {}
	for p in props:
		cosines[p["id"]] = VO.similarity(input, p["signature"])
		if VO.gate(input, p["gate"]):
			weights[p["id"]] = float(p["weight"]) * cosines[p["id"]] * (1.0 + performance)
	check_near(cosines["searing_edge"], 0.997, "Searing Edge cosine")
	check_near(cosines["keen_balance"], 0.263, "Keen Balance cosine")
	check_near(cosines["frostbite"], 0.077, "Frostbite cosine")
	check(not weights.has("frostbite"), "Frostbite fails its gate")
	check_near(VO.normalize_sum(weights)["searing_edge"], 0.826, "Searing Edge pick chance", 0.002)
	var picks_allowed := 1 + floori(performance * 3.0) + floori(30 / 25.0)
	check(picks_allowed == 3, "3 picks allowed")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var picks := VO.sample_unique(weights, rng, picks_allowed)
	check(picks.size() == 2, "only two properties pass the gate, so the roll stops at 2")


func test_example_3_contest() -> void:
	var m: Dictionary = load_json("res://data/matchups.json")
	var wolf := { "weakTo": ["heat"], "strongAgainst": ["cold"] }
	var a := VO.contest({ "heat": 20 }, wolf, m)
	var b := VO.contest({ "cold": 20 }, wolf, m)
	check_near(a, 30.0, "heat vs frost wolf")
	check_near(b, 12.0, "cold vs frost wolf")
	check_near(a + b, 42.0, "squad total")
	check_near(a + VO.contest({ "force": 20 }, wolf, m), 50.0, "swap cold caster for force")


# --- Operation rules and pitfalls ---------------------------------------------

func test_zero_vectors() -> void:
	check(VO.normalize_sum({}).is_empty(), "normalize_sum of empty")
	check(VO.normalize_sum({ "heat": 0 }).is_empty(), "normalize_sum of zero")
	check(VO.normalize_len({ "heat": 0 }).is_empty(), "normalize_len of zero")
	check_near(VO.similarity({}, { "heat": 1 }), 0.0, "zero vector matches nothing")
	check(VO.dominant_axis({ "heat": 0 }) == "", "zero vector has no dominant axis")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var pick := VO.sample({}, rng, ["heat", "cold"])
	check(pick == "heat" or pick == "cold", "zero vector sample falls back to equal odds")


func test_single_axis_and_ties() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		check(VO.sample({ "light": 5 }, rng) == "light", "single axis always sampled")
	var order := ["heat", "cold", "force"]
	check(VO.dominant_axis({ "force": 10, "cold": 10 }, order) == "cold", "tie broken by axis order")
	check(VO.dominant_axis({ "cold": 10, "force": 10 }, ["force", "cold"]) == "force", "tie follows given order")


func test_sample_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var counts := { "a": 0, "b": 0 }
	for i in 10000:
		counts[VO.sample({ "a": 3, "b": 1 }, rng, ["a", "b"])] += 1
	check_near(counts["a"] / 10000.0, 0.75, "3:1 odds", 0.03)


func test_seeded_streams_are_deterministic() -> void:
	var s1 = Streams.new(12345)
	var s2 = Streams.new(12345)
	var odds := { "heat": 1, "cold": 1, "force": 1, "motion": 1 }
	var order := ["heat", "cold", "force", "motion"]
	var same := true
	for i in 50:
		if VO.sample(odds, s1.stream("leveling"), order) != VO.sample(odds, s2.stream("leveling"), order):
			same = false
	check(same, "same seed and stream give the same rolls")
	var a: int = s1.stream("dungeon").randi()
	var b: int = s1.stream("combat").randi()
	check(a != b, "different streams are independent")


func test_rng_state_roundtrip() -> void:
	var s1 = Streams.new(99)
	s1.stream("combat").randi()
	s1.stream("combat").randi()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s1.get_state()))
	var s2 = Streams.new(0)
	s2.set_state(saved)
	check(s1.stream("combat").randi() == s2.stream("combat").randi(), "resumed stream continues identically")


func test_shift_caps_and_floor() -> void:
	var v := VO.shift({ "int": 19 }, { "int": 3 }, { "int": 20 })
	check_near(v["int"], 20.0, "cap applies")
	var bond := VO.shift({ "bond": -95 }, { "bond": -20 }, { "bond": 100 }, -100.0)
	check_near(bond["bond"], -100.0, "signed floor applies")
	var original := { "str": 4 }
	VO.shift(original, { "str": 1 })
	check(original["str"] == 4, "shift does not modify its input")


func test_gate_and_bond_tiers() -> void:
	check(VO.gate({ "cha": 10, "int": 3 }, { "cha": 10 }), "gate passes at the line")
	check(not VO.gate({ "cha": 9 }, { "cha": 10 }), "gate fails below the line")
	var tiers: Array = load_json("res://data/bonds.json")["tiers"]
	check(VO.gate_tier(0, tiers) == "Stranger", "0 is Stranger")
	check(VO.gate_tier(41, tiers) == "Friend", "41 is Friend")
	check(VO.gate_tier(-60, tiers) == "Enemy", "-60 is Enemy")
	check(VO.gate_tier(100, tiers) == "Unbreakable", "100 is Unbreakable")


func test_decay() -> void:
	check_near(VO.decay({ "bond": 50 }, 0.05)["bond"], 47.5, "bond decays toward 0")
	check_near(VO.decay({ "pride": 0 }, 0.5, { "pride": 70 })["pride"], 35.0, "disposition returns to rest")


# --- Calendar -----------------------------------------------------------------

func test_calendar_day_parts_and_ap() -> void:
	var cal = CalLogic.new(load_json("res://data/calendar.json"))
	check(cal.day_name() == "mon" and cal.part_id() == "before_school", "starts Monday before school")
	check(cal.ap == 2, "before school has 2 AP")
	check(cal.spend_ap(2), "can spend 2 AP")
	check(not cal.spend_ap(1), "cannot overspend")
	for i in 8:
		cal.advance_part()
	check(cal.day_name() == "tue" and cal.part_index == 0, "8 parts make a weekday")
	for i in 8 * 3 + 6:
		cal.advance_part()
	check(cal.is_boss_night(), "Friday evening is boss night")
	cal.advance_part()
	cal.advance_part()
	check(cal.is_weekend() and cal.part_id() == "morning", "weekend after Friday night")
	check(cal.ap == 3, "weekend parts have 3 AP")


# --- Data integrity -----------------------------------------------------------

func test_all_data_files_parse() -> void:
	var bad: Array[String] = []
	_collect_bad_json("res://data", bad)
	check(bad.is_empty(), "unparseable JSON: %s" % ", ".join(PackedStringArray(bad)))


func _collect_bad_json(path: String, bad: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		bad.append(path)
		return
	for f in dir.get_files():
		if f.ends_with(".json") and load_json(path + "/" + f) == null:
			bad.append(path + "/" + f)
	for d in dir.get_directories():
		_collect_bad_json(path + "/" + d, bad)

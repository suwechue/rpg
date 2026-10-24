## Base for test suites in tests/suites/. run_tests.gd instantiates every suite,
## calls each test_ method and adds up passes and failures. Suites stay pure:
## no autoloads, data comes from DataTables.
extends RefCounted

const DT := preload("res://src/core/data_tables.gd")

var passes := 0
var failures := 0
var current := ""
var _db: Dictionary = {}


func db() -> Dictionary:
	if _db.is_empty():
		_db = DT.tables("res://data")
	return _db


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL %s.%s: %s" % [get_script().resource_path.get_file().get_basename(), current, msg])


func check_near(actual: float, expected: float, msg: String, eps: float = 0.001) -> void:
	check(absf(actual - expected) <= eps, "%s (got %.4f, expected %.4f)" % [msg, actual, expected])


func seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

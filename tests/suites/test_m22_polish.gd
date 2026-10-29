## M22: settings choices and achievements.
extends "res://tests/suite.gd"

const SR := preload("res://src/core/settings_rules.gd")
const Ach := preload("res://src/core/achievements.gd")


func test_settings() -> void:
	check(SR.cycle([25, 45, 90], 45) == 90 and SR.cycle([25, 45, 90], 90) == 25, "choices cycle and wrap")
	check(SR.step_volume(db(), 6.0, true) == 6.0 and SR.step_volume(db(), -30.0, false) == -30.0, "volumes clamp")
	check(SR.step_volume(db(), 0.0, false) < 0.0, "volume steps down")
	check(SR.cfg(db())["rebindable"].has("interact"), "interact can be rebound")


func test_achievements() -> void:
	var j := { "runs": 5, "endings": { "act1": true }, "friendScenes": ["a", "b", "c", "d", "e"], "deductions": ["x"], "combos": [] }
	var fresh := Ach.check(db(), j)
	var ids: Array = fresh.map(func(a: Dictionary) -> String: return str(a["id"]))
	check(ids.has("first_ending") and ids.has("act1") and ids.has("friends_5") and ids.has("deduce_1") and ids.has("runs_5"), "earned: %s" % str(ids))
	check(not ids.has("deduce_all") and not ids.has("combos_10"), "not the ones still in progress")
	check(bool(j.get("alt_narrator", false)), "Act 1 unlocks the alternate narrator lines")
	check(Ach.check(db(), j).is_empty(), "each is earned once")
	check(Ach.progress({ "arena": { "bestWave": 12 } }, "arena.bestWave") == 12, "arena progress")

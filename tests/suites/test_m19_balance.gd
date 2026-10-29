## M19: unlock waves, part-time jobs and difficulty modes.
extends "res://tests/suite.gd"

const Locs := preload("res://src/core/town/locations.gd")
const RM := preload("res://src/core/run/run_model.gd")


func test_unlock_waves() -> void:
	var run := RM.new_run(db(), 5, "mage", seeded(5))
	check(Locs.closed_reason(db(), run, "arcade", 1, "after_school") != "", "the arcade waits for week 2")
	check(Locs.closed_reason(db(), run, "hospital_closed_wing", 3, "after_school") != "", "the closed wing waits for week 4")
	for w in ["2", "3", "4", "5"]:
		check(str(db()["unlocks"]["weeks"].get(w, "")) != "", "week %s has an announcement" % w)
	var opened := {}
	for l in db()["town/locations"]["locations"]:
		opened[int(l.get("openFromWeek", 0))] = true
	check(opened.has(2) and opened.has(3) and opened.has(4), "something opens in weeks 2, 3 and 4")


func test_jobs() -> void:
	var run := RM.new_run(db(), 5, "mage", seeded(5))
	var jobs := 0
	for id in ["garys_deli", "forge", "hospital", "library"]:
		for a in Locs.rec(db(), id).get("activities", []):
			if a.has("job"):
				jobs += 1
				check(int(a["effects"].get("money", 0)) > 0, "%s pays" % id)
				check(not db()["jobs"]["events"].get(str(a["job"]), []).is_empty(), "%s has shift events" % id)
	check(jobs == 4, "four part-time jobs (%d)" % jobs)
	var week1 := Locs.activities(db(), run, "forge", "after_school", { "week": 1 })
	check(not week1.any(func(a: Dictionary) -> bool: return a.has("job")), "the forge isn't hiring in week 1")


func test_modes() -> void:
	var m: Dictionary = db()["run_modes"]["modes"]
	check(m.has("permadeath") and m.has("mercy") and m.has("story"), "three difficulty modes")
	check(bool(m["mercy"].get("rewind", false)) and str(m["story"].get("combat", "")) == "story", "Mercy rewinds; Story uses easier fights")
	var story: Dictionary = db()["combat_rules"]["difficulties"]["story"]
	check(float(story["enemyDamageMul"]) < 1.0, "Story fights hit softer")

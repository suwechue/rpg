## TL (docs/TOWN_LIFE.md): the town during school hours, getting caught,
## favors and events, gear, social gaps, combat stubs, polish.
extends "res://tests/suite.gd"

const Locs := preload("res://src/core/town/locations.gd")
const Sched := preload("res://src/core/town/schedule.gd")
const Crowd := preload("res://src/core/town/crowd.gd")
const RM := preload("res://src/core/run/run_model.gd")


func run_() -> Dictionary:
	return RM.new_run(db(), 5, "mage", seeded(5))


## Part 1: a skipped period has places open and people around.
func test_school_hours() -> void:
	check(Locs.expand_hours(db(), ["@schoolHours", "lunch"]) == ["period_1", "period_2", "period_3", "lunch"], "the @schoolHours alias expands")
	var run := run_()
	for part in ["period_1", "period_2", "period_3"]:
		var open := 0
		for l in db()["town/locations"]["locations"]:
			if str(l.get("zone", "")) != "school" and Locs.closed_reason(db(), run, str(l["id"]), 2, part) == "":
				open += 1
		check(open >= 6, "%s: %d places open in town" % [part, open])
		var people := 0
		for id in Sched.npc_ids(db()):
			var loc := Sched.location_of(db(), run, str(id), "tue", part, 8)
			if loc != "" and str(Locs.rec(db(), loc).get("zone", "")) != "school" and not loc.ends_with("_house") and loc != "elm_apartments":
				people += 1
		for zone in ["downtown", "residential", "outskirts"]:
			people += Crowd.generate(db(), run, zone, part, 2, seeded(1)).size()
		check(people >= 8, "%s: %d people around" % [part, people])
	var daytime := 0
	for l in db()["town/locations"]["locations"]:
		for a in l.get("activities", []):
			if bool(a.get("daytime", false)):
				daytime += 1
	check(daytime >= 4, "at least 4 daytime-only activities (%d)" % daytime)
	for id in ["officer_pruitt", "rae", "walt", "mo", "mr_ellis"]:
		check(not db().get("npcs/" + id, {}).is_empty(), "%s exists" % id)

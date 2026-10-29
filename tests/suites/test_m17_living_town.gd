## M17: generated townsfolk, rumors, barks, party banter and town changes.
extends "res://tests/suite.gd"

const Crowd := preload("res://src/core/town/crowd.gd")
const RM := preload("res://src/core/run/run_model.gd")


func run_() -> Dictionary:
	return RM.new_run(db(), 5, "mage", seeded(5))


func test_generate_crowd() -> void:
	var run := run_()
	var people := Crowd.generate(db(), run, "downtown", "midday", 1, seeded(2))
	check(people.size() == 11, "a weekend square crowd: 7 adults + 4 students (%d)" % people.size())
	var names := {}
	for p in people:
		check(Assets_has(str(p["sprite"])), "%s has a sprite" % p["name"])
		check(str(p["rumor"]) != "" and not p["disposition"].is_empty(), "%s has a rumor and a disposition" % p["name"])
		names[p["name"]] = true
	check(names.size() >= 9, "names vary (%d of %d)" % [names.size(), people.size()])
	check(Crowd.generate(db(), run, "downtown", "midday", 1, seeded(2)) == people, "the crowd is seeded")
	check(Crowd.generate(db(), run, "school", "period_1", 1, seeded(2)).is_empty(), "nobody in the halls during class")


func Assets_has(id: String) -> bool:
	return db()["assets/manifest"]["assets"].has(id)


func test_rumors_follow_the_signature() -> void:
	var run := run_()
	run["signature"] = { "cold": 50 }
	var cold: Array = db()["town/crowd"]["rumors"]["cold"]
	check(cold.has(Crowd.rumor(db(), run, 1, seeded(1))), "rumors hint at the week's dominant Vector")


func test_banter() -> void:
	var run := run_()
	check(Crowd.zone_comment(db(), "kelly", "school") != "" and Crowd.zone_comment(db(), "nobody", "downtown") != "", "members comment on zones (with a default)")
	check(Crowd.pair_line(db(), run, ["dex", "theo"], seeded(1)) == "", "pair banter waits for Bond")
	run["bonds"] = { "dex": 30.0, "theo": 30.0 }
	check(Crowd.pair_line(db(), run, ["dex", "theo"], seeded(1)) != "", "and unlocks with it")


func test_town_changes() -> void:
	var run := run_()
	var ctx := { "week": 1, "day": "mon", "part": "after_school" }
	check(Crowd.changes(db(), run, ctx, "school").any(func(c: Dictionary) -> bool: return c["id"] == "poster_pep"), "week 1: the pep rally poster")
	check(Crowd.changes(db(), run, ctx, "downtown").is_empty(), "no crater or flyers yet")
	RM.set_flag(run, "dance_interrupted")
	RM.set_flag(run, "forge_relit")
	var late := { "week": 5, "day": "sat", "part": "midday" }
	var ids: Array = Crowd.changes(db(), run, late, "downtown").map(func(c: Dictionary) -> String: return str(c["id"]))
	check(ids.has("fountain_crater") and ids.has("missing_flyers") and ids.has("poster_dance"), "week 5: the crater, flyers and the dance poster")
	check(Crowd.changes(db(), run, late, "outskirts").any(func(c: Dictionary) -> bool: return c["id"] == "forge_relit"), "the relit forge smokes")
	check(db()["town/changes"]["changes"].size() >= 5, "at least 5 choice-driven changes")

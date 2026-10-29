## M13: class periods as cutscenes (the bell, the walk, the class and its
## seating chart), the locker, nap spots from data, the new school spots.
extends "res://tests/suite.gd"

const SchoolScenes := preload("res://src/core/run/school_scenes.gd")
const CS := preload("res://src/core/story/cutscenes.gd")
const Locker := preload("res://src/core/town/locker.gd")
const Sched := preload("res://src/core/town/schedule.gd")


func test_class_cutscene_steps() -> void:
	var cls: Dictionary = db()["school_classes"]["classes"][0]
	var steps := SchoolScenes.steps(db(), cls, 2, "Coach Byrne", seeded(4))
	check(CS.problems(db(), { "id": "class", "steps": steps }).is_empty(), "class steps are valid cutscene steps")
	check(steps.any(func(s: Dictionary) -> bool: return s["type"] == "sfx" and s["event"] == "bell"), "the bell rings")
	check(steps.any(func(s: Dictionary) -> bool: return s["type"] == "seating"), "the class shows a seating chart")
	check(steps.all(func(s: Dictionary) -> bool: return not str(s.get("text", "")).contains("{")), "every placeholder is filled")


func test_seating() -> void:
	var cls: Dictionary = db()["school_classes"]["classes"][0]
	var s := SchoolScenes.seating(db(), cls, seeded(1))
	var flat: Array = []
	for row in s["rows"]:
		flat.append_array(row)
	check(flat.count("@you") == 1, "you have exactly one seat")
	for m in s["mates"]:
		check(cls["classmates"].has(m) and flat.has(m), "%s sits in the class" % m)
	check(SchoolScenes.seating(db(), cls, seeded(1)) == s, "the chart is seeded")


func test_locker() -> void:
	var run := { "inventory": { "squad_ribbon": 2 } }
	check(Locker.store(run, "squad_ribbon") and int(run["locker"]["squad_ribbon"]) == 1 and int(run["inventory"]["squad_ribbon"]) == 1, "store an item")
	check(Locker.take(run, "squad_ribbon") and not run["locker"].has("squad_ribbon") and int(run["inventory"]["squad_ribbon"]) == 2, "take it back")
	check(not Locker.take(run, "squad_ribbon"), "can't take what isn't there")


func test_nap_spots_and_hangouts() -> void:
	var naps := Sched.nap_spots(db())
	check(naps.has("bleachers") and naps.has("back_stairs"), "the new school spots are nap spots")
	var locs: Array = db()["town/locations"]["locations"].map(func(l: Dictionary) -> String: return str(l["id"]))
	for n in naps:
		check(locs.has(n), "nap spot %s is a location" % n)

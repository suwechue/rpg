## M20: mirror rooms on Upside-Down floors, leaning toward places touched this week.
extends "res://tests/suite.gd"

const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const RM := preload("res://src/core/run/run_model.gd")


func test_mirror_rooms() -> void:
	var run := RM.new_run(db(), 5, "mage", seeded(5))
	var themes: Array = db()["rooms/themes"]["themes"].map(func(t: Dictionary) -> String: return str(t["id"]))
	for r in db()["rooms/mirror_rooms"]["rooms"]:
		check(themes.has(str(r["theme"])), "%s uses a real theme" % r["id"])
	var seen := 0
	var deli := 0
	run["visited"] = { "2": ["garys_deli"] }
	for i in 200:
		var m := Gen.pick_mirror(db(), run, 2, seeded(i))
		if not m.is_empty():
			seen += 1
			if m["id"] == "frozen_deli":
				deli += 1
	check(seen > 40 and seen < 110, "about a third of fight rooms are mirrors (%d of 200)" % seen)
	check(deli * 3 > seen, "places you visited show up more (%d frozen delis of %d)" % [deli, seen])
	var f := Gen.generate(db(), run, 2, "tue")
	var layouts := DT.index_under(db(), "rooms/", "layouts")
	for room in f["rooms"]:
		if room.has("mirror"):
			check(str(room["layout"]) != "", "mirror rooms get a layout")

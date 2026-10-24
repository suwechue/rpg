## M9: gameplay log tallies.
extends "res://tests/suite.gd"

const Log := preload("res://src/core/run/play_log.gd")


func test_play_log_day_tallies() -> void:
	var d := Log.new_day(1, "Monday")
	Log.add_ap(d, "talk", 1)
	Log.add_ap(d, "talk", 1)
	Log.add_ap(d, "shop:deli", 1)
	Log.add_fight(d, "win")
	Log.add_fight(d, "lose")
	Log.add_fight(d, "flee")
	check(int(d["ap"]["talk"]) == 2 and int(d["ap"]["shop:deli"]) == 1, "AP counted per kind")
	check(int(d["won"]) == 1 and int(d["lost"]) == 1 and int(d["fled"]) == 1, "fights counted by result")


func test_play_log_summary() -> void:
	var a := Log.new_day(1, "Monday")
	Log.add_ap(a, "shop:deli", 1)
	Log.add_ap(a, "shop:arcade", 2)
	Log.add_fight(a, "win")
	a["seconds"] = 100.0
	var b := Log.new_day(1, "Tuesday")
	Log.add_ap(b, "talk", 3)
	b["seconds"] = 50.0
	var s := Log.summarize([a, b, { "type": "note" }])
	check(int(s["days"]) == 2, "two day records")
	check(int(s["ap"]["shop"]) == 3 and int(s["ap"]["talk"]) == 3, "AP grouped by action type")
	check(int(s["won"]) == 1 and int(s["lost"]) == 0, "fight totals")
	check(is_equal_approx(float(s["avgSeconds"]), 75.0), "average seconds per day")
	check(Log.group("activity:library") == "activity" and Log.group("talk") == "talk", "kind groups")

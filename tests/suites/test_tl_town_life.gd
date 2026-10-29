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


## Part 2: getting caught, parent trust, patrol cones, the attendance streak.
func test_truancy() -> void:
	const Tr := preload("res://src/core/town/truancy.gd")
	var run := run_()
	var square := Tr.risk(db(), run, "town_square", [])
	var alley := Tr.risk(db(), run, "hidden_alley", [])
	check(square > alley, "the square is riskier than the alley")
	check(Tr.risk(db(), run, "park", ["officer_pruitt"]) > Tr.risk(db(), run, "park", []), "Officer Pruitt nearby raises the risk")
	run["skips_week"] = 3
	check(Tr.risk(db(), run, "hidden_alley", []) > alley, "more skips, more risk")
	check(Tr.label(db(), 0.05) == "low" and Tr.label(db(), 0.6) == "high", "risk labels")
	var r := Tr.resolve(db(), run, "take", 5, 0.0, seeded(1))
	check(not r["free"] and run["detention_pending"] and Tr.trust(db(), run) == 40, "taking it: detention and a call home")
	var ran := Tr.resolve(db(), run_(), "run", 5, 0.9, seeded(1))
	check(ran["free"], "a good chase gets away")
	var frees := 0
	for i in 40:
		if Tr.resolve(db(), run_(), "talk", 12, 0.0, seeded(i))["free"]:
			frees += 1
	check(frees > 20, "high Charisma usually talks its way out (%d of 40)" % frees)
	var cov := run_()
	cov["flags"]["ellis_covers"] = true
	check(Tr.resolve(db(), cov, "take", 5, 0.0, seeded(1))["key"] == "truancy.covered", "Mr. Ellis covers for you once")
	var low := run_()
	Tr.change_trust(db(), low, -30)
	check(Tr.night_ap_delta(db(), low) == -1 and low["texts"].any(func(t: Dictionary) -> bool: return t["from"] == "parent"), "low trust: a curfew and a text home")
	var high := run_()
	Tr.change_trust(db(), high, 30)
	check(Tr.allowance(db(), high) > 0, "high trust: an allowance")
	var cone := Tr.cone(db(), Vector2i(5, 4), Vector2i.RIGHT, { Vector2i(8, 4): true })
	check(cone.has(Vector2i(6, 4)) and cone.has(Vector2i(7, 5)) and not cone.has(Vector2i(8, 4)), "patrol cones widen and walls stop them")
	var good := run_()
	good["attendance_week"] = { "physics": 3 }
	var st0 := int(good["player"]["stats"]["int"])
	check(Tr.week_end(db(), good) != "", "a perfect week gives a stat")
	check(Locs.closed_reason(db(), run_(), "hallways", 2, "period_2") == "", "the hallways can be snuck into during class")


## Part 3: town events, the favor board, opened places, visitable houses.
func test_town_content() -> void:
	const Fav := preload("res://src/core/town/favors.gd")
	check(db()["story/town_events"]["stories"].size() >= 15, "at least 15 town events (%d)" % db()["story/town_events"]["stories"].size())
	for s in db()["story/town_events"]["stories"]:
		var ev: Dictionary = s["steps"][0].get("event", {})
		check(ev.get("choices", []).size() >= 2, "%s has a choice" % s["id"])
	check(Fav.all(db()).size() >= 15, "at least 15 favors")
	var run := run_()
	var b1 := Fav.board(db(), run, 2, seeded(1))
	check(b1.size() == int(db()["town/favors"]["perWeek"]) and Fav.board(db(), run, 2, seeded(9)) == b1, "the board is posted once a week")
	Fav.board(db(), run, 3, seeded(2))
	check(int(run["favorBoard"]["week"]) == 3 and run["favorBoard"]["done"].is_empty(), "a new week posts a fresh board")
	var run2 := run_()
	var board2 := Fav.board(db(), run2, 2, seeded(1))
	Fav.complete(run2, str(board2[0]))
	check(not Fav.board(db(), run2, 2, seeded(1)).has(str(board2[0])), "a done favor comes off the board")
	var opened := 0
	for id in ["train_station", "town_museum", "movie_theater"]:
		if str(Locs.rec(db(), id).get("status", "")) == "OPEN":
			opened += 1
	check(opened == 3, "the station, museum and theater are open")
	check(Locs.closed_reason(db(), run_(), "train_station", 2, "after_school") != "" and Locs.closed_reason(db(), run_(), "train_station", 3, "after_school") == "", "the station opens in week 3")
	var houses := 0
	for l in db()["town/locations"]["locations"]:
		if l.has("visitBond"):
			houses += 1
	check(houses >= 4, "at least 4 visitable houses (%d)" % houses)
	var friend := run_()
	check(Locs.door(db(), friend, "theo_house", 2, "tue", "after_school", 3)["kind"] != "enter", "a stranger's house stays shut")
	friend["bonds"]["theo"] = 50.0
	check(Locs.door(db(), friend, "theo_house", 2, "tue", "after_school", 3)["kind"] == "enter", "at Friend Bond you can visit")

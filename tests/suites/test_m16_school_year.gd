## M16: class events with repeats, the school calendar, clubs, exams and the
## report card.
extends "res://tests/suite.gd"

const Clubs := preload("res://src/core/run/clubs.gd")
const Exams := preload("res://src/core/run/exams.gd")
const School := preload("res://src/core/run/school.gd")
const StoryRules := preload("res://src/core/story/story.gd")
const CS := preload("res://src/core/story/cutscenes.gd")
const RM := preload("res://src/core/run/run_model.gd")


func fresh() -> Dictionary:
	return RM.new_run(db(), 5, "mage", seeded(5))


func test_class_events_per_class() -> void:
	var counts := {}
	for e in db()["events/class_events"]["events"]:
		counts[str(e.get("class", "any"))] = int(counts.get(str(e.get("class", "any")), 0)) + 1
	for c in db()["school_classes"]["classes"]:
		check(int(counts.get(str(c["id"]), 0)) >= 8, "%s has 8+ class events (%d)" % [c["id"], int(counts.get(str(c["id"]), 0))])


func test_repeats_are_rare_and_short() -> void:
	var run := fresh()
	var picks := {}
	var rng := seeded(3)
	for i in 40:
		var r := School.attend(db(), run, 1, rng, { "week": 2, "day": "tue", "part": "period_1", "period": 1 })
		if not r["event"].is_empty():
			picks[str(r["event"]["id"])] = int(picks.get(str(r["event"]["id"]), 0)) + 1
	check(picks.size() >= 6, "40 periods show a spread of events (%d different)" % picks.size())
	var repeated: Array = run["class_events_seen"].keys().filter(func(k: String) -> bool: return int(run["class_events_seen"][k]) > 1)
	check(not repeated.is_empty(), "some events repeat over 40 periods")


func test_calendar() -> void:
	for id in ["cal_w2_pep_rally", "cal_w3_club_fair", "cal_w4_test_week", "cal_w4_report_card", "cal_w5_dance"]:
		check(not StoryRules.find(db(), id).is_empty(), "%s is on the calendar" % id)
	var run := fresh()
	check(StoryRules.due(db(), run, { "week": 3, "day": "mon", "part": "lunch" }, true).has("cal_w3_club_fair"), "the club fair in week 3")
	check(StoryRules.due(db(), run, { "week": 4, "day": "fri", "part": "after_school" }, true).has("cal_w4_report_card"), "the report card on week 4 Friday")
	check(StoryRules.due_at(db(), run, { "week": 2, "day": "mon", "part": "after_school" }, "school", []).has("cal_w2_pep_rally"), "the pep rally at school in week 2")
	for c in CS.all(db()):
		if str(c["id"]).begins_with("cal_"):
			check(CS.problems(db(), c).is_empty(), "%s is a valid cutscene" % c["id"])


func test_clubs() -> void:
	var run := fresh()
	check(Clubs.join(db(), run, "drama") == "" and Clubs.join(db(), run, "science") == "", "join two clubs")
	check(Clubs.join(db(), run, "art") == "full", "but not a third")
	check(Clubs.join(db(), run, "drama") != "", "or the same one twice")
	check(Clubs.meeting_today(db(), run, "tue") == "drama" and Clubs.meeting_today(db(), run, "mon") == "science", "meetings land on their days")
	check(Clubs.meeting_today(db(), run, "sat") == "", "no meeting on the weekend")
	var ev := Clubs.meeting_event(db(), run, "drama", seeded(1))
	check(not ev["effects"].is_empty() and str(ev["text"]) != "" and int(run["clubMeetings"]["drama"]) == 1, "a meeting gives stat XP and Bond and is counted")


func test_exams() -> void:
	var run := fresh()
	var cls := School.class_rec(db(), "physics")
	var low := Exams.score(db(), run, cls)
	run["grades"]["ms_g"] = 40.0
	check(Exams.score(db(), run, cls) > low, "attendance (Grade) raises the exam score")
	var rep := Exams.report(db(), run, ["physics", "drama", "earth_science"])
	check(rep["rows"].size() == 3 and not rep["parent"].is_empty(), "the report card has every class and a reaction")
	check(Exams.letter(db(), 95)["letter"] == "A" and Exams.letter(db(), 10)["letter"] == "F", "letters by score")
	check(not Exams.report_effects(db(), rep).is_empty(), "the report card has effects")

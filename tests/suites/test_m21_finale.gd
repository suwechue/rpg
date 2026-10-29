## M21: the Act 1 finale (the dance, the fountain, the square), the
## aftermath weekend with leak points, and End of Act 1.
extends "res://tests/suite.gd"

const StoryRules := preload("res://src/core/story/story.gd")
const CS := preload("res://src/core/story/cutscenes.gd")
const Crowd := preload("res://src/core/town/crowd.gd")
const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const RM := preload("res://src/core/run/run_model.gd")


func test_finale_in_the_square() -> void:
	var run := RM.new_run(db(), 5, "mage", seeded(5))
	var f := Gen.generate(db(), run, 5, "fri")
	var boss: Array = f["rooms"].filter(func(r: Dictionary) -> bool: return r["type"] == "boss")
	check(not boss.is_empty() and boss[0]["layout"] == "fountain_square" and boss[0]["enemies"] == ["mirror_town"], "week 5's boss is the Mirror Town in the square")
	var dance := CS.find(db(), "cal_school_dance")
	check(str(dance).contains("act1_finale") and CS.problems(db(), dance).is_empty(), "the dance ends with the fountain")


func test_aftermath_and_end() -> void:
	var run := RM.new_run(db(), 5, "mage", seeded(5))
	check(not StoryRules.due(db(), run, { "week": 5, "day": "sat", "part": "morning" }, true).has("act1_aftermath"), "no aftermath without the finale")
	RM.set_flag(run, "act1_finale_won")
	check(StoryRules.due(db(), run, { "week": 5, "day": "sat", "part": "morning" }, true).has("act1_aftermath"), "the aftermath on Saturday")
	check(StoryRules.due(db(), run, { "week": 5, "day": "sun", "part": "weekend_evening" }, true).has("act1_end"), "End of Act 1 on Sunday evening")
	var ctx := { "week": 5, "day": "sat", "part": "midday" }
	var leaks := Crowd.changes(db(), run, ctx, "downtown").filter(func(c: Dictionary) -> bool: return c["kind"] == "leak")
	check(not leaks.is_empty() and leaks[0].has("fight"), "leak points open in daylight")
	RM.set_flag(run, "leak_square_closed")
	check(Crowd.changes(db(), run, ctx, "downtown").filter(func(c: Dictionary) -> bool: return c["kind"] == "leak").is_empty(), "a sealed leak closes")
	check(FileAccess.file_exists("res://docs/ACT2.md"), "docs/ACT2.md exists")


func test_win_flags() -> void:
	const StateScript := preload("res://src/core/combat/combat_state.gd")
	var ch := preload("res://src/core/character.gd").create(db(), "fighter", seeded(1), { "isPlayer": true })
	var st := StateScript.new(db(), seeded(2), { "layout": { "map": ["P..E"] }, "party": [{ "char": ch }], "enemies": [DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)], "winFlag": "leak_test" })
	check(st.finish()["winFlag"] == "leak_test", "a fight carries its win flag to the summary")

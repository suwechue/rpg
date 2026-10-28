## P2 Part 3 (ROADMAP M14 and M15): cutscene data, branching, hooks in data.
extends "res://tests/suite.gd"

const CS := preload("res://src/core/story/cutscenes.gd")
const StoryRules := preload("res://src/core/story/story.gd")


func test_cutscenes_are_valid() -> void:
	var all := CS.all(db())
	check(all.size() >= 15, "cutscenes exist (%d)" % all.size())
	for c in all:
		var probs := CS.problems(db(), c)
		check(probs.is_empty(), "%s is valid %s" % [c["id"], str(probs)])
	for id in ["intro_moving_day", "intro_night", "kelly_floor_intro", "kelly_floor_end", "mascot_intro", "mascot_phase2", "arena_first", "arena_boss_first", "arena_new_best"]:
		check(not CS.find(db(), id).is_empty(), "%s exists" % id)


func test_branches() -> void:
	var end := CS.find(db(), "kelly_floor_end")
	var saved := CS.expand(end["steps"], { "survived_w1_monday": true })
	var lost := CS.expand(end["steps"], {})
	check(str(saved[0].get("speaker", "")) == "kelly" and str(lost[0].get("type", "")) == "narrator", "if_flag picks the branch for the run")
	check(not CS.problems(db(), { "id": "x", "steps": [{ "type": "dance" }] }).is_empty(), "unknown steps are caught")


func test_hooks_in_data() -> void:
	var mascot: Dictionary = DT.index_under(db(), "enemies/", "enemies")["hollow_mascot"]
	check(str(mascot.get("cutscenes", {}).get("phase2", "")) == "mascot_phase2", "the Hollow Mascot has intro and phase 2 cutscenes")
	var ev := StoryRules.find(db(), "w1_evening")
	check(ev["steps"].any(func(s: Dictionary) -> bool: return str(s.get("type", "")) == "cutscene"), "the Kelly floor plays cutscenes")
	for part in ["before_school", "period_1", "period_2", "lunch", "period_3", "after_school", "night"]:
		check(not StoryRules.find(db(), "w1_day_" + part).is_empty(), "tutorial day: %s has its beat" % part)

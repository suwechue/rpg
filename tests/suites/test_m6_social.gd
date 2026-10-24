## M6: dialogue checks, Bonds, gifts, recruitment and the Kelly Monday scenario.
extends "res://tests/suite.gd"

const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Dlg := preload("res://src/core/social/dialogue_check.gd")
const BondRules := preload("res://src/core/social/bonds.gd")
const StoryRules := preload("res://src/core/story/story.gd")
const School := preload("res://src/core/run/school.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")


func fresh(seed_value: int = 1) -> Dictionary:
	return RM.new_run(db(), seed_value, "mage", seeded(seed_value))


func topic(npc: String, id: String) -> Dictionary:
	for t in db()["npcs/" + npc]["topics"]:
		if t["id"] == id:
			return t
	return {}


func test_topic_data() -> void:
	var axes: Array = db()["spaces"]["disposition"]["axes"]
	var seen := {}
	var count := 0
	for key in db():
		if not str(key).begins_with("npcs/"):
			continue
		for t in db()[key].get("topics", []):
			count += 1
			check(not seen.has(t["id"]), "unique topic id %s" % t["id"])
			seen[t["id"]] = true
			check(str(t.get("label", "")) != "" and str(t.get("line", "")) != "", "%s has a label and a line" % t["id"])
			for a in t.get("tone", {}):
				check(axes.has(a), "%s tone axis %s is a disposition axis" % [t["id"], a])
	check(count >= 120, "about 4 topics per character (%d)" % count)
	for id in ["kelly", "theo", "dex", "priya", "mara"]:
		check(db()["npcs/" + id]["topics"].size() >= 4, "%s is fully authored" % id)


func test_topic_gates() -> void:
	var run := fresh()
	var ctx := { "week": 1 }
	check(Dlg.topic_lock(db(), run, "kelly", topic("kelly", "kelly_cheer"), ctx) == "", "no gate on the compliment")
	check(Dlg.topic_lock(db(), run, "gary", topic("gary_gossip".split("_")[0], "gary_gossip"), ctx) == "CHA 4" or run["player"]["stats"]["cha"] >= 4, "CHA gate")
	check(Dlg.topic_lock(db(), run, "kelly", topic("kelly", "kelly_walk"), ctx) != "", "walking her home needs CHA 8 and Acquaintance")
	run["player"]["stats"]["cha"] = 10
	check(Dlg.topic_lock(db(), run, "kelly", topic("kelly", "kelly_walk"), ctx).begins_with("Bond"), "then the Bond tier")
	run["bonds"]["kelly"] = 20.0
	check(Dlg.topic_lock(db(), run, "kelly", topic("kelly", "kelly_walk"), ctx) == "", "unlocked")
	check(Dlg.topic_lock(db(), run, "ms_nonsense", topic("ms_nonsense", "nonsense_upside"), ctx) != "", "week-locked lore")


func test_misheard_chance() -> void:
	var run := fresh()
	run["player"]["stats"]["cha"] = 5
	check_near(Dlg.misheard_chance(db(), run, 0.2, "neutral"), 0.2 * 0.8, "base x (1 - CHA/25)")
	check_near(Dlg.misheard_chance(db(), run, 0.2, "bad"), 0.2 * 0.8 * 1.5, "bad mood x1.5")
	run["player"]["stats"]["cha"] = 20
	check_near(Dlg.misheard_chance(db(), run, 0.05, "neutral"), 0.02, "never below 2%")
	run["player"]["stats"]["cha"] = 5
	run["player"]["traits"] = ["clear_speaker"]
	check_near(Dlg.misheard_chance(db(), run, 0.2, "neutral"), 0.08, "Clear Speaker halves it")


func test_reception_by_match() -> void:
	var run := fresh()
	var kind := { "kindness": 1.0 }
	var cruel := { "kindness": -1.0 }
	check(Dlg.reception(db(), run, "mara", kind, "neutral") > 0.5, "Mara loves sincerity")
	check(Dlg.reception(db(), run, "mara", cruel, "neutral") < 0.0, "and hates cruelty")
	check(Dlg.reception(db(), run, "kelly", { "pride": 1.0 }, "neutral") > Dlg.reception(db(), run, "kelly", { "kindness": 1.0 }, "neutral"), "compliments land with proud Kelly")
	check(Dlg.reception(db(), run, "mara", kind, "good") > Dlg.reception(db(), run, "mara", kind, "bad"), "mood matters")


func test_say_changes_bond_and_hides_topic() -> void:
	var run := fresh(5)
	var t := topic("mara", "mara_quiet")
	var r := Dlg.say(db(), run, "mara", t, seeded(1), { "week": 1 })
	check(r["outcome"] != "" and RM.bond(run, "mara") != 10.0, "Bond moved from 10 (%s, misheard %s)" % [r["outcome"], r["misheard"]])
	var listed := []
	for x in Dlg.topics(db(), run, "mara", { "week": 1 }):
		listed.append(x["id"])
	check(not listed.has("mara_quiet"), "a topic is used up for the week")
	var listed2 := []
	for x in Dlg.topics(db(), run, "mara", { "week": 2 }):
		listed2.append(x["id"])
	check(listed2.has("mara_quiet"), "available again next week")
	var a := fresh(9)
	var b := fresh(9)
	var ra := Dlg.say(db(), a, "kelly", topic("kelly", "kelly_joke"), seeded(3), { "week": 1 })
	var rb := Dlg.say(db(), b, "kelly", topic("kelly", "kelly_joke"), seeded(3), { "week": 1 })
	check(ra["heard"] == rb["heard"] and ra["bond"] == rb["bond"], "seeded conversations repeat")


func test_misheard_reads_badly() -> void:
	var misheard := 0
	var worse := 0
	for s in 200:
		var run := fresh(s)
		run["player"]["stats"]["cha"] = 1
		var r := Dlg.say(db(), run, "kelly", topic("kelly", "kelly_cheer"), seeded(s), { "week": 1 })
		if r["misheard"]:
			misheard += 1
			if r["outcome"] != "good":
				worse += 1
	check(misheard > 20 and misheard < 100, "CHA 1 mishears a 20%% line often (%d/200)" % misheard)
	check(worse == misheard, "a misheard line never lands well")


func test_gifts() -> void:
	var run := fresh()
	Fx.add_item(run, "squad_ribbon", 1)
	Fx.add_item(run, "chain_food", 1)
	Fx.add_item(run, "good_tea", 1)
	var b0 := RM.bond(run, "kelly")
	check(BondRules.give_gift(db(), run, "kelly", "squad_ribbon")["reaction"] == "like" and RM.bond(run, "kelly") > b0 + 5, "liked gift")
	var g0 := RM.bond(run, "gary")
	check(BondRules.give_gift(db(), run, "gary", "chain_food")["reaction"] == "dislike" and RM.bond(run, "gary") < g0, "disliked gift")
	check(BondRules.give_gift(db(), run, "theo", "good_tea")["reaction"] == "neutral", "neutral gift")
	check(BondRules.give_gift(db(), run, "theo", "good_tea")["reaction"] == "none", "no item, no gift")


func test_recruitment_staggered() -> void:
	var run := fresh()
	check(BondRules.recruit_block(db(), run, "gary", 1) != "", "Gary is a mentor, not a recruit")
	check(BondRules.recruit_block(db(), run, "theo", 1).begins_with("Needs Bond"), "Friend tier needed")
	run["bonds"]["theo"] = 45.0
	check(BondRules.recruit_block(db(), run, "theo", 1) == "", "Core Four from week 1")
	run["bonds"]["sam"] = 50.0
	check(BondRules.recruit_block(db(), run, "sam", 1) != "" and BondRules.recruit_block(db(), run, "sam", 2) == "", "Sam from week 2")
	run["bonds"]["jake"] = 50.0
	check(BondRules.recruit_block(db(), run, "jake", 3) != "", "Jake after his forge questline")
	RM.set_flag(run, "jake_forge_done")
	check(BondRules.recruit_block(db(), run, "jake", 3) == "", "then Jake")
	run["bonds"]["phase"] = 50.0
	check(BondRules.recruit_block(db(), run, "phase", 3) != "", "Phase after deli shifts")
	run["shifts"]["deli_shifts"] = 3
	check(BondRules.recruit_block(db(), run, "phase", 3) == "", "then Phase")
	run["bonds"]["kelly"] = 50.0
	check(BondRules.recruit_block(db(), run, "kelly", 2) != "", "Kelly needs a high Bond and a kind first night")
	var theo := BondRules.recruit(db(), run, "theo", seeded(1))
	check(theo["class"] == "mage" and theo["knownVectors"] == ["force", "motion"], "Theo joins as a Force/Motion mage")
	check(run["party_ids"] == ["theo"], "and comes along tonight")
	check(BondRules.set_party(db(), run, ["theo", "sam", "dex", "mara"]) != "", "max party of 3")


## Plays the Monday evening with given choices and an auto fight with Kelly.
func monday(run: Dictionary, lunch: int, disruption: int, lantern: int, shortcut: int, panic: int, help: bool) -> String:
	var lunch_ev: Dictionary = StoryRules.find(db(), "w1_lunch")["steps"][0]["event"]
	var choice: Dictionary = StoryRules.resolve_choice(db(), run, lunch_ev["choices"][lunch], seeded(1))
	Fx.apply(db(), run, choice.get("effects", {}), seeded(1), {})
	var dis := DT.record(db(), "events/class_events", "story_w1_disruption")
	School.resolve_event(db(), run, dis, disruption, seeded(1), {})
	var steps: Array = StoryRules.find(db(), "w1_evening")["steps"]
	Fx.apply(db(), run, steps[2]["event"]["choices"][lantern]["effects"], seeded(1), {})
	var fight: Dictionary = steps[4]
	var summary := { "helpIgnored": 0 if help else 1, "support": { "kelly": 1 if help else 0 } }
	run["kelly_risk"] = int(run["kelly_risk"]) + StoryRules.combat_risk(fight, summary, "kelly")
	Fx.apply(db(), run, steps[5]["event"]["choices"][shortcut]["effects"], seeded(1), {})
	var p: Dictionary = steps[7]["event"]["choices"][panic]
	if Fx.conditions_met(db(), run, p.get("cond", {}), {}):
		Fx.apply(db(), run, p["effects"], seeded(1), {})
	return StoryRules.kelly_outcome(db(), run, "w1_evening")


## M6 "Done when": the Kelly Monday scenario is scripted and her Risk tracked.
func test_kelly_monday_both_outcomes() -> void:
	var cruel := fresh(2)
	check(monday(cruel, 0, 0, 1, 0, 2, false) == "death", "mock, laugh, keep the lantern, ignore her, shortcut: she panics (Risk %d)" % cruel["kelly_risk"])
	check(int(cruel["kelly_risk"]) == 2 + 1 + 1 + 2 + 1, "every Risk source counted (%d)" % cruel["kelly_risk"])
	var kind := fresh(3)
	kind["player"]["stats"]["cha"] = 6
	check(monday(kind, 2, 1, 0, 1, 0, true) == "survive", "kind night survives (Risk %d)" % kind["kelly_risk"])
	check(int(kind["kelly_risk"]) <= 0, "and Kelly Risk ends at or below 0")
	StoryRules.apply_survival(db(), kind)
	check(RM.flag(kind, "kelly_survived_kind") and RM.bond(kind, "kelly") > 0.0, "a kind night earns her loyalty")
	var middle := fresh(4)
	check(monday(middle, 3, 2, 1, 0, 2, true) == "survive", "a rough-but-not-cruel night survives (Risk %d)" % middle["kelly_risk"])


func test_kelly_guest_fight_tracks_help() -> void:
	var run := fresh(6)
	var kelly := StoryRules.make_guest(db(), run, "kelly", seeded(6))
	check(kelly["guest"] and RM.character(run, "kelly") == kelly, "Kelly is a guest character")
	var enemies := []
	for id in ["detention_slip", "detention_slip"]:
		enemies.append(DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true))
	var st := StateScript.new(db(), seeded(6), { "layout": DT.record(db(), "rooms/combat_layouts", "locker_hall"),
		"party": [{ "char": run["player"], "ai": true }, { "char": kelly, "ai": true, "guest": true }], "enemies": enemies })
	var g := 0
	while st.result == "" and g < 300:
		AI.take_turn(st, st.current)
		g += 1
	var s := st.finish()
	check(s["result"] != "", "the tutorial fight ends")
	check(s.has("helpIgnored") and s.has("support"), "help calls and support are tracked")
	StoryRules.clear_guests(run)
	check(RM.character(run, "kelly").is_empty(), "guests leave after the night")


func test_story_triggers() -> void:
	var run := fresh()
	check(StoryRules.due(db(), run, { "week": 1, "day": "mon", "part": "lunch" }, true) == ["w1_lunch"], "lunch scene is due Monday lunch")
	check(StoryRules.due(db(), run, { "week": 1, "day": "mon", "part": "evening" }, false) == ["w1_evening"], "the evening floor is due")
	RM.set_flag(run, "story_done_w1_evening")
	check(StoryRules.due(db(), run, { "week": 1, "day": "mon", "part": "evening" }, false).is_empty(), "once only")
	check(StoryRules.due(db(), run, { "week": 1, "day": "tue", "part": "lunch" }, true).is_empty(), "not on Tuesday")

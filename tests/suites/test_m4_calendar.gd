## M4: run model, school, effects, crafting, day flow, and a week of days.
extends "res://tests/suite.gd"

const RM := preload("res://src/core/run/run_model.gd")
const School := preload("res://src/core/run/school.gd")
const Fx := preload("res://src/core/run/effects.gd")
const DayFlow := preload("res://src/core/run/day_flow.gd")
const Crafting := preload("res://src/core/progression/crafting.gd")
const CalLogic := preload("res://src/core/calendar_logic.gd")
const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")


func fresh(seed_value: int = 1, class_id: String = "mage") -> Dictionary:
	return RM.new_run(db(), seed_value, class_id, seeded(seed_value))


func ctx_for(cal) -> Dictionary:
	return { "week": cal.week, "day": cal.day_name(), "part": cal.part_id(), "period": int(cal.current_part().get("period", 0)) }


func test_new_run() -> void:
	var run := fresh()
	check(run["player"]["class"] == "mage" and run["player"]["isPlayer"], "player built")
	check(run["schedule"].size() == 3, "default schedule")
	check(int(run["collection"].get("card_guard", 0)) == 1 and int(run["collection"].get("card_blink", 0)) == 1, "starter deck goes into the collection")
	check(run["money"] == int(db()["economy"]["startMoney"]), "start money from data")


func test_stat_bars() -> void:
	var ch := Char.create(db(), "mage", seeded(1), { "stats": { "str": 4, "dex": 5, "con": 5, "int": 7, "per": 5, "wil": 6, "cha": 4 } })
	var cfg: Dictionary = db()["stats"]["training"]
	check_near(RM.bars_for(cfg, 4), 3.0, "3 bars per point at low stats")
	check_near(RM.bars_for(cfg, 7), 4.0, "4 bars from 7")
	check_near(RM.bars_for(cfg, 19), 5.0, "capped at 5")
	var r := RM.train_stat(db(), ch, "str", 2.0)
	check(r["gained"] == 0 and ch["stats"]["str"] == 4, "2 bars is not a point yet")
	r = RM.train_stat(db(), ch, "str", 1.5)
	check(r["gained"] == 1 and ch["stats"]["str"] == 5, "third bar gives STR 5")
	check_near(float(ch["statXp"]["str"]), 0.5, "overflow carries")


func test_schedule_rules() -> void:
	var run := fresh()
	check(School.schedule_error(db(), run, ["pe", "drama"]) != "", "needs 3 classes")
	check(School.schedule_error(db(), run, ["pe", "drama", "nope"]) != "", "unknown class rejected")
	check(School.set_schedule(db(), run, ["pe", "pe", "history"], 1) == "", "repeats allowed")
	check(run["schedule_week"] == 1, "schedule week recorded")


func test_attend_and_half_gains() -> void:
	var run := fresh()
	School.set_schedule(db(), run, ["drama", "drama", "history"], 1)
	var cha0: float = float(run["player"].get("statXp", {}).get("cha", 0.0))
	var ctx := { "week": 2, "day": "tue", "part": "period_1", "period": 1 }
	var r1 := School.attend(db(), run, 1, seeded(3), ctx)
	var cha1: float = float(run["player"]["statXp"].get("cha", 0.0)) + 3.0 * float(run["player"]["stats"]["cha"] - 4)
	check(cha1 - cha0 >= 1.0, "first attendance: a full bar of CHA")
	ctx["period"] = 2
	var bars_before := float(run["player"]["statXp"].get("cha", 0.0))
	var r2 := School.attend(db(), run, 2, seeded(4), ctx)
	check(r2["lines"][0].find("half") >= 0, "repeat class says half gains")
	check(run["attendance"]["drama"] == 2, "attendance counted")
	check(float(run["grades"]["mr_mustard"]) >= 3.0 + 1.5 - 0.01, "grade 3 + 1.5")
	check(not r1["event"].is_empty(), "an event was drawn")
	check(bars_before >= 0.0, "bars tracked")


func test_forced_story_event() -> void:
	var run := fresh()
	var ev := School.pick_event(db(), run, "drama", seeded(1), { "week": 1, "day": "mon", "period": 2 })
	check(ev.get("id", "") == "story_w1_disruption", "week 1 Monday period 2 is the Kelly disruption")
	var ev2 := School.pick_event(db(), run, "drama", seeded(1), { "week": 1, "day": "mon", "period": 1 })
	check(ev2.get("id", "") != "story_w1_disruption", "not in period 1")
	var r := School.resolve_event(db(), run, ev, 0, seeded(1), {})
	check(int(run["kelly_risk"]) == 1, "laughing along adds Kelly Risk")
	check(RM.flag(run, "w1_laughed_at_kelly"), "flag set")
	check(r["lines"].size() > 0, "result lines")


func test_event_sampling_is_seeded() -> void:
	var a := fresh()
	var b := fresh()
	var ids_a: Array = []
	var ids_b: Array = []
	var ra := seeded(77)
	var rb := seeded(77)
	for i in 10:
		ids_a.append(School.pick_event(db(), a, "physics", ra, { "week": 2 }).get("id", ""))
		ids_b.append(School.pick_event(db(), b, "physics", rb, { "week": 2 }).get("id", ""))
	check(ids_a == ids_b, "same seed, same events")
	var spot := School.pick_event(db(), a, "physics", seeded(5), { "week": 2 })
	check(spot.get("type", "") != "spotlight", "spotlight needs Grade 25")


func test_quiz_check_and_repeat() -> void:
	var run := fresh()
	var quiz := DT.record(db(), "events/class_events", "physics_quiz")
	run["player"]["stats"]["int"] = 20
	var r := School.resolve_event(db(), run, quiz, -1, seeded(1), { "class": "physics", "professor": "ms_g" })
	check(r["success"], "INT 20 passes the quiz")
	check(float(run["grades"].get("ms_g", 0)) >= 3.0, "the quiz repeats the class gains (grade)")
	run["player"]["stats"]["dex"] = 1
	var acc := DT.record(db(), "events/class_events", "pe_rope_climb")
	var hp0 := 40
	run["player"]["hp"] = hp0
	var r2 := School.resolve_event(db(), run, acc, -1, seeded(1), {})
	check(not r2["success"] and int(run["player"]["hp"]) < hp0, "failed accident costs HP")


func test_skip_and_detention() -> void:
	var run := fresh()
	School.skip(db(), run, 1)
	School.skip(db(), run, 2)
	check(not run["detention_pending"], "two skips are fine")
	var lines := School.skip(db(), run, 3)
	check(run["detention_pending"] and lines.size() == 2, "third skip sets up detention")
	check(float(run["grades"].get("ms_g", 0.0)) == 0.0, "grade can't go below 0")
	School.new_week(run)
	check(run["skips_week"] == 0 and not RM.flag(run, "detention_this_week"), "weekly reset")


func test_effects_vocabulary() -> void:
	var run := fresh()
	var lines := Fx.apply(db(), run, { "stats": { "cha": 2 }, "money": 7, "flag": ["a", "b"], "kellyRisk": 2,
		"learnVector": "light", "item": { "spice": 2 }, "counter": { "deli_shifts": 1 }, "hp": -5, "bond": { "gary": 4 } }, seeded(1), {})
	check(run["player"]["stats"]["cha"] == 6, "stats")
	check(run["money"] == 27, "money")
	check(RM.flag(run, "a") and RM.flag(run, "b"), "flags")
	check(run["kelly_risk"] == 2, "kelly risk")
	check(run["player"]["knownVectors"].has("light"), "learn vector")
	check(run["inventory"]["spice"] == 2, "items")
	check(run["shifts"]["deli_shifts"] == 1, "counters")
	check(RM.bond(run, "gary") >= 4.0, "bond")
	check(lines.size() >= 5, "lines describe the changes")


func test_conditions() -> void:
	var run := fresh()
	var c := { "week": 1, "day": "mon" }
	check(Fx.conditions_met(db(), run, { "week": 1 }, c), "week matches")
	check(not Fx.conditions_met(db(), run, { "week": 2 }, c), "week mismatch")
	check(Fx.conditions_met(db(), run, { "day": ["mon", "tue"] }, c), "day in list")
	check(not Fx.conditions_met(db(), run, { "flag": "x" }, c), "missing flag")
	RM.set_flag(run, "x")
	check(Fx.conditions_met(db(), run, { "flag": "x", "notFlag": "y" }, c), "flag and notFlag")
	check(not Fx.conditions_met(db(), run, { "minStat": { "cha": 15 } }, c), "stat gate")
	check(Fx.conditions_met(db(), run, { "minStat": { "cha": 3 } }, c), "stat gate passes")


# --- Crafting --------------------------------------------------------------------------

func test_archetypes() -> void:
	check(Crafting.archetype(db(), { "heat": 10 }) == "thermal", "heat -> thermal")
	check(Crafting.archetype(db(), { "motion": 10 }) == "precision", "motion -> precision")
	check(Crafting.archetype(db(), { "light": 5, "binding": 5 }) == "alignment", "tie by axis order -> binding -> alignment")
	check(Crafting.archetype(db(), { "corrosion": 10 }) == "chemical", "tier 3 -> chemical")


func test_property_picks_and_perfect() -> void:
	check(Crafting.property_picks(db(), 0.1) == 0, "poor craft: no properties")
	check(Crafting.property_picks(db(), 0.5) == 1, "decent craft: 1")
	check(Crafting.property_picks(db(), 0.9) == 2, "great craft: 2")
	check(Crafting.is_perfect(db(), 0.96) and not Crafting.is_perfect(db(), 0.9), "perfect line")
	var w := Crafting.property_weights(db(), { "heat": 10 }, 0.5)
	check(w.has("searing_edge") and w.has("kindling") and not w.has("frostbite"), "gates filter properties")


func test_craft_and_copy() -> void:
	var run := fresh()
	var p: Dictionary = run["player"]
	p["knownVectors"] = ["heat", "cold"]
	var plain := Crafting.craft(db(), run, p, ["heat"], "bolt", "minor", 0.1, seeded(1))
	check(plain["id"] == "sp:heat:bolt:minor" and run["collection"][plain["id"]] == 1, "plain design goes to the collection by spell id")
	var fancy := Crafting.craft(db(), run, p, ["heat"], "bolt", "standard", 0.9, seeded(2))
	check(fancy["id"].begins_with("craft_") and fancy["properties"].size() == 2, "great craft rolls 2 properties into a stored card")
	check(run["cards"].has(fancy["id"]), "stored in the library")
	var perfect := Crafting.craft(db(), run, p, ["cold"], "bolt", "standard", 1.0, seeded(3))
	check(perfect["magnitude"] == "standard" and not perfect["stepped"], "perfect step capped at Tier 1")
	p["knowledgeTier"] = 2
	var perfect2 := Crafting.craft(db(), run, p, ["cold"], "bolt", "standard", 1.0, seeded(3))
	check(perfect2["magnitude"] == "major" and perfect2["stepped"], "perfect step at Tier 2")
	check(Crafting.copy(run, fancy["id"]) and run["collection"][fancy["id"]] == 2, "copies keep the design")
	check(not Crafting.copy(run, "nope"), "can't copy what you don't own")
	check(Crafting.craft(db(), run, p, ["force"], "bolt", "minor", 0.5, seeded(1)).has("error"), "unknown vector errors")


func test_property_effects_on_cards() -> void:
	var card := CardRules.make_spell(db(), { "heat": 1 }, "bolt", "standard", ["searing_edge"])
	check_near(CardRules.power(db(), card), 11.5, "Searing Edge +15% power")
	var quick := CardRules.make_spell(db(), { "motion": 1 }, "bolt", "minor", ["quickcast"])
	check(CardRules.spell_cost(db(), quick) == 0, "Quickcast -1 cost, min 0")


func test_deck_rules() -> void:
	var run := fresh()
	var p: Dictionary = run["player"]
	var deck: Array = p["deck"].duplicate()
	check(Crafting.deck_error(db(), run, p, deck) == "", "starter deck is legal")
	var small := deck.slice(0, 9)
	check(Crafting.deck_error(db(), run, p, small) != "", "too small")
	var four := deck.duplicate()
	four.append("card_guard")
	four.append("card_guard")
	check(Crafting.deck_error(db(), run, p, four) != "", "more copies than owned / allowed")
	var bad := deck.duplicate()
	bad[0] = "sp:binding:bolt:minor"
	check(Crafting.deck_error(db(), run, p, bad) != "", "unknown Vector or unowned card rejected")


# --- Day flow -----------------------------------------------------------------------------

func test_part_kinds_and_screens() -> void:
	var cal = CalLogic.new(db()["calendar"])
	check(DayFlow.part_kind(cal.current_part()) == "free", "before school is free")
	var run := fresh()
	check(DayFlow.on_enter(run, 1, "mon", cal.current_part(), false) == ["schedule"], "first morning asks for a schedule")
	run["schedule_week"] = 1
	check(DayFlow.on_enter(run, 1, "mon", cal.current_part(), false).is_empty(), "then nothing")
	cal.advance_part()
	check(DayFlow.on_enter(run, 1, "mon", cal.current_part(), false) == ["class"], "period 1 is a class")
	for i in 4:
		cal.advance_part()
	run["detention_pending"] = true
	check(DayFlow.on_enter(run, 1, "mon", cal.current_part(), false) == ["detention"], "after school detention")
	cal.advance_part()
	check(DayFlow.on_enter(run, 1, "mon", cal.current_part(), false) == ["dungeon"], "evening dungeon")
	cal.advance_part()
	check(DayFlow.on_enter(run, 1, "mon", cal.current_part(), false) == ["night"], "night")


func test_sleep_and_injury() -> void:
	var run := fresh()
	run["player"]["hp"] = 3
	var ally := Char.create(db(), "fighter", seeded(2), { "id": "ally" })
	ally["injured"] = 2
	run["roster"].append(ally)
	run["party_ids"] = ["ally"]
	check(DayFlow.available_party(run).is_empty(), "injured members sit out")
	DayFlow.end_day(db(), run)
	check(run["player"]["hp"] == Char.derived(db(), run["player"])["maxHp"], "sleep restores HP")
	check(ally["injured"] == 1, "injury counts down")
	DayFlow.end_day(db(), run)
	check(DayFlow.available_party(run) == ["ally"], "back after two nights")


func test_weekly_bond_decay() -> void:
	var run := fresh()
	run["bonds"]["a"] = 50.0
	run["bonds"]["b"] = 90.0
	DayFlow.new_week(db(), run)
	check_near(float(run["bonds"]["a"]), 47.5, "5% decay toward 0")
	check_near(float(run["bonds"]["b"]), 90.0, "Unbreakable does not decay")


## M4 "Done when": play a week of days with no dungeon and see stats change.
func test_play_a_week_without_dungeon() -> void:
	var run := fresh(31337)
	var cal = CalLogic.new(db()["calendar"])
	var rng := seeded(31337)
	var stats0: Dictionary = run["player"]["stats"].duplicate()
	var aff0: Dictionary = run["player"]["vectorAffinity"].duplicate()
	School.set_schedule(db(), run, ["physics", "drama", "earth_science"], 1)
	var days := 0
	var attended := 0
	while cal.week == 1:
		var c := ctx_for(cal)
		match DayFlow.part_kind(cal.current_part()):
			"class":
				var r := School.attend(db(), run, int(c["period"]), rng, c)
				attended += 1
				if not r["event"].is_empty():
					School.resolve_event(db(), run, r["event"], 0, rng, r["ctx"])
			"free":
				if cal.ap >= 2:
					Fx.apply(db(), run, { "statXp": { "str": 1.0 } }, rng, c)
					cal.spend_ap(2)
		var day_before: int = cal.day_index
		cal.advance_part()
		if cal.day_index != day_before:
			DayFlow.end_day(db(), run)
			days += 1
	check(days == 7 and attended == 15, "7 days, 15 classes attended (got %d, %d)" % [days, attended])
	var changed := 0
	for s in stats0:
		if int(run["player"]["stats"][s]) != int(stats0[s]):
			changed += 1
	check(changed >= 3, "at least 3 stats rose over the week (%d)" % changed)
	check(float(run["player"]["vectorAffinity"]["force"]) > float(aff0["force"]), "physics nudged Force affinity")
	check(float(run["grades"].get("ms_g", 0)) >= 15.0, "Grade with Ms. G built up")

## M8: advanced classes and class change, signature perks, weeks 2-5 content.
extends "res://tests/suite.gd"

const RM := preload("res://src/core/run/run_model.gd")
const Char := preload("res://src/core/character.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const CC := preload("res://src/core/progression/class_change.gd")
const CardRules := preload("res://src/core/card.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const Sig := preload("res://src/core/dungeon/signature.gd")
const StoryRules := preload("res://src/core/story/story.gd")
const Bonds := preload("res://src/core/social/bonds.gd")


func fresh(class_id: String = "mage", seed_value: int = 1) -> Dictionary:
	return RM.new_run(db(), seed_value, class_id, seeded(seed_value))


func level_to(ch: Dictionary, lvl: int) -> void:
	var rng := seeded(3)
	while int(ch["level"]) < lvl:
		Lv.add_xp(db(), ch, Lv.xp_to_next(db(), int(ch["level"])), rng)


func test_advanced_class_data() -> void:
	var adv := 0
	var hidden := 0
	for c in db()["classes"]["classes"]:
		if int(c.get("tier", 1)) >= 2:
			adv += 1
			if bool(c.get("hidden", false)):
				hidden += 1
			check(c.has("requires") and c.has("growth") and c.has("perk"), "%s is complete" % c["id"])
	check(adv == 10 and hidden == 3, "10 advanced classes, 3 hidden (%d, %d)" % [adv, hidden])


func test_class_change_at_5() -> void:
	var run := fresh("mage")
	var p: Dictionary = run["player"]
	p["knownVectors"] = ["heat", "cold"]
	p["stats"]["int"] = 9
	level_to(p, 5)
	check(p.has("pendingClassChange"), "level 5 opens a Class Change")
	var o := CC.options(db(), run, p)
	check(o["available"].has("elementalist"), "INT 9 mage who knows Heat and Cold can be an Elementalist")
	var locked_ids: Array = o["locked"].map(func(l: Variant) -> String: return str(l["id"]))
	check(locked_ids.has("kinetic_logician") and not o["available"].has("kinetic_logician"), "Kinetic Logician needs Force/Motion and Physics x8")
	check(not locked_ids.has("deli_knight") and not o["available"].has("deli_knight"), "hidden classes don't show while locked")
	check(not o["available"].has("upside_touched"), "Tier 3 waits for level 12")
	Lv.auto_perks(db(), p)
	var keep := str(p["perks"][0])
	CC.apply(db(), run, p, "elementalist", keep)
	check(p["class"] == "elementalist" and p["perks"] == [keep] and not p.has("pendingClassChange"), "class changed, one perk kept")
	check(p["knownForms"].has("burst"), "Elementalist grants Burst")
	check(float(Char.collect_mods(db(), p).get("combat", {}).get("spellDamagePct", 0.0)) >= 0.1, "class mods apply")
	check(Lv.perk_options(db(), p, 6).size() == 2, "perks at 6 still come from the old class tree")


func test_hidden_and_tier3_gates() -> void:
	var run := fresh("fighter")
	var p: Dictionary = run["player"]
	level_to(p, 5)
	var dk := DT.record(db(), "classes", "deli_knight")
	check(CC.requirement_error(db(), run, p, dk) != "", "Deli Knight is locked")
	run["shifts"]["deli_shifts"] = 10
	run["bonds"]["gary"] = 45.0
	check(CC.requirement_error(db(), run, p, dk) == "", "10 shifts and Gary's friendship open Deli Knight")
	var ut := DT.record(db(), "classes", "upside_touched")
	level_to(p, 12)
	p["stats"]["wil"] = 12
	check(CC.requirement_error(db(), run, p, ut) != "", "Upside-Touched needs Wild Surges")
	p["wildSurges"] = 5
	check(CC.requirement_error(db(), run, p, ut) == "" and CC.options(db(), run, p)["available"].has("upside_touched"), "5 Wild Surges and WIL 12 at level 12")


func test_recruits_auto_advance() -> void:
	var run := fresh("mage")
	run["bonds"]["theo"] = 50.0
	var theo := Bonds.recruit(db(), run, "theo", seeded(1))
	level_to(theo, 5)
	check(theo.has("pendingClassChange"), "Theo reaches the marker")
	check(CC.auto_advance(db(), run, theo) == "elementalist" and theo["class"] == "elementalist", "Theo grows into an Elementalist")


func unit_state(party: Array, enemies: Array) -> StateScript:
	var p: Array = []
	for ch in party:
		p.append({ "char": ch })
	var recs: Array = []
	for id in enemies:
		recs.append(DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true))
	return StateScript.new(db(), seeded(1), { "layout": { "map": ["P....E", "P....E", "P....E"] }, "party": p, "enemies": recs })


func test_signature_perks_in_combat() -> void:
	var run := fresh("mage")
	var p: Dictionary = run["player"]
	p["class"] = "elementalist"
	var st := unit_state([p], ["pom_pom_wisp"])
	var u = st.unit_by_id("player")
	var hybrid := CardRules.make_spell(db(), { "heat": 1, "cold": 1 }, "bolt", "standard")
	check(st.card_cost(u, hybrid) == 2, "Prism: hybrids skip the hybrid cost")
	var g: Dictionary = fresh("fighter")["player"]
	g["class"] = "guardian"
	g["id"] = "player"
	var ally := Char.create(db(), "mage", seeded(2), { "id": "ally" })
	var st2 := unit_state([g, ally], ["pom_pom_wisp"])
	var gu = st2.unit_by_id("player")
	var au = st2.unit_by_id("ally")
	au.cell = gu.cell + Vector2i(0, 1)
	st2.current = gu
	gu.action_used = false
	st2.guard(gu)
	check(au.shield >= 5, "Bulwark: Guard shields adjacent allies")
	var sb: Dictionary = fresh("fighter")["player"]
	sb["class"] = "spellblade"
	var st3 := unit_state([sb], ["pom_pom_wisp"])
	var su = st3.unit_by_id("player")
	st3._resolve_spec(su, st3._spell_spec(su, CardRules.make_spell(db(), { "heat": 1 }, "weapon_infusion", "standard")), su.cell)
	check(int(su.infusion["strikes"]) == 3, "Spellsteel: infusion lasts 3 strikes")


func test_weeks_content() -> void:
	for w in range(1, 6):
		var wr := Sig.week_rec(db(), w)
		check(not wr.is_empty() and not wr.get("baseSignature", {}).is_empty(), "week %d has a signature" % w)
		var boss: Dictionary = DT.index_under(db(), "enemies/", "enemies").get(str(wr.get("boss", "")), {})
		check(not boss.is_empty() and boss.get("phases", []).size() >= 3, "week %d boss %s has phases" % [w, wr.get("boss")])
		check(not DT.record(db(), "rooms/combat_layouts", str(wr.get("bossLayout", ""))).is_empty(), "week %d boss layout exists" % w)
		var run := fresh()
		check(Sig.enemy_weights(db(), run, w, "normal").size() >= 3, "week %d has at least 3 normal enemy types" % w)
		check(Sig.enemy_weights(db(), run, w, "elite").size() >= 1, "week %d has an elite" % w)
		var f := Gen.generate(db(), run, w, "fri")
		var has_boss := false
		for r in f["rooms"]:
			has_boss = has_boss or (r["type"] == "boss" and r["enemies"] == [wr["boss"]])
		check(has_boss, "week %d Friday has its boss" % w)
	var normals := 0
	var elites := 0
	for e in DT.records_under(db(), "enemies/", "enemies"):
		if e.get("tier", "normal") == "normal":
			normals += 1
		elif e.get("tier", "") == "elite":
			elites += 1
	check(normals >= 15 and elites == 5, "at least 15 normal and 5 elite enemy types (%d, %d)" % [normals, elites])


func test_main_story_beats() -> void:
	var run := fresh()
	check(StoryRules.due(db(), run, { "week": 2, "day": "mon", "part": "lunch" }, true).has("s2_not_alone"), "week 2: others are pulled in")
	check(StoryRules.due(db(), run, { "week": 3, "day": "wed", "part": "after_school" }, true).has("s3_coverup"), "week 3: Mr. B's cover-up")
	check(StoryRules.due(db(), run, { "week": 5, "day": "wed", "part": "after_school" }, true).has("s5_reveal_mr_b"), "week 5: Mr. B is revealed")
	var end: Dictionary = db()["endings"]["alpha"]
	check(str(end["reveal"]).begins_with("NARRATOR_REVEAL_TBD"), "the reveal is a marked placeholder")
	check(ResourceLoader.exists("res://src/scenes/story/narrator_reveal_tbd.tscn"), "the NARRATOR_REVEAL_TBD scene exists")

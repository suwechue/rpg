## M2: characters, cards, decks, leveling.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const DeckClass := preload("res://src/core/deck.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const VO := preload("res://src/core/vector_ops.gd")


func test_create_every_class() -> void:
	for cls in db()["classes"]["classes"]:
		if int(cls.get("tier", 1)) != 1:
			continue
		var ch := Char.create(db(), str(cls["id"]), seeded(5))
		check(ch["class"] == cls["id"], "class set for %s" % cls["id"])
		check(ch["knownVectors"].size() == int(cls.get("startVectors", 1)), "%s knows its starting Vectors" % cls["id"])
		check(ch["deck"].size() >= int(db()["leveling"]["deckMin"]), "%s starter deck meets the minimum" % cls["id"])
		for id in ch["deck"]:
			check(not CardRules.resolve(db(), str(id)).is_empty(), "%s deck card %s resolves" % [cls["id"], id])
		var d := Char.derived(db(), ch)
		check(ch["hp"] == d["maxHp"] and ch["mp"] == d["maxMp"], "%s starts at full HP and MP" % cls["id"])


func test_healer_forced_light() -> void:
	var ch := Char.create(db(), "healer", seeded(1))
	check(ch["knownVectors"] == ["light"], "healer knows exactly Light")


func test_derived_formulas() -> void:
	var ch := Char.create(db(), "mage", seeded(1), { "stats": { "str": 4, "dex": 5, "con": 5, "int": 7, "per": 5, "wil": 6, "cha": 4 } })
	var d := Char.derived(db(), ch)
	check(d["maxHp"] == 20 + 5 * 4 + 0, "max HP = 20 + CON x 4 + class bonus")
	check(d["maxMp"] == int(4 + 7 * 0.5 + 6 * 0.34) + 2, "max MP = 4 + INT / 2 + WIL / 3 + class bonus (CU: a small pool)")
	check(d["movement"] == 3 + 1, "movement = 3 + floor(DEX / 5)")
	check(d["initiative"] == 5 + 2, "initiative = DEX + PER / 2")
	check(d["stability"] == 6 + 3, "stability = WIL + INT / 2")
	check_near(d["critChancePct"], 7.5, "crit = 5 + DEX / 2")
	check(d["mpRegen"] == 1, "MP regen is 1 per turn")


func test_trait_and_perk_mods() -> void:
	var ch := Char.create(db(), "mage", seeded(1), { "traits": ["bookworm", "night_owl"] })
	var base := Char.create(db(), "mage", seeded(1))
	check(Char.effective_stats(db(), ch)["int"] == Char.effective_stats(db(), base)["int"] + 1, "Bookworm adds INT")
	check(Char.derived(db(), ch)["maxMp"] >= Char.derived(db(), base)["maxMp"] + 1, "Night Owl +1 MP and +1 INT stack")
	ch["perks"] = ["arcane_reserve"]
	check(Char.derived(db(), ch)["maxMp"] >= Char.derived(db(), base)["maxMp"] + 3, "perk adds MP")
	var mods := Char.merge_mods([{ "social": { "misinterpretMul": 0.5 } }, { "social": { "misinterpretMul": 0.5 } }])
	check_near(mods["social"]["misinterpretMul"], 0.25, "Mul keys multiply")


func test_card_costs() -> void:
	var bolt := CardRules.make_spell(db(), { "heat": 1 }, "bolt", "standard")
	check(bolt["cost"] == 2, "Standard Bolt costs 2")
	var burst := CardRules.make_spell(db(), { "heat": 1, "cold": 1 }, "burst", "major")
	check(burst["cost"] == 4 + 2 + 2 + 1, "Major Heat/Cold Burst: 4 + Burst 2 + Major surcharge 2 + antagonism 1 = 9 (PT Part 8)")
	check_near(burst["vectors"]["heat"], 0.5, "hybrid is an equal Blend")
	check(CardRules.improvise_cost(db(), bolt) == 4, "improvise ceil(2 x 1.5) + 1 = 4")
	var glyph := CardRules.make_spell(db(), { "cold": 1 }, "glyph", "grand")
	check(CardRules.improvise_cost(db(), glyph) == 16, "improvise ceil(10 x 1.5) + 1 = 16")
	check(bolt["id"] == "sp:heat:bolt:standard", "spell id format")
	var again := CardRules.resolve(db(), "sp:cold+heat:burst:major")
	check(again["id"] == "sp:heat+cold:burst:major", "resolve normalizes axis order")
	check(again["name"] == "Ember-Frost Burst", "hybrid name")
	check(CardRules.resolve(db(), "card_frost_line")["cost"] == 3, "data card resolves")


func test_knowledge_tier_caps() -> void:
	check(CardRules.max_magnitude(db(), 1) == "standard", "Tier 1 caps at Standard")
	check(CardRules.max_magnitude(db(), 2) == "major", "Tier 2 caps at Major")
	check(CardRules.max_magnitude(db(), 3) == "grand", "Tier 3 caps at Grand")
	var ch := Char.create(db(), "mage", seeded(1), { "knownVectors": ["heat", "cold"] })
	check(CardRules.design_error(db(), ch, ["heat"], "bolt", "standard") == "", "legal design")
	check(CardRules.design_error(db(), ch, ["heat"], "bolt", "major") != "", "Major blocked at Tier 1")
	check(CardRules.design_error(db(), ch, ["force"], "bolt", "minor") != "", "unknown Vector blocked")
	check(CardRules.design_error(db(), ch, ["heat"], "glyph", "minor") != "", "unknown Form blocked")
	check(CardRules.design_error(db(), ch, ["heat", "cold"], "bolt", "minor") == "", "hybrid allowed")
	check(CardRules.step_up(db(), "standard", 1) == "standard", "step up capped by tier")
	check(CardRules.step_up(db(), "standard", 2) == "major", "step up at tier 2")


func test_deck_draw_and_fatigue() -> void:
	var rng := seeded(3)
	var ids: Array = []
	for i in 10:
		ids.append("c%d" % i)
	var deck = DeckClass.new(ids, rng, db()["stats"]["combat"])
	var r: Dictionary = deck.draw(3, rng)
	check(deck.hand.size() == 3 and r["fatigue"] == 0, "opening hand 3, no fatigue")
	deck.draw(5, rng)
	check(deck.hand.size() == 3, "hand limit 3 (CT Part 4)")
	check(deck.draw_pile.size() == 7, "cards beyond the limit stay in the pile")
	for i in 3:
		deck.play(0)
	deck.draw(3, rng)
	for i in 3:
		deck.play(0)
	deck.draw(3, rng)
	for i in 3:
		deck.play(0)
	deck.draw(1, rng)
	check(deck.draw_pile.is_empty(), "pile emptied")
	deck.play(0)
	r = deck.draw(2, rng)
	check(r["fatigue"] == 1, "first reshuffle costs 1 fatigue")
	check(deck.total_cards() == 10, "no cards lost")
	while not deck.hand.is_empty():
		deck.play(0)
	while not deck.draw_pile.is_empty():
		deck.draw(1, rng)
		deck.play(0)
	r = deck.draw(1, rng)
	check(r["fatigue"] == 2, "second reshuffle costs 2")
	deck.play(0, true)
	check(deck.exhausted.size() == 1 and deck.total_cards() == 9, "consumables leave the fight")


func test_deck_shuffle_is_seeded() -> void:
	var ids := ["a", "b", "c", "d", "e", "f", "g", "h"]
	var d1 = DeckClass.new(ids, seeded(77))
	var d2 = DeckClass.new(ids, seeded(77))
	check(d1.draw_pile == d2.draw_pile, "same seed, same order")


func test_xp_curve() -> void:
	var per := int(db()["leveling"]["xpPerLevel"])
	check(Lv.xp_to_next(db(), 1) == per and Lv.xp_to_next(db(), 4) == per * 4, "level n needs xpPerLevel x n")
	var ch := Char.create(db(), "fighter", seeded(2))
	var reports := Lv.add_xp(db(), ch, per + per * 2 + 5, seeded(2))
	check(reports.size() == 2 and ch["level"] == 3 and ch["xp"] == 5, "XP carries over across levels")
	var gained := 0
	for r in reports:
		for s in r["stats"]:
			gained += int(r["stats"][s])
	check(gained == 6, "3 stat points per level")
	# PT Part 8: Technique picks at levels 2 and 3 replace the old perk levels.
	check(bool(reports[0].get("techniquePick", false)) and bool(reports[1].get("techniquePick", false)) and ch["pendingTechniques"].size() == 2, "Technique picks at levels 2 and 3")
	var start := (ch["techniques"] as Array).size()
	var opts := Lv.technique_options(db(), ch)
	check(not opts.is_empty() and Lv.choose_technique(db(), ch, str(opts[0])), "a Technique chosen")
	check(ch["pendingTechniques"].size() == 1 and (ch["techniques"] as Array).size() == start + 1, "Technique recorded")


func test_learning_pity() -> void:
	var ch := Char.create(db(), "mage", seeded(1), { "knownVectors": ["heat"] })
	ch["dryVectorRolls"] = 3
	var r := Lv.learning_roll(db(), ch, "vectorAffinity", "knownVectors", "dryVectorRolls", seeded(9))
	check(r["kind"] == "new" and r["pity"], "pity forces something new")
	check(ch["dryVectorRolls"] == 0, "dry counter resets")
	ch["knownVectors"] = ["heat", "cold", "force", "motion", "binding", "light"]
	ch["dryVectorRolls"] = 5
	r = Lv.learning_roll(db(), ch, "vectorAffinity", "knownVectors", "dryVectorRolls", seeded(9))
	check(r["kind"] == "raise", "Tier 1 cap: all six base Vectors known, so a known one rises")
	check(not ch["knownVectors"].has("gravity") and not ch["knownVectors"].has("transmutation"), "Tier 2+ Vectors are not learnable at Tier 1")


## M2 "Done when": a seeded mage levels to 5 identically every time.
func test_seeded_mage_levels_to_5_identically() -> void:
	var results: Array = []
	for attempt in 3:
		var rng := seeded(424242)
		var ch := Char.create(db(), "mage", rng)
		var lvl_rng := seeded(424242 + 1)
		while ch["level"] < 5:
			Lv.add_xp(db(), ch, Lv.xp_to_next(db(), int(ch["level"])), lvl_rng)
			Lv.auto_perks(db(), ch)
		results.append(JSON.stringify(ch, "", true))
		check(ch["level"] == 5, "reached level 5")
	check(results[0] == results[1] and results[1] == results[2], "identical mage every time")
	var other := Char.create(db(), "mage", seeded(1))
	var other_rng := seeded(2)
	while other["level"] < 5:
		Lv.add_xp(db(), other, Lv.xp_to_next(db(), int(other["level"])), other_rng)
		Lv.auto_perks(db(), other)
	check(JSON.stringify(other, "", true) != results[0], "a different seed gives a different mage")

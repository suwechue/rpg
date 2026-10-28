## PT Part 5: the Card Forge (fuse, salvage, upgrade, riders with escalating
## cost) and riders in combat.
extends "res://tests/suite.gd"

const Forge := preload("res://src/core/progression/forge.gd")
const CardRules := preload("res://src/core/card.gd")
const Char := preload("res://src/core/character.gd")
const RM := preload("res://src/core/run/run_model.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")


func fresh() -> Dictionary:
	var run := RM.new_run(db(), 3, "fighter", seeded(3))
	run["collection"] = {}
	run["cards"] = {}
	return run


func test_fuse_element_and_technique() -> void:
	var run := fresh()
	var frost := CardRules.spell_id(db(), { "cold": 1.0 }, "bolt", "standard")
	run["collection"][frost] = 1
	run["collection"]["card_lunge"] = 1
	check(Forge.fuse_block(db(), run, frost, "card_lunge") == "", "an element and a technique fuse")
	var made := Forge.fuse(db(), run, frost, "card_lunge")
	check(made.get("infuse", {}).has("cold") and str(made["name"]).contains("Lunge"), "the technique carries the Vector: %s" % made.get("name", ""))
	check(not run["collection"].has(frost) and not run["collection"].has("card_lunge"), "both sources are used up")
	check(int(run["collection"].get(str(made["id"]), 0)) == 1, "the fused card joins the collection")
	check(CardRules.cost(db(), made) == maxi(CardRules.cost(db(), CardRules.resolve(db(), frost)), 1) + int(db()["forge"]["fusionSurcharge"]), "cost: the higher of the two plus the surcharge")


func test_fuse_two_spells_and_refusals() -> void:
	var run := fresh()
	var heat := CardRules.spell_id(db(), { "heat": 1.0 }, "bolt", "standard")
	var cold := CardRules.spell_id(db(), { "cold": 1.0 }, "bolt", "minor")
	run["collection"][heat] = 2
	run["collection"][cold] = 1
	var made := Forge.fuse(db(), run, heat, cold)
	check(made.get("vectors", {}).size() == 2 and str(made["name"]) == "Thermal Shock", "two spells make a named hybrid: %s" % made.get("name", ""))
	check(Forge.fuse_block(db(), run, heat, heat) != "", "the same Vector twice doesn't fuse")
	run["collection"]["card_dash"] = 1
	run["collection"]["card_mend"] = 1
	check(Forge.fuse_block(db(), run, "card_dash", "card_dash") != "", "you need two copies to fuse a card with itself")


func test_salvage_and_upgrade() -> void:
	var run := fresh()
	var heat := CardRules.spell_id(db(), { "heat": 1.0 }, "bolt", "minor")
	run["collection"][heat] = 2
	var gain := Forge.salvage(db(), run, heat)
	check(int(gain.get("heat", 0)) > 0 and int(gain.get("generic", 0)) > 0, "salvage gives Vector and generic Scraps (%s)" % str(gain))
	check(int(run["collection"][heat]) == 1, "one copy is destroyed")
	Forge.add_scraps(run, { "generic": 10, "heat": 5 })
	var up := Forge.upgrade(db(), run, heat)
	check(not up.has("error") and str(up.get("magnitude", "")) == "standard", "a spell design upgrades one Magnitude step")


func test_riders() -> void:
	var run := fresh()
	run["collection"]["card_lunge"] = 1
	Forge.add_scraps(run, { "generic": 20 })
	var c := Forge.card(db(), run, "card_lunge")
	var first := int(Forge.rider_cost(db(), c, "slow")["generic"])
	var with1 := Forge.add_rider(db(), run, "card_lunge", "slow")
	check(with1.get("riders", []) == ["slow"] and CardRules.cost(db(), with1) == CardRules.cost(db(), c) + 1, "a rider raises the MP cost")
	var second := int(Forge.rider_cost(db(), with1, "weaken")["generic"])
	check(second == int(Forge.riders(db())["weaken"]["scraps"]) + 1 and first == int(Forge.riders(db())["slow"]["scraps"]), "the 2nd rider costs +1")
	check(Forge.rider_block(db(), run, str(with1["id"]), "weaken") != "", "common cards have 1 rider slot")
	var burst := CardRules.spell_id(db(), { "heat": 1.0 }, "burst", "minor")
	run["collection"][burst] = 1
	check(Forge.rider_block(db(), run, burst, "twin") != "", "Twin only goes on single-target cards")


func test_riders_in_combat() -> void:
	var ch := Char.create(db(), "fighter", seeded(1), { "isPlayer": true })
	var st := StateScript.new(db(), seeded(5), { "layout": { "map": ["PE......."] }, "party": [{ "char": ch }],
		"enemies": [DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)] })
	var p = st.units[0]
	var e = st.units[1]
	e.hp = 999
	var card := CardRules.resolve(db(), "card_heavy_swing").duplicate(true)
	card["riders"] = ["slow", "weaken", "daze"]
	st._apply_riders(p, card, e.cell, [e.cell])
	check(e.statuses.has("slowed2") and e.statuses.has("weakened") and e.statuses.has("dazed"), "riders land on the target")
	e.movement = 4
	check(st.move_budget(e) == 2, "Slow: -2 Movement")
	var spec := st.action_spec(e, e.actions[0])
	var weak := st._expected_hit(e, p, spec)
	e.statuses.erase("weakened")
	check_near(weak, st._expected_hit(e, p, spec) * 0.75, "Weaken: -25% damage")
	var plus := DT.record(db(), "forms", "burst")
	var wide := st._widen({ "riders": ["widen"] }, { "footprint": "plus", "range": 4 })
	check(str(wide["footprint"]) == "square_3x3" and plus.size() > 0, "Widen: plus becomes 3x3")

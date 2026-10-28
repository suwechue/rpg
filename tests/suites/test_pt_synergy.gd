## PT Part 7: statuses as setups and payoffs, the Cone Form, card tags, class
## card pools and enemy variety.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const Forms := preload("res://src/core/combat/forms.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")


func enemy(id: String) -> Dictionary:
	return DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)


func setup() -> StateScript:
	var ch := Char.create(db(), "mage", seeded(1), { "isPlayer": true, "knownVectors": ["heat", "cold"] })
	return StateScript.new(db(), seeded(5), { "layout": { "map": ["P...E....", "........."] }, "party": [{ "char": ch }], "enemies": [enemy("pom_pom_wisp")] })


func spec(st: StateScript, axis: String) -> Dictionary:
	return st._spell_spec(st.units[0], CardRules.make_spell(db(), { axis: 1.0 }, "bolt", "standard"))


func test_wet_freeze_shatter() -> void:
	var st := setup()
	var p = st.units[0]
	var e = st.units[1]
	e.hp = 999
	st.add_status(e, "wet")
	st._status_setups(p, spec(st, "cold"), [e])
	check(e.statuses.has("frozen") and e.statuses.has("root") and not e.statuses.has("wet"), "Cold on a Wet unit Freezes it (root + frozen)")
	var frozen_hit := st._expected_hit(p, e, spec(st, "force"))
	st._status_setups(p, spec(st, "force"), [e])
	check(not e.statuses.has("frozen"), "Force shatters the ice")
	check_near(frozen_hit, st._expected_hit(p, e, spec(st, "force")) * 1.5, "shattering hits x1.5")


func test_burning_and_spread() -> void:
	var st := setup()
	var p = st.units[0]
	var e = st.units[1]
	e.hp = 999
	st._status_setups(p, spec(st, "heat"), [e])
	check(e.statuses.has("burning"), "Heat sets Burning")
	st._status_setups(p, spec(st, "force"), [e])
	check(st.grid.burning.has(e.cell + Vector2i(1, 0)), "Force spreads Burning to the tiles around it")
	var hp: int = e.hp
	st.current = e
	st._start_turn(e)
	check(e.hp < hp, "Burning hurts at the start of its turn")


func test_marked_exposed_poison() -> void:
	var st := setup()
	var p = st.units[0]
	var e = st.units[1]
	var base := st._expected_hit(p, e, spec(st, "heat"))
	st.add_status(e, "marked")
	check_near(st._expected_hit(p, e, spec(st, "heat")), base * 1.25, "Marked takes +25%")
	e.statuses.erase("marked")
	st.add_status(e, "poisoned")
	st.add_status(e, "poisoned")
	check(int(e.links["poison"]) == 2, "Poison stacks")
	st._status_setups(p, spec(st, "corrosion"), [e])
	check(int(e.links["poison"]) == 4 and e.statuses.has("exposed"), "Corrosion doubles the stacks and Exposes")
	e.hp = 5
	st._heal(e, e, 10)
	check(e.hp == 10, "healing on the Poisoned is halved")


func test_shadowed_cone_tags() -> void:
	var st := setup()
	var p = st.units[0]
	var e = st.units[1]
	st.add_status(e, "shadowed")
	check(not st._spell_targets(p, st.form_rec("bolt"), false).has(e.cell), "Shadowed units can't be targeted from more than 2 tiles")
	var grid := GridScript.new({ "map": [".......", ".......", ".......", ".......", "......."] })
	var cone := Forms.footprint(grid, { "footprint": "cone" }, Vector2i(0, 2), Vector2i(3, 2), {})
	check(cone.size() == 9, "a Cone is 1-3-5 tiles (%d)" % cone.size())
	var tags := CardRules.tags(db(), CardRules.resolve(db(), "card_flash_frost"))
	check(tags["setsUp"].has("frozen") and tags["paysOff"].has("wet"), "cards list what they set up and pay off (%s)" % str(tags))


func test_card_pools_and_enemies() -> void:
	for cls in ["fighter", "rogue", "healer", "mage", "bard"]:
		var n: int = db()["cards/class_" + cls]["cards"].size()
		check(n >= 10 and n <= 15, "%s has a 10 to 15 card pool (%d)" % [cls, n])
		for c in db()["cards/class_" + cls]["cards"]:
			check(c.has("tags") and str(c.get("text", "")) != "", "%s lists tags and text" % c["id"])
	var added := 0
	for key in ["cards/class_fighter", "cards/class_rogue", "cards/class_healer", "cards/class_mage", "cards/class_bard", "cards/synergy_cards"]:
		added += db()[key]["cards"].size()
	check(added >= 60, "60+ new cards in this part (%d; PT Part 8 adds the new Vectors' cards)" % added)
	for e in DT.records_under(db(), "enemies/", "enemies"):
		if str(e.get("tier", "")) in ["normal", "elite"] and not bool(e.get("tutorial", false)):
			var n: int = e.get("actions", []).size()
			check(n >= 2 and n <= 4, "%s has 2 to 4 actions (%d)" % [e["id"], n])
	var st := setup()
	var drop := enemy("puddle_imp")
	check(drop["actions"][0].get("statusAfter", "") == "wet", "enemy actions can leave statuses")

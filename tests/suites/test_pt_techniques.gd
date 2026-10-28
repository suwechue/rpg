## PT Part 8: Techniques, reconfiguring, advanced classes and Vector unlocks.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const CC := preload("res://src/core/progression/class_change.gd")
const RM := preload("res://src/core/run/run_model.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")


func test_techniques() -> void:
	var ch := Char.create(db(), "mage", seeded(1))
	check(ch["techniques"] == ["still_mind"], "a mage starts with Still Mind")
	ch["level"] = 6
	var opts := Lv.technique_options(db(), ch)
	check(not opts.has("still_mind") and not opts.has("stored_formula"), "owned and planned Techniques aren't offered")
	var lean_first: Dictionary = Lv.techniques(db())[str(opts[0])]
	check(str(lean_first["category"]) in ["kinetics", "meditation"], "the class's leaning categories come first")
	check(Lv.choose_technique(db(), ch, "one_with_the_formula") == false, "tier 6 needs level 18")
	check(Lv.choose_technique(db(), ch, "resilient_mind"), "pick Resilient Mind")
	check(bool(Char.collect_mods(db(), ch)["combat"].get("stableRolls", false)), "its mod applies")
	check(Lv.reconfigure(db(), ch, "resilient_mind", "conversion_reflex") and ch["techniques"].has("conversion_reflex") and not ch["techniques"].has("resilient_mind"), "reconfigure swaps one Technique")
	var rk := Char.create(db(), "fighter", seeded(2))
	check(rk["knownForms"].has("construct") == false, "fighters don't start with Construct")
	rk["techniques"] = []
	rk["level"] = 2
	check(Lv.choose_technique(db(), rk, "runic_toolkit") and rk["knownForms"].has("construct"), "Runic Toolkit teaches Construct")


func test_advanced_classes() -> void:
	var run := RM.new_run(db(), 1, "mage", seeded(1))
	var p: Dictionary = run["player"]
	var alch: Dictionary = {}
	for c in db()["classes"]["classes"]:
		if c["id"] == "alchemist":
			alch = c
	check(not alch.is_empty() and CC.requirement_error(db(), run, p, alch) != "", "the Alchemist needs Stored Formula")


func test_vector_unlocks() -> void:
	var ch := Char.create(db(), "fighter", seeded(1), { "knownVectors": ["force"], "vectorAffinity": { "force": 10.0, "heat": 1.0 } })
	check(Lv.advanced_unlocked(db(), ch, "gravity"), "a Force-heavy character unlocks Gravity")
	check(not Lv.advanced_unlocked(db(), ch, "shadow"), "but not Shadow")
	check(not Lv.advanced_unlocked(db(), ch, "probability"), "Probability is data only")
	var nxt := Lv.next_unlocks(db(), ch)
	check(nxt.any(func(n: Dictionary) -> bool: return str(n["axis"]) == "gravity" and bool(n["ready"])), "the Compendium can list the next unlock")


func test_technique_hooks_in_combat() -> void:
	var ch := Char.create(db(), "mage", seeded(1), { "isPlayer": true })
	ch["techniques"] = ["internal_casting", "mid_flight_correction"]
	var e: Dictionary = DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)
	var st := StateScript.new(db(), seeded(5), { "layout": { "map": ["Ph.....cE"] }, "party": [{ "char": ch }], "enemies": [e], "partyFirst": true })
	var p = st.units[0]
	var hp: int = p.hp
	st.current = p
	st._enter_cell(p, Vector2i(1, 0))
	check(p.hp == hp, "Internal Casting: hazards don't hurt on your own turn")
	check(st.cover_mul(p.cell, Vector2i(6, 0), true) == 1.0, "Mid-Flight Correction ignores half cover")


func test_new_vector_content() -> void:
	var per := {}
	for c in db()["cards/advanced_vector_cards"]["cards"]:
		for axis in c.get("vectors", {}):
			per[axis] = int(per.get(axis, 0)) + 1
	for axis in ["gravity", "lightning", "sound", "shadow", "warding"]:
		check(int(per.get(axis, 0)) >= 6, "%s has 6+ cards (%d)" % [axis, int(per.get(axis, 0))])
	for axis in ["poison", "psychic", "cognition"]:
		check(int(per.get(axis, 0)) >= 4, "%s has 4+ cards (%d)" % [axis, int(per.get(axis, 0))])
	var fams: Array = db()["enemies/vector_families"]["enemies"]
	check(fams.size() == 10, "10 new enemy families")
	var new_total: int = fams.size() + db()["enemies/patch_enemies"]["enemies"].size()
	check(new_total >= 24, "24+ new enemies across PT Parts 7 and 8 (%d)" % new_total)
	var tpl := {}
	for t in db()["encounters"]["templates"]:
		tpl[str(t["id"])] = true
	check(tpl.has("storm_front") and tpl.has("toxic_garden") and tpl.has("gravity_trap"), "combo-themed encounter templates")
	var card_total := 0
	for key in ["cards/advanced_vector_cards", "cards/class_fighter", "cards/class_rogue", "cards/class_healer", "cards/class_mage", "cards/class_bard", "cards/synergy_cards"]:
		card_total += db()[key]["cards"].size()
	check(card_total >= 80, "80+ new cards across PT Parts 7 and 8 (%d)" % card_total)

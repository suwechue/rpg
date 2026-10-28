## M11: UI skin data, card faces, status display.
extends "res://tests/suite.gd"

const CardRules := preload("res://src/core/card.gd")
const Spec := preload("res://src/core/assets/asset_specs.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")


func test_ui_data_complete() -> void:
	var ui: Dictionary = db()["ui"]
	for c in ["bg", "bgLight", "border", "text", "dim", "accent", "good", "bad", "party", "enemy"]:
		check(ui["colors"].has(c), "color %s defined" % c)
	for axis in db()["spaces"]["arcane"]["axes"]:
		check(ui["vectorColors"].has(axis) and ui["vectorColorsColorblind"].has(axis), "%s has both palettes" % axis)
		check(ui["vectorPatterns"].has(axis), "%s has a pattern" % axis)
		check(not Spec.spec(db(), "icon_vector_%s" % axis).is_empty(), "%s has an icon" % axis)
		check(not Spec.spec(db(), "card_art_%s" % axis).is_empty(), "%s has default card art" % axis)
	var cb: Array = ui["vectorColorsColorblind"].values()
	var seen := {}
	for c in cb:
		seen[str(c)] = true
	check(seen.size() == cb.size(), "colorblind colors are all different")
	for s in ui["statuses"]:
		check(not Spec.spec(db(), str(ui["statuses"][s]["icon"])).is_empty(), "status %s icon listed" % s)
	check(not db()["vectors"].has("colors"), "Vector colors live only in ui.json")


func test_card_summary_is_short() -> void:
	for c in db()["cards/starter_cards"]["cards"]:
		var line := CardRules.summary(db(), c)
		check(line.length() > 0 and line.length() <= 10, "%s one-line effect fits a card: '%s'" % [c["id"], line])
	var spell := CardRules.make_spell(db(), { "heat": 1.0 }, "bolt", "standard")
	check(CardRules.summary(db(), spell) == "Bolt 7", "spell summary is form and power: %s" % CardRules.summary(db(), spell))


func test_card_art_ids() -> void:
	var spell := CardRules.make_spell(db(), { "cold": 1.0, "heat": 0.5 }, "burst", "minor")
	var ids := CardRules.art_ids(db(), spell)
	check(ids.has("card_art_heat") and ids[-1] == "card_art_spell", "spell art falls back to its first Vector, then its kind: %s" % str(ids))
	var strike := { "id": "card_strike", "kind": "basic" }
	check(CardRules.art_ids(db(), strike) == ["card_art_card_strike", "card_art_basic"], "basic cards try their own art then the basic art")


func test_status_list_order() -> void:
	var ch := preload("res://src/core/character.gd").create(db(), "mage", seeded(1), { "isPlayer": true })
	var foe: Dictionary = DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)
	var st: StateScript = StateScript.new(db(), seeded(1), { "layout": { "map": ["P..E"] }, "party": [{ "char": ch }], "enemies": [foe] })
	var u = st.units[0]
	u.statuses["slow"] = 1
	u.statuses["root"] = 1
	u.shield = 3
	check(st.status_list(u) == ["root", "slow", "shield"], "statuses in display order: %s" % str(st.status_list(u)))

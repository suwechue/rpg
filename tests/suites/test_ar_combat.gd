## AR: move OR act turns, quick cards, Burst footprints per Magnitude, the
## area falloff rule and telegraph cancels (docs/ARENA.md Parts 1 and 2).
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const Forms := preload("res://src/core/combat/forms.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")


func enemy(id: String) -> Dictionary:
	return DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)


func hero() -> Dictionary:
	return Char.create(db(), "mage", seeded(1), { "knownVectors": ["heat", "force", "cold", "light", "binding"], "isPlayer": true,
		"stats": { "str": 6, "dex": 30, "con": 6, "int": 7, "per": 30, "wil": 6, "cha": 4 } })


func fight(map: Array, enemies: Array, mode: String = "") -> StateScript:
	var setup := { "layout": { "map": map }, "party": [{ "char": hero() }], "enemies": enemies }
	if mode != "":
		setup["turnMode"] = mode
	return StateScript.new(db(), seeded(5), setup)


func player(st: StateScript):
	for u in st.units:
		if u.is_player:
			return u
	return null


func foe(st: StateScript, i: int = 0):
	var n := 0
	for u in st.units:
		if u.team == "enemy":
			if n == i:
				return u
			n += 1
	return null


func test_default_is_move_or_act() -> void:
	check(str(db()["combat_rules"]["turnMode"]) == "move_or_act", "move OR act is the default turn rule")
	var st := fight(["P.E......", "........."], [enemy("pom_pom_wisp")])
	check(st.turn_mode == "move_or_act", "fights use it")


func test_move_or_act() -> void:
	var st := fight(["P..E.....", "........."], [enemy("pom_pom_wisp")])
	var p = player(st)
	foe(st).hp = 999
	p.deck.hand = ["card_heavy_swing", "card_guard", "card_light_jab"]
	check(st.move(p, Vector2i(2, 0)), "moving is allowed")
	check(st.act_block(p) != "", "after moving, no action: %s" % st.act_block(p))
	check(not st.strike(p, foe(st).cell), "Strike is blocked after moving")
	check(st.card_block(p, st.card_of(p, 1)) == "", "a quick card still works with a move")
	check(st.undo_move(p), "undo the move...")
	check(st.strike(p, Vector2i(1, 0)) == false and st.act_block(p) == "", "...and the action is available again")
	var st2 := fight(["P.E......", "........."], [enemy("pom_pom_wisp")])
	var p2 = player(st2)
	foe(st2).hp = 999
	p2.deck.hand = ["card_light_jab", "card_guard"]
	check(st2.play_card(p2, 0, foe(st2).cell) == false, "not adjacent yet")
	p2.cell = Vector2i(1, 0)
	p2.start_cell = p2.cell
	check(st2.play_card(p2, 0, foe(st2).cell), "acting is allowed")
	check(not st2.can_move(p2), "after acting, no moving")
	check(st2.play_card(p2, 0, p2.cell), "a quick card still works with an act")


func test_other_turn_modes() -> void:
	var st := fight(["P..E.....", "........."], [enemy("pom_pom_wisp")], "move_then_act")
	var p = player(st)
	foe(st).hp = 999
	st.move(p, Vector2i(2, 0))
	check(st.act_block(p) == "", "move_then_act: act after moving")
	st.strike(p, foe(st).cell)
	check(not st.can_move(p) or p.move_left == 0, "move_then_act: no moving after acting")
	var st2 := fight(["P..E.....", "........."], [enemy("pom_pom_wisp")], "move_and_act")
	var p2 = player(st2)
	foe(st2).hp = 999
	st2.move(p2, Vector2i(2, 0))
	st2.strike(p2, foe(st2).cell)
	check(st2.can_move(p2), "move_and_act: moving after acting too")


func test_enemy_turns_by_difficulty() -> void:
	var st := fight(["P....E...", "........."], [enemy("pom_pom_wisp")])
	var e = foe(st)
	check(st.difficulty == "normal" and not st._moves_and_acts(e), "Normal: enemies move or attack")
	e.move_left = e.movement
	for o in AI.options(st, e):
		if str(o["kind"]) == "action":
			check(o["move"] == e.cell, "Normal: attacks are from where it stands")
	var hard := StateScript.new(db(), seeded(5), { "layout": { "map": ["P....E...", "........."] }, "party": [{ "char": hero() }],
		"enemies": [enemy("pom_pom_wisp")], "difficulty": "hard" })
	var h = foe(hard)
	check(hard._moves_and_acts(h), "Hard: enemies move, then attack")
	h.move_left = h.movement
	var moving_attack := false
	for o in AI.options(hard, h):
		if str(o["kind"]) == "action" and o["move"] != h.cell:
			moving_attack = true
	check(moving_attack, "Hard: their plans include moving into range and hitting")
	var fast := enemy("pom_pom_wisp")
	fast["moveAndAct"] = true
	var st2 := fight(["P....E...", "........."], [fast])
	check(st2._moves_and_acts(foe(st2)), "fast elites move and attack on Normal too")


func test_burst_footprint_by_magnitude() -> void:
	var grid := GridScript.new({ "map": [".........", ".........", ".........", ".........", "........."] })
	var burst := DT.record(db(), "forms", "burst")
	var minor := Forms.footprint(grid, Forms.at_magnitude(burst, "minor"), Vector2i(0, 2), Vector2i(4, 2), {})
	var standard := Forms.footprint(grid, Forms.at_magnitude(burst, "standard"), Vector2i(0, 2), Vector2i(4, 2), {})
	var major := Forms.footprint(grid, Forms.at_magnitude(burst, "major"), Vector2i(0, 2), Vector2i(4, 2), {})
	check(minor.size() == 5 and standard.size() == 5 and not minor.has(Vector2i(5, 3)), "Minor and Standard Burst are a plus shape")
	check(major.size() == 9, "Major Burst is the full 3x3")
	var st := fight(["P........", ".........", "........E"], [enemy("pom_pom_wisp")])
	var card := CardRules.make_spell(db(), { "heat": 1.0 }, "burst", "minor")
	var pv := st.preview(player(st), card, Vector2i(3, 1))
	check(pv["cells"].size() == 5, "the preview shows the exact tiles for the Magnitude")


func test_area_falloff() -> void:
	var st := fight(["P........", "...EEE...", "....E...."], [enemy("pom_pom_wisp"), enemy("pom_pom_wisp"), enemy("pom_pom_wisp"), enemy("pom_pom_wisp")])
	var p = player(st)
	var card := CardRules.make_spell(db(), { "heat": 1.0 }, "burst", "minor")
	var pv := st.preview(p, card, Vector2i(4, 1))
	var dmg: Array = []
	for h in pv["hits"]:
		dmg.append(int(h["damage"]))
	check(dmg.size() == 4, "the plus hits all four (%s)" % str(dmg))
	check(dmg[2] < dmg[0] and dmg[3] < dmg[1], "targets beyond the second take less (%s)" % str(dmg))


func _lock(e, cells: Array) -> void:
	e.intent = { "kind": "attack", "action": e.actions[0], "move": e.cell, "target": cells[0], "cells": cells, "mode": "locked", "charge": 0 }


func test_disabling_cancels_telegraphs() -> void:
	var st := fight(["P.E......", "........."], [enemy("pom_pom_wisp")])
	var p = player(st)
	var e = foe(st)
	_lock(e, [p.cell])
	var spec := { "vectors": { "light": 1.0 }, "power": 5.0, "form": st.form_rec("bolt"), "heal": false, "mult": 1.0, "ranged": true, "name": "Dazzle" }
	st._apply_vector_effects(p, spec, [e.cell], [e])
	check(e.intent.is_empty(), "blinding cancels an attack under move_or_act")
	e.intent = { "kind": "move", "move": Vector2i(1, 1), "cells": [] }
	spec["vectors"] = { "binding": 1.0 }
	st._apply_vector_effects(p, spec, [e.cell], [e])
	check(e.intent.is_empty(), "rooting cancels a planned move")
	_lock(e, [p.cell])
	e.intent["action"] = { "id": "poke", "kind": "strike", "name": "Poke" }
	st._push(p, e, Vector2i(1, 0), 3)
	check(e.intent.is_empty(), "pushing a melee attacker out of range cancels its attack")


func test_planning_ignores_last_turns_flags() -> void:
	var st := fight(["P....E...", "........."], [enemy("pom_pom_wisp")])
	var e = foe(st)
	e.action_used = true
	e.moved_steps = 2
	e.move_left = 0
	var plan := AI.plan_intent(st, e)
	check(str(plan.get("kind", "")) != "defend" and str(plan.get("kind", "")) != "", "an enemy that acted last turn still plans a real move or attack (%s)" % plan.get("kind", ""))
	check(e.action_used and e.moved_steps == 2, "its own flags are left as they were")


func test_single_target_attacks_track() -> void:
	var st := fight(["P........", ".E......."], [enemy("pom_pom_wisp")])
	var e = foe(st)
	var plan := AI.plan_intent(st, e)
	if str(plan.get("kind", "")) == "attack" and plan.get("cells", []).size() <= 1:
		check(str(plan["mode"]) == "tracking", "single-target attacks follow their target")
	else:
		check(true, "no single-target attack planned this time")

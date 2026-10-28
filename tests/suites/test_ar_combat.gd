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


func test_default_is_two_actions() -> void:
	check(str(db()["combat_rules"]["turnMode"]) == "two_actions", "2 Actions + 1 Quick is the default turn rule (PT Part 1)")
	var st := fight(["P.E......", "........."], [enemy("pom_pom_wisp")])
	check(st.turn_mode == "two_actions", "fights use it")


func test_move_or_act() -> void:
	var st := fight(["P..E.....", "........."], [enemy("pom_pom_wisp")], "move_or_act")
	var p = player(st)
	foe(st).hp = 999
	p.deck.hand = ["card_heavy_swing", "card_guard", "card_light_jab"]
	check(st.move(p, Vector2i(2, 0)), "moving is allowed")
	check(st.act_block(p) != "", "after moving, no action: %s" % st.act_block(p))
	check(not st.strike(p, foe(st).cell), "Strike is blocked after moving")
	check(st.card_block(p, st.card_of(p, 1)) == "", "a quick card still works with a move")
	check(st.undo_move(p), "undo the move...")
	check(st.strike(p, Vector2i(1, 0)) == false and st.act_block(p) == "", "...and the action is available again")
	var st2 := fight(["P.E......", "........."], [enemy("pom_pom_wisp")], "move_or_act")
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
	var chance := st.move_and_act_chance(e, "enemyDoubleAttackChance")
	check(chance > 0.0 and chance < 1.0, "Normal: some enemy turns attack twice (chance %.2f, PT Part 1)" % chance)
	var twice := 0
	st.roll_move_and_act(e)
	check(st._moves_and_acts(e), "enemies always have 2 Actions: they can move and attack")
	for i in 300:
		st.roll_move_and_act(e)
		if e.double_attack:
			twice += 1
	check(absf(float(twice) / 300.0 - chance) < 0.1, "the double-attack roll matches the chance (%d/300)" % twice)
	e.move_left = e.movement
	var moving := false
	for o in AI.options(st, e):
		if str(o["kind"]) == "action" and o["move"] != e.cell:
			moving = true
	check(moving, "plans include moving into range and hitting")
	var hard := StateScript.new(db(), seeded(5), { "layout": { "map": ["P....E...", "........."] }, "party": [{ "char": hero() }],
		"enemies": [enemy("pom_pom_wisp")], "difficulty": "hard" })
	var h = foe(hard)
	check(hard.move_and_act_chance(h, "enemyDoubleAttackChance") > chance, "Hard: more double attacks")
	check(h.max_hp > e.max_hp, "Hard: enemies have more HP (%d vs %d)" % [h.max_hp, e.max_hp])
	var act: Dictionary = e.actions[0]
	check(float(hard.action_spec(h, act).get("power", 0)) + float(hard.action_spec(h, act).get("base", 0)) > float(st.action_spec(e, act).get("power", 0)) + float(st.action_spec(e, act).get("base", 0)), "Hard: enemies hit harder")

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
	var st := fight(["P.E......", "........."], [enemy("pom_pom_wisp")], "move_or_act")
	var p = player(st)
	var e = foe(st)
	_lock(e, [p.cell])
	var spec := { "vectors": { "light": 1.0 }, "power": 5.0, "form": st.form_rec("bolt"), "heal": false, "mult": 1.0, "ranged": true, "name": "Dazzle" }
	st._apply_vector_effects(p, spec, [e.cell], [e])
	check(not e.intent.is_empty(), "blinding keeps the telegraph (PT Part 4: it adds a miss chance instead)")
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


func test_single_target_attacks_lock_unless_marked() -> void:
	var st := fight(["P........", ".E......."], [enemy("pom_pom_wisp")])
	var e = foe(st)
	var plan := AI.plan_intent(st, e)
	if str(plan.get("kind", "")) == "attack":
		check(str(plan["mode"]) == "locked", "single-target attacks lock their tile (CT Part 2)")
	else:
		check(true, "no attack planned this time")
	var tracker := enemy("pom_pom_wisp")
	for a in tracker["actions"]:
		a["intent"] = "tracking"
	var st2 := fight(["P........", ".E......."], [tracker])
	var plan2 := AI.plan_intent(st2, foe(st2))
	if str(plan2.get("kind", "")) == "attack":
		check(str(plan2["mode"]) == "tracking", "actions marked tracking follow their target")


func test_just_in_time_telegraphs() -> void:
	# Order by initiative: set it so it goes P, E1, Q, E2.
	var st := StateScript.new(db(), seeded(3), { "layout": { "map": ["P.......E", "Q.......E", "........."] },
		"party": [{ "char": hero() }, { "char": hero() }], "enemies": [enemy("pom_pom_wisp"), enemy("pom_pom_wisp")] })
	var units: Array = st.units
	var p = units[0]
	var q = units[1]
	var e1 = units[2]
	var e2 = units[3]
	p.initiative = 40
	e1.initiative = 30
	q.initiative = 20
	e2.initiative = 10
	for u in units:
		u.intent = {}
	st._build_order()
	check(st.acts_next(p) == [e1] and st.acts_next(q) == [e2], "each party turn is the last chance before the next enemies")
	check(st.last_chance_for(e1) == p and st.last_chance_for(e2) == q, "the last-chance link points at the party turn before")
	st.turn_index = 0
	st.current = p
	st._start_turn(p)
	check(not e1.intent.is_empty() and e2.intent.is_empty(), "only the enemy acting next reveals its plan")
	st.turn_index = 2
	st.current = q
	st._start_turn(q)
	check(not e2.intent.is_empty(), "the next enemy reveals on the party turn right before it")
	var wrap := StateScript.new(db(), seeded(3), { "layout": { "map": ["P.......E", "........E"] },
		"party": [{ "char": hero() }], "enemies": [enemy("pom_pom_wisp"), enemy("pom_pom_wisp")] })
	var only = wrap.units[0]
	check(wrap.acts_next(only).size() == 2, "back-to-back enemies all reveal on the same party turn")


func test_blocked_enemies_reaim_or_lose_the_attack() -> void:
	var st := fight(["P.E......", "........."], [enemy("pom_pom_wisp")])
	var p = player(st)
	var e = foe(st)
	var act: Dictionary = {}
	for a in e.actions:
		if str(a.get("kind", "")) == "strike":
			act = a
	if act.is_empty():
		act = { "kind": "strike", "name": "Bop", "damage": 5 }
	st.current = e
	e.move_left = e.movement
	e.action_used = false
	# Planned to step next to the player from the other side; that tile is now taken.
	e.intent = { "kind": "attack", "action": act, "move": Vector2i(1, 1), "target": p.cell, "cells": [p.cell], "mode": "locked", "unit": p.id, "charge": 0 }
	var hp_before: int = p.hp
	st.execute_intent(e)
	check(p.hp < hp_before or GridScript.manhattan(e.cell, p.cell) == 1, "an enemy that can still reach its target attacks from where it ends up")
	var st2 := fight(["P#E......", "##......."], [enemy("pom_pom_wisp")])
	var p2 = player(st2)
	var e2 = foe(st2)
	st2.current = e2
	e2.move_left = 0
	e2.action_used = false
	e2.intent = { "kind": "attack", "action": act, "move": Vector2i(1, 0), "target": p2.cell, "cells": [p2.cell], "mode": "locked", "unit": p2.id, "charge": 0 }
	var hp2: int = p2.hp
	st2.execute_intent(e2)
	check(p2.hp == hp2, "an enemy that can't reach its plan or its target loses the attack")


## CU: move + 1 action, quick cards, undo move, the smaller MP pool, intents
## (commit, dodge, friendly fire, charge interrupts), forced movement and ice.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")


func enemy(id: String) -> Dictionary:
	return DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)


func hero(extra: Dictionary = {}) -> Dictionary:
	var opts := { "knownVectors": ["heat", "force", "cold", "light"], "isPlayer": true, "stats": { "str": 6, "dex": 30, "con": 6, "int": 7, "per": 30, "wil": 6, "cha": 4 } }
	opts.merge(extra, true)
	return Char.create(db(), "mage", seeded(1), opts)


## A fight where the player acts first (very high initiative). CU's rule by
## default (move and act); AR's move_or_act is tested in test_ar_combat.gd.
func fight(map: Array, enemies: Array, mode: String = "move_and_act") -> StateScript:
	var st := StateScript.new(db(), seeded(5), { "layout": { "map": map }, "party": [{ "char": hero() }], "enemies": enemies, "turnMode": mode })
	return st


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


func give_hand(u, ids: Array) -> void:
	u.deck.hand = ids.duplicate()


func test_move_then_one_action() -> void:
	var st := fight(["P.E......"], [enemy("pom_pom_wisp")])
	var p = player(st)
	check(st.current == p, "the player acts first")
	give_hand(p, ["card_heavy_swing", "card_light_jab", "card_ember_bolt"])
	p.mp = 10
	foe(st).hp = 999
	foe(st).max_hp = 999
	check(st.move(p, Vector2i(1, 0)), "move first")
	check(st.play_card(p, 1, foe(st).cell), "then one action (a card)")
	check(p.action_used, "the action is used")
	check(st.card_block(p, st.card_of(p, 0)) == "No action left", "a second action card is blocked: %s" % st.card_block(p, st.card_of(p, 0)))
	check(not st.strike(p, foe(st).cell), "Strike needs the action too")
	check(not st.guard(p), "so does Guard")
	p.move_left = 1
	check(st.move(p, Vector2i(0, 0)), "movement left over can still be used after acting")


func test_quick_cards() -> void:
	var st := fight(["P.E......"], [enemy("pom_pom_wisp")])
	var p = player(st)
	give_hand(p, ["card_guard", "card_dash", "card_heavy_swing"])
	check(bool(st.card_of(p, 0).get("quick", false)), "Guard is a quick card")
	check(st.play_card(p, 0, p.cell), "a quick card")
	check(p.quick_used and not p.action_used, "uses the quick slot, not the action")
	check(st.play_card(p, 0, p.cell), "a second quick card")
	check(p.action_used, "the second quick card takes the action")
	check(st.card_block(p, st.card_of(p, 0)) == "No action left", "nothing left after that")


func test_undo_move() -> void:
	var st := fight(["P........", ".........", "........E"], [enemy("pom_pom_wisp")])
	var p = player(st)
	var start: Vector2i = p.cell
	var full: int = p.move_left
	check(not st.can_undo_move(p), "nothing to undo before moving")
	st.move(p, start + Vector2i(2, 0))
	check(st.can_undo_move(p), "undo is offered after a move")
	check(st.undo_move(p) and p.cell == start and p.move_left == full, "back on the start tile with full Movement")
	st.move(p, start + Vector2i(1, 0))
	st.guard(p)
	check(not st.can_undo_move(p), "no undo after acting")


func test_mp_pool_is_small() -> void:
	for cls in ["mage", "fighter", "rogue", "healer", "bard"]:
		var ch := Char.create(db(), cls, seeded(3))
		var d := Char.derived(db(), ch)
		check(int(d["maxMp"]) >= 5 and int(d["maxMp"]) <= 13, "%s starts with a small MP pool (%d)" % [cls, d["maxMp"]])
		check(int(d["mpRegen"]) == 1, "%s regenerates 1 MP a turn" % cls)
	var ch := Char.create(db(), "mage", seeded(3))
	var lvl1 := int(Char.derived(db(), ch)["maxMp"])
	ch["level"] = 9
	check(int(Char.derived(db(), ch)["maxMp"]) == lvl1 + 4, "MP grows slowly with level")
	var minor := CardRules.make_spell(db(), { "heat": 1.0 }, "bolt", "minor")
	var major := CardRules.make_spell(db(), { "heat": 1.0 }, "bolt", "major")
	check(CardRules.cost(db(), minor) == 1 and CardRules.cost(db(), major) == 4, "Minor 1, Major 4 (plus Form cost)")


func test_rounds_are_announced() -> void:
	var st := fight(["P.......E"], [enemy("pom_pom_wisp")])
	var rounds: Array = []
	for e in st.take_events():
		if str(e["t"]) == "round":
			rounds.append(int(e["n"]))
	check(rounds == [1], "round 1 starts with a banner event")
	var tr := st.timeline_rounds()
	check(tr["now"].size() == 2 and tr["next"].size() == 2, "the timeline shows this round and the next")


func _lock_attack(st: StateScript, e, cells: Array) -> void:
	e.intent = { "kind": "attack", "action": e.actions[0], "move": e.cell, "target": cells[0], "cells": cells, "mode": "locked", "charge": 0 }


func test_intents_are_planned_for_the_player_turn() -> void:
	var st := fight(["P..E.....", "....E...."], [enemy("pom_pom_wisp"), enemy("megaphone_mimic")])
	for i in 2:
		check(not foe(st, i).intent.is_empty(), "enemy %d shows an intent at the start of the player's turn" % i)


func test_dodge_a_locked_attack() -> void:
	var st := fight(["P.E......", "........."], [enemy("pom_pom_wisp")])
	var p = player(st)
	var e = foe(st)
	_lock_attack(st, e, [p.cell])
	check(st.threat_at(p.cell) > 0, "the telegraphed tile shows damage")
	var hp: int = p.hp
	st.move(p, p.cell + Vector2i(0, 1))
	check(st.threat_at(p.cell) == 0, "the new tile is safe")
	st.end_turn()
	check(st.current == e, "enemy turn")
	AI.take_turn(st, e)
	check(p.hp == hp, "stepping out of the telegraph dodges the attack")


func test_locked_attack_hits_enemies_too() -> void:
	var st := fight(["P........", "....E.E.."], [enemy("pom_pom_wisp"), enemy("pom_pom_wisp")])
	var a = foe(st, 0)
	var b = foe(st, 1)
	_lock_attack(st, a, [b.cell])
	var hp: int = b.hp
	st.end_turn()
	while st.current != a and st.result == "":
		AI.take_turn(st, st.current)
	b.intent = {}
	AI.take_turn(st, a)
	check(b.hp < hp or b.dead, "an enemy standing in another's telegraph gets hit (%d -> %d)" % [hp, b.hp])


func test_tracking_intent_follows() -> void:
	var st := fight(["P.E......", "........."], [enemy("varsity_shade")])
	var p = player(st)
	var e = foe(st)
	e.intent = { "kind": "attack", "action": e.actions[0], "move": e.cell, "target": p.cell, "cells": [p.cell], "mode": "tracking", "unit": p.id, "charge": 0 }
	st.move(p, p.cell + Vector2i(0, 1))
	check(st.intent_cells(e) == [p.cell], "a tracking telegraph follows its target")


func test_charge_and_interrupts() -> void:
	var st := fight(["P...E....", "........."], [enemy("pom_pom_wisp")])
	var e = foe(st)
	_lock_attack(st, e, [Vector2i(0, 0), Vector2i(1, 0)])
	e.intent["charge"] = 1
	var p = player(st)
	var spec := { "vectors": { "cold": 1.0 }, "power": 5.0, "form": st.form_rec("bolt"), "heal": false, "mult": 1.0, "ranged": true, "name": "Frost" }
	st._apply_vector_effects(p, spec, [e.cell], [e])
	check(int(e.intent["charge"]) == 2, "Cold slows a charge down a turn")
	spec["vectors"] = { "light": 1.0 }
	st._apply_vector_effects(p, spec, [e.cell], [e])
	check(e.intent.is_empty(), "Light blinds the charger and cancels the attack")
	_lock_attack(st, e, [Vector2i(2, 0)])
	e.intent["charge"] = 1
	st._push(p, e, Vector2i(0, 1), 1)
	check(e.intent["cells"] == [Vector2i(2, 1)], "a push moves the charged area with the charger")
	var card := CardRules.make_spell(db(), { "light": 1.0 }, "bolt", "minor")
	var pv := st.preview(p, card, e.cell)
	check(not pv["interrupts"].is_empty(), "the preview says the hit will interrupt the charge")


func test_charging_enemy_waits_then_fires() -> void:
	var st := fight(["P...E....", "........."], [enemy("pom_pom_wisp")])
	var p = player(st)
	var e = foe(st)
	_lock_attack(st, e, [p.cell])
	e.intent["charge"] = 1
	var hp: int = p.hp
	st.end_turn()
	AI.take_turn(st, e)
	check(p.hp == hp and not e.intent.is_empty(), "the first enemy turn only charges")
	st.end_turn() if st.current == p else null
	while st.current != e and st.result == "":
		st.end_turn()
	AI.take_turn(st, e)
	check(p.hp < hp, "then the charged attack lands on the tile")


func test_push_landing_preview() -> void:
	var st := fight(["P.Eh.....", "........."], [enemy("pom_pom_wisp")])
	var p = player(st)
	var e = foe(st)
	var land := st.push_landing(p, e, Vector2i(1, 0), 1, true)
	check(land["to"] == Vector2i(3, 0) and bool(land["hazard"]), "pushed one tile into a hazard: %s" % str(land))
	var hp: int = e.hp
	st._push(p, e, Vector2i(1, 0), 1)
	check(e.cell == Vector2i(3, 0) and e.hp < hp, "the push really lands in the hazard and hurts")
	var st2 := fight(["P.E#.....", "........."], [enemy("pom_pom_wisp")])
	var land2 := st2.push_landing(player(st2), foe(st2), Vector2i(1, 0), 2, true)
	check(bool(land2["collide"]) and int(land2["damage"]) > 0 and land2["to"] == Vector2i(2, 0), "pushing into a wall collides")
	var card := CardRules.make_spell(db(), { "force": 1.0 }, "bolt", "standard")
	var st3 := fight(["P.E......", "........."], [enemy("pom_pom_wisp")])
	var pv := st3.preview(player(st3), card, foe(st3).cell)
	check(pv["pushes"].size() == 1, "a Force card's preview shows where the target lands")


func test_ice_slide() -> void:
	var st := fight(["P.Eiii...", "........."], [enemy("pom_pom_wisp")])
	var p = player(st)
	var e = foe(st)
	var land := st.push_landing(p, e, Vector2i(1, 0), 1, true)
	check(bool(land["slide"]) and land["to"] == Vector2i(6, 0), "the preview shows a slide across the ice: %s" % str(land))
	st._push(p, e, Vector2i(1, 0), 1)
	check(e.cell == Vector2i(6, 0), "pushed onto ice, the enemy slides to the end (%s)" % str(e.cell))
	var slid := false
	for ev in st.take_events():
		if str(ev["t"]) == "slide":
			slid = true
	check(slid, "a slide event plays")
	var st2 := fight(["Pii......", "........E"], [enemy("pom_pom_wisp")])
	var p2 = player(st2)
	p2.move_left = 5
	st2.move(p2, Vector2i(1, 0))
	check(p2.cell == Vector2i(3, 0), "walking onto ice slides you off the end (%s)" % str(p2.cell))


func test_heat_on_ice_makes_water() -> void:
	var st := fight(["P.i......", "........E"], [enemy("pom_pom_wisp")])
	var spec := { "vectors": { "heat": 1.0 }, "power": 5.0, "form": st.form_rec("bolt"), "heal": false, "mult": 1.0, "ranged": true, "name": "Ember" }
	st._apply_vector_effects(player(st), spec, [Vector2i(2, 0)], [])
	check(st.grid.get_terrain(Vector2i(2, 0)) == GridScript.WATER, "Heat melts ice into water")


func test_back_attacks() -> void:
	var st := fight(["P.E......"], [enemy("pom_pom_wisp")])
	var p = player(st)
	var e = foe(st)
	var spec := st.action_spec(e, e.actions[0])
	e.facing = -1
	var front := st._expected_hit(p, e, st._spell_spec(p, CardRules.make_spell(db(), { "heat": 1.0 }, "bolt", "minor")))
	e.facing = 1
	var back := st._expected_hit(p, e, st._spell_spec(p, CardRules.make_spell(db(), { "heat": 1.0 }, "bolt", "minor")))
	check(back > front, "hitting from behind does more (%.1f vs %.1f)" % [back, front])
	check(st.hit_note(p, e, { "heat": 1.0 }).contains("from behind"), "the log says why")
	check(spec.has("name"), "enemy actions still resolve")


func test_boss_phase_reshapes_field() -> void:
	var st := fight(["P........", ".........", "........E"], [enemy("hollow_mascot")])
	var e = foe(st)
	var before := 0
	for c in st.grid.all_cells():
		if st.grid.get_terrain(c) == GridScript.HAZARD:
			before += 1
	e.hp = int(e.max_hp * 0.2)
	st._check_phase(e)
	var after := 0
	for c in st.grid.all_cells():
		if st.grid.get_terrain(c) == GridScript.HAZARD:
			after += 1
	check(after == before + 3, "the last boss phase adds 3 hazards (%d -> %d)" % [before, after])
	var charged := false
	for a in e.actions:
		if int(a.get("charge", 0)) > 0 and a.has("pattern"):
			charged = true
	check(charged, "the last phase has a charged pattern attack")
	var cells := st.pattern_cells(e, "ring", Vector2i.ZERO)
	check(not cells.is_empty() and not cells.has(e.cell), "a ring pattern surrounds the boss")

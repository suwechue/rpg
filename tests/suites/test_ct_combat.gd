## CT: directional cover (Part 3) and who has acted this round (Part 2b).
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const Str := preload("res://src/core/strings.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")


func enemy(id: String) -> Dictionary:
	return DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)


func hero() -> Dictionary:
	return Char.create(db(), "mage", seeded(1), { "knownVectors": ["heat", "force"], "isPlayer": true })


func fight(map: Array, enemies: Array) -> StateScript:
	return StateScript.new(db(), seeded(5), { "layout": { "map": map }, "party": [{ "char": hero() }], "enemies": enemies })


func test_cover_pieces_are_props_with_hp() -> void:
	var st := fight(["P.c.x...E"], [enemy("pom_pom_wisp")])
	var wall = st.unit_at(Vector2i(2, 0))
	var crate = st.unit_at(Vector2i(4, 0))
	check(wall != null and st.is_cover(wall) and wall.max_hp == 15, "a 'c' tile is a low wall with 15 HP")
	check(crate != null and st.is_cover(crate) and crate.max_hp == 8, "an 'x' tile is a crate with 8 HP")
	check(st.grid.walkable_terrain(Vector2i(2, 0)), "the floor under cover is plain floor")
	st._damage(wall, 3, null, "force", "hit")
	check(wall.hp == 9, "Force breaks cover twice as fast (15 - 3x2 = %d)" % wall.hp)
	st._damage(crate, 2, null, "heat", "hit")
	check(crate.hp == 4, "Heat burns crates (8 - 2x2 = %d)" % crate.hp)


func test_cover_is_directional() -> void:
	var st := fight([".........", "....Pc..E", "........."], [enemy("pom_pom_wisp")])
	var cell := Vector2i(4, 1)
	check(st.cover_mul(Vector2i(8, 1), cell, true) == 0.5, "ranged attacks across the cover deal x0.5")
	check(st.cover_mul(Vector2i(8, 1), cell, false) == 0.75, "melee over the cover deals x0.75")
	check(st.cover_mul(Vector2i(7, 2), cell, true) == 0.5, "a slight angle still counts as across")
	check(st.cover_mul(Vector2i(4, 0), cell, true) == 1.0, "from the side: flanking ignores cover")
	check(st.cover_mul(Vector2i(1, 1), cell, true) == 1.0, "from behind: no cover")
	check(st.cover_mul(Vector2i(5, 0), cell, true) == 1.0, "diagonal over the corner counts as flanking")


func test_cover_halves_hits_and_telegraphs() -> void:
	var st := fight([".........", "....Pc..E", "........."], [enemy("pom_pom_wisp")])
	var p = st.units[0]
	var e: UnitScript = null
	for u in st.units:
		if u.team == "enemy":
			e = u
	var act := { "name": "Spark", "form": "bolt", "vectors": { "light": 1.0 }, "damage": 10 }
	var spec := st.action_spec(e, act)
	var covered := st._expected_hit(e, p, spec)
	e.cell = Vector2i(4, 0)
	var flanked := st._expected_hit(e, p, spec)
	check_near(covered, flanked * 0.5, "a ranged hit across cover is halved compared with a flank")
	e.cell = Vector2i(8, 1)
	e.intent = { "kind": "attack", "action": act, "move": Vector2i(4, 2), "target": p.cell, "cells": [p.cell], "mode": "locked", "unit": p.id, "charge": 0 }
	var from_side := st.intent_damage(e, p.cell)
	e.intent["move"] = Vector2i(7, 1)
	var across := st.intent_damage(e, p.cell)
	check(across < from_side, "telegraphs use the planned spot: across cover %d, from the side %d" % [across, from_side])
	check(st.hit_note(e, p, act["vectors"]).contains(Str.t(db(), "combat_state.in_cover")), "the log says the hit was in cover")


func test_preview_shows_cover() -> void:
	var st := fight(["P.......c.E"], [enemy("pom_pom_wisp")])
	var p = st.units[0]
	var e: UnitScript = null
	for u in st.units:
		if u.team == "enemy":
			e = u
	e.cell = Vector2i(9, 0)
	var bolt := CardRules.make_spell(db(), { "heat": 1.0 }, "bolt", "standard")
	p.cell = Vector2i(5, 0)
	var pv := st.preview(p, bolt, e.cell)
	var cov := 1.0
	for h in pv["hits"]:
		if str(h["unit"]) == e.id:
			cov = float(h.get("cover", 1.0))
	check(cov == 0.5, "the hover preview carries the cover multiplier (%.2f)" % cov)


func test_ranged_enemies_seek_cover() -> void:
	var st := fight([".........", "P.....c.E", "........."], [enemy("pom_pom_wisp")])
	var e: UnitScript = null
	for u in st.units:
		if u.team == "enemy":
			e = u
	var p = st.units[0]
	var behind := Vector2i(7, 1)
	var open := Vector2i(7, 0)
	check(st.cover_mul(p.cell, behind, true) < 1.0 and st.cover_mul(p.cell, open, true) == 1.0, "the tile in front of the wall is in cover from the player")
	check(float(db()["ai"].get("coverSeek", 0.0)) > 0.0, "the AI values cover (data/ai.json coverSeek)")


func test_layouts_have_cover() -> void:
	for l in db()["rooms/combat_layouts"]["layouts"]:
		if str(l["id"]) == "training_yard" or bool(l.get("tutorial", false)):
			continue
		var n := 0
		for row in l["map"]:
			n += str(row).count("c") + str(row).count("x")
		check(n >= 3 and n <= 6, "layout %s has 3 to 6 cover pieces (%d)" % [l["id"], n])


func test_acted_this_round() -> void:
	var st := fight(["P.......E"], [enemy("pom_pom_wisp")])
	var first = st.current
	check(not st.acted_this_round(first), "the unit taking its turn isn't marked as done")
	st.end_turn()
	if st.result == "" and st.round_num == 1 and st.current != first:
		check(st.acted_this_round(first), "after its turn, it is marked as done this round")

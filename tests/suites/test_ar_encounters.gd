## AR Part 4b: encounter templates, counts, formations, party scaling,
## reinforcements, boss adds and enemy teamwork.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Enc := preload("res://src/core/dungeon/encounters.gd")
const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const Night := preload("res://src/core/dungeon/night.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const GridScript := preload("res://src/core/combat/grid.gd")


func fresh(seed_value: int = 5) -> Dictionary:
	return RM.new_run(db(), seed_value, "mage", seeded(seed_value))


func test_counts_and_templates() -> void:
	var run := fresh()
	var templates := {}
	for i in 60:
		var rng := seeded(100 + i)
		var e := Enc.build(db(), run, 1, "combat", rng)
		templates[e["template"]] = true
		var weight := 0.0
		for r in e["roles"]:
			weight += 0.5 if str(r) == "minion" else 1.0
		weight += float(e["reinforcements"].get("enemies", []).size())
		check(weight >= 3.0 - 0.01, "week 1 fights have a budget of 3 or more (%s: %.1f)" % [e["template"], weight])
	check(templates.size() >= 4, "several templates show up in week 1 (%s)" % str(templates.keys()))
	var w5 := Enc.build(db(), fresh(7), 5, "combat", seeded(9))
	check(w5["enemies"].size() >= 5, "week 5 fights are bigger (%d)" % w5["enemies"].size())


func test_elite_rooms() -> void:
	var e := Enc.build(db(), fresh(), 2, "elite", seeded(3))
	check(e["template"] == "elite_escort", "elite rooms use the elite escort template")
	check(e["affixes"].has(0) and e["affixes"][0].size() >= 1, "the elite gets 1 or 2 affixes")
	check(e["enemies"].size() >= 4, "with an escort")


func test_roles() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	check(Enc.roles_of(idx["dust_gremlin"]) == ["minion"], "minions")
	check(Enc.roles_of(idx["nurse_moth"]).has("healer") and not Enc.roles_of(idx["nurse_moth"]).has("fighter"), "healers")
	check(Enc.roles_of(idx["riot_shield"]).has("front"), "shield bearers hold the front")
	check(Enc.roles_of(idx["bell_tower_eye"]).has("ranged"), "snipers are ranged")
	check(Enc.roles_of(idx["hall_rusher"]).has("fast"), "chargers are fast")


func test_generated_floor_uses_templates() -> void:
	var f := Gen.generate(db(), fresh(), 1, "tue")
	var fights := 0
	for r in f["rooms"]:
		if str(r["type"]) in ["combat", "elite"]:
			fights += 1
			check(str(r.get("template", "")) != "", "room %d has a template" % int(r["id"]))
	check(fights > 0, "the floor has fights")


func test_party_scaling_keeps_roles() -> void:
	var room := { "id": 1, "type": "combat", "enemies": ["nurse_moth", "hall_rusher", "dust_gremlin", "dust_gremlin"], "roles": ["healer", "fighter", "minion", "minion"], "scale": 1.0 }
	var fs := Night.fight_setup(db(), room, 1)
	check(fs["enemies"].size() == 3 and fs["roles"] == ["healer", "fighter", "minion"], "solo: 0.75 of them, roles kept")
	check(is_equal_approx(float(fs["enemies"][0]["scale"]), 0.85), "solo enemies are at 85% power")


func _hero() -> Dictionary:
	return Char.create(db(), "mage", seeded(1), { "isPlayer": true })


func test_formations() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var lay := { "map": ["<P........E", "<P........E", "<P........E", "<P........E", "<P........E", "<P........E"] }
	var foes: Array = []
	for id in ["hall_rusher", "hall_rusher", "dust_gremlin", "dust_gremlin"]:
		foes.append(idx[id].duplicate(true))
	var amb := StateScript.new(db(), seeded(2), { "layout": lay, "party": [{ "char": _hero() }], "enemies": foes, "formation": "ambush" })
	var left := 0
	var right := 0
	for u in amb.units:
		if u.team == "enemy":
			if u.cell.x < amb.grid.cols / 2:
				left += 1
			else:
				right += 1
		elif u.is_player:
			check(u.cell.x >= 3 and u.cell.x <= 7, "ambush: the party starts in the middle (%s)" % str(u.cell))
	check(left > 0 and right > 0, "ambush: enemies on both sides (%d, %d)" % [left, right])
	var fb := StateScript.new(db(), seeded(2), { "layout": lay, "party": [{ "char": _hero() }],
		"enemies": [idx["bell_tower_eye"].duplicate(true), idx["riot_shield"].duplicate(true)], "roles": ["ranged", "front"], "formation": "front_back" })
	var sniper = null
	var shield = null
	for u in fb.units:
		if u.role == "ranged":
			sniper = u
		elif u.role == "front":
			shield = u
	check(shield.cell.x < sniper.cell.x, "front_back: the shield bearer stands in front of the sniper")


func test_reinforcements() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var st := StateScript.new(db(), seeded(2), { "layout": { "map": ["P........", ".........", "........."] }, "party": [{ "char": _hero() }],
		"enemies": [idx["hall_rusher"].duplicate(true)], "reinforcements": { "round": 3, "enemies": [idx["dust_gremlin"].duplicate(true), idx["dust_gremlin"].duplicate(true)] } })
	var count := func() -> int: return st.units.filter(func(u) -> bool: return u.team == "enemy" and u.alive()).size()
	var guard := 0
	while st.round_num < 2 and guard < 50:
		st.end_turn()
		guard += 1
	check(not st.support_cells().is_empty(), "the round before, their spawn tiles are telegraphed")
	while st.round_num < 3 and guard < 100:
		st.end_turn()
		guard += 1
	check(count.call() == 3, "on round 3 the second group arrives (%d)" % count.call())


func test_boss_adds() -> void:
	var f := Gen.generate(db(), fresh(), 3, "fri")
	var boss: Dictionary = {}
	for r in f["rooms"]:
		if str(r["type"]) == "boss":
			boss = r
	check(not boss.get("reinforcements", {}).is_empty(), "week 3 bosses get a reinforcement wave")
	for e in db()["enemies/bosses"]["enemies"]:
		for i in [1, 2]:
			check(not e["phases"][i].get("summon", []).is_empty(), "%s phase %d brings adds" % [e["id"], i + 1])


func test_swarm_scatters() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var st := StateScript.new(db(), seeded(2), { "layout": { "map": ["P........", ".........", "........."] }, "party": [{ "char": _hero() }],
		"enemies": [idx["hall_rusher"].duplicate(true), idx["dust_gremlin"].duplicate(true)], "roles": ["leader", "minion"] })
	var leader = null
	var minion = null
	for u in st.units:
		if u.role == "leader":
			leader = u
		elif u.role == "minion":
			minion = u
	st._damage(leader, 999, null, "", "hit")
	check(int(minion.disposition.get("courage", 0)) < 0, "killing the leader scatters the swarm")


func test_enemies_avoid_each_others_telegraphs() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var st := StateScript.new(db(), seeded(2), { "layout": { "map": ["P........", ".........", "........."] }, "party": [{ "char": _hero() }],
		"enemies": [idx["hall_rusher"].duplicate(true), idx["hall_rusher"].duplicate(true)], "turnMode": "move_and_act" })
	var a = null
	var b = null
	for u in st.units:
		if u.team == "enemy":
			if a == null:
				a = u
			else:
				b = u
	a.intent = { "kind": "attack", "action": a.actions[1], "move": a.cell, "target": Vector2i(4, 1), "cells": [Vector2i(4, 1), Vector2i(4, 2)], "mode": "locked", "charge": 0 }
	b.move_left = b.movement
	for o in AI.options(st, b):
		if o["move"] in [Vector2i(4, 1), Vector2i(4, 2)] and str(o["kind"]) == "move":
			check(false, "an enemy won't plan to stand in another enemy's telegraph")
	check(true, "options checked")

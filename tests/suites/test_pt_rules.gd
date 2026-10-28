## PT Part 4 rules fixes: Afterimage decoys, Taunt re-planning, Blind keeping
## telegraphs, push skip and move rules, Blink as a Quick, hazard kills,
## tracking damage, Lunge over hazards, wall climb and break, high crits.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")
const Res := preload("res://src/core/combat/resolver.gd")


func enemy(id: String) -> Dictionary:
	return DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)


func hero() -> Dictionary:
	return Char.create(db(), "rogue", seeded(1), { "knownVectors": ["force", "heat"], "isPlayer": true,
		"stats": { "str": 8, "dex": 30, "con": 8, "int": 7, "per": 30, "wil": 6, "cha": 4 } })


func fight(map: Array, enemies: Array) -> StateScript:
	return StateScript.new(db(), seeded(5), { "layout": { "map": map }, "party": [{ "char": hero() }], "enemies": enemies })


func me(st: StateScript):
	for u in st.units:
		if u.is_player:
			return u
	return null


func foe(st: StateScript):
	for u in st.units:
		if u.team == "enemy":
			return u
	return null


func test_afterimage_takes_tracking_hit() -> void:
	var st := fight(["P........", "........E"], [enemy("frost_wolf")])
	var p = me(st)
	var e = foe(st)
	var d := UnitScript.make_prop("decoy", 5, 2)
	d.cell = Vector2i(0, 1)
	st._add_unit(d)
	p.links["decoy"] = d.id
	st.current = e
	e.intent = { "kind": "attack", "action": e.actions[0], "move": e.cell, "target": p.cell, "cells": [p.cell], "mode": "tracking", "unit": p.id, "charge": 0 }
	var hp: int = p.hp
	st.execute_intent(e)
	check(p.hp == hp and (d.dead or d.hp < 5), "the decoy takes the tracking attack")


func test_tracking_damage() -> void:
	var st := fight(["P.E......"], [enemy("frost_wolf")])
	var e = foe(st)
	var act: Dictionary = e.actions[0].duplicate()
	act["intent"] = "locked"
	var locked := float(st.action_spec(e, act).get("power", 0)) + float(st.action_spec(e, act).get("base", 0))
	act["intent"] = "tracking"
	var tracking := float(st.action_spec(e, act).get("power", 0)) + float(st.action_spec(e, act).get("base", 0))
	check_near(tracking, locked * 0.6, "tracking attacks deal 60% of a locked attack")


func test_taunt_replans() -> void:
	var st := fight(["P........", ".........", "....E...."], [enemy("pom_pom_wisp")])
	var p = me(st)
	var e = foe(st)
	var ally := Char.create(db(), "fighter", seeded(2), { "id": "brick" })
	var st2 := StateScript.new(db(), seeded(5), { "layout": { "map": ["P.......P", ".........", "....E...."] },
		"party": [{ "char": hero() }, { "char": ally }], "enemies": [enemy("pom_pom_wisp")] })
	var brick = st2.unit_by_id("brick")
	var w = foe(st2)
	st2.taunt_replan(brick, 6)
	check(str(w.links.get("taunted_by", "")) == "brick", "enemies in range are taunted")
	if not w.intent.is_empty() and str(w.intent.get("kind", "")) == "attack":
		check(w.intent.get("target", Vector2i(-1, -1)) == brick.cell or str(w.intent.get("unit", "")) == "brick", "and re-plan at the taunter")
	check(p != null and e != null, "setup")


func test_blind_keeps_telegraphs() -> void:
	var st := fight(["P.E......"], [enemy("pom_pom_wisp")])
	var e = foe(st)
	e.intent = { "kind": "attack", "action": e.actions[0], "move": e.cell, "target": me(st).cell, "cells": [me(st).cell], "mode": "locked", "charge": 0 }
	e.statuses["blind"] = 1
	st._interrupt(e, "blind")
	check(not e.intent.is_empty(), "Blind never removes a telegraph")
	e.intent["charge"] = 1
	st._interrupt(e, "blind")
	check(not e.intent.is_empty(), "not even a charge-up (Light cancels those)")


func test_push_rules() -> void:
	var st := fight(["P........", "....E...."], [enemy("pom_pom_wisp")])
	var e = foe(st)
	var aura := { "name": "Glow", "form": "aura", "magnitude": "standard", "vectors": { "light": 1.0 }, "damage": 4 }
	e.intent = { "kind": "attack", "action": aura, "move": e.cell, "target": e.cell, "cells": [e.cell + Vector2i(1, 0), e.cell + Vector2i(-1, 0)], "mode": "locked", "charge": 0 }
	e.cell += Vector2i(1, 0)
	st._shift_intent(e, Vector2i(1, 0))
	check(e.intent["cells"].has(Vector2i(6, 1)) and e.intent["move"] == e.cell, "self-centered areas move with a pushed enemy")
	var st2 := fight(["P........", ".E......."], [enemy("detention_slip")])
	var s = foe(st2)
	var strike := { "name": "Bop", "kind": "strike", "damage": 5 }
	s.intent = { "kind": "attack", "action": strike, "move": s.cell, "target": Vector2i(0, 1), "cells": [Vector2i(0, 1)], "mode": "locked", "charge": 0 }
	s.cell = Vector2i(5, 1)
	st2._shift_intent(s, Vector2i(4, 0))
	check(s.intent.is_empty(), "an aimed attack out of reach after a push is skipped (off balance)")


func test_blink_is_quick_and_hazards_kill() -> void:
	var blink := CardRules.resolve(db(), "card_blink")
	check(bool(blink.get("quick", false)) and str(blink.get("text", "")).begins_with("Quick"), "Blink is a Quick")
	var st := fight(["P.......E"], [enemy("pom_pom_wisp")])
	var p = me(st)
	p.hp = 2
	st._damage(p, 5, null, "heat", "burn")
	check(p.hp <= 0 or p.downed or st.result == "lose", "burning can finish you outside the tutorial")


func test_lunge_over_hazards() -> void:
	var st := fight(["PpE......"], [enemy("pom_pom_wisp")])
	var p = me(st)
	var e = foe(st)
	e.cell = Vector2i(3, 0)
	e.hp = 999
	p.deck.hand = ["card_lunge"]
	p.mp = 10
	check(st.play_card(p, 0, e.cell) and p.cell == Vector2i(2, 0), "Lunge jumps the gap and lands next to the target")


func test_walls_break_and_climb() -> void:
	var st := fight(["P#.......", ".c......E", "........."], [enemy("pom_pom_wisp")])
	var p = me(st)
	check(st.grid.wall_hp.has(Vector2i(1, 0)), "'#' walls have HP")
	check(st.adjacent_walls(p).has(Vector2i(1, 0)), "Strike can reach the wall")
	st.damage_wall(Vector2i(1, 0), 13, "force")
	check(st.grid.get_terrain(Vector2i(1, 0)) == GridScript.RUBBLE, "Force deals x2: the wall breaks into rubble")
	check(st.cover_piece(Vector2i(4, 0), Vector2i(0, 0)) != null, "rubble gives half cover")
	p.cell = Vector2i(0, 1)
	check(st.climb_targets(p).has(Vector2i(2, 1)), "climb over the low wall into the tile beyond")
	var acts: int = p.actions_left
	check(st.climb(p, Vector2i(2, 1)) and p.cell == Vector2i(2, 1) and p.actions_left == acts - 1, "climbing costs 1 Action")
	var boundary := fight(["PB.......", "........E"], [enemy("pom_pom_wisp")])
	check(not boundary.grid.wall_hp.has(Vector2i(1, 0)), "the boundary can't be broken")


func test_high_crits() -> void:
	var u := UnitScript.new()
	u.crit_pct = 0.0
	u.high_crit_pct = 100.0
	var r := Res.finalize(db(), 10.0, u, seeded(1))
	check(bool(r["high"]) and int(r["amount"]) == 20, "a high crit is x2.0")
	u.high_crit_pct = 0.0
	u.crit_pct = 100.0
	r = Res.finalize(db(), 10.0, u, seeded(1))
	check(bool(r["crit"]) and not bool(r["high"]) and int(r["amount"]) == 15, "a crit is x1.5")
	var d := Char.derived(db(), hero())
	check(float(d["highCritChancePct"]) > 1.0, "high crit chance grows with DEX (%.1f%%)" % float(d["highCritChancePct"]))

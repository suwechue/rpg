## PT Parts 1 and 2 (adopted inside CT): 2 Actions + 1 Quick, Strike and Guard
## as Quicks, the Cantrip, Hold and the end-of-turn discard, undo, party-first
## arena rounds, opportunity strikes, enemy double attacks; plus CT Parts 5 to 7
## (role cards, sealed exit, tutorial floor) and the card text audit (CT Part 4).
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const Night := preload("res://src/core/dungeon/night.gd")
const Tutorial := preload("res://src/core/story/tutorial.gd")
const Crafting := preload("res://src/core/progression/crafting.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Str := preload("res://src/core/strings.gd")


func enemy(id: String) -> Dictionary:
	return DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)


func hero(cls: String = "mage") -> Dictionary:
	return Char.create(db(), cls, seeded(1), { "knownVectors": ["heat", "force"], "isPlayer": true,
		"stats": { "str": 6, "dex": 30, "con": 6, "int": 7, "per": 30, "wil": 6, "cha": 4 } })


func fight(map: Array, enemies: Array, extra: Dictionary = {}) -> StateScript:
	var setup := { "layout": { "map": map }, "party": [{ "char": hero() }], "enemies": enemies }
	setup.merge(extra, true)
	return StateScript.new(db(), seeded(5), setup)


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


func test_two_actions_and_quicks() -> void:
	# The PT Part 1 rule (Strike and Guard as Quicks) is a data option now.
	db()["combat_rules"]["builtinsQuick"] = true
	var st := fight(["P.......E", "........."], [enemy("pom_pom_wisp")])
	var p = me(st)
	foe(st).hp = 999
	check(st.uses_actions(p) and p.actions_left == 2, "a party turn has 2 Actions")
	check(st.move(p, Vector2i(2, 0)) and p.actions_left == 1, "a Move spends 1 Action")
	check(st.can_move(p) and st.move(p, Vector2i(4, 0)) and p.actions_left == 0, "move + move is allowed")
	check(not st.can_move(p) and st.act_block(p) != "", "with no Actions left, nothing but a Quick")
	foe(st).cell = Vector2i(5, 0)
	check(st.quick_block(p) == "" and st.strike(p, Vector2i(5, 0)), "Strike is a Quick, usable after moving twice")
	check(p.quick_used and st.quick_block(p) != "", "one Quick per turn")
	check(not st.guard(p), "Guard is the same Quick")
	var st2 := fight(["PE.......", "........."], [enemy("pom_pom_wisp")])
	var p2 = me(st2)
	foe(st2).hp = 999
	check(st2.guard(p2) and p2.actions_left == 2, "Guard doesn't spend an Action")
	p2.deck.hand = ["card_heavy_swing", "card_heavy_swing", "card_heavy_swing"]
	p2.mp = 10
	check(st2.play_card(p2, 0, foe(st2).cell) and st2.play_card(p2, 0, foe(st2).cell) and p2.actions_left == 0, "card + card is allowed")
	db()["combat_rules"]["builtinsQuick"] = false


func test_cantrip() -> void:
	var st := fight(["P...E....", "........."], [enemy("pom_pom_wisp")])
	var p = me(st)
	var e = foe(st)
	e.hp = 999
	var spec := st.cantrip_spec(p)
	check(not spec.is_empty() and spec["vectors"].has("heat"), "the Cantrip is in the first Vector known")
	check(st.cantrip_targets(p).has(e.cell), "single target at range")
	var mp: int = p.mp
	check(st.cast_cantrip(p, e.cell) and p.mp == mp and p.actions_left == 1 and e.hp < 999, "0 MP, 1 Action, it hurts")


func test_hold_and_end_turn_discard() -> void:
	var st := fight(["P.......E", "........."], [enemy("pom_pom_wisp")])
	var p = me(st)
	p.deck.hand = ["card_dash", "card_blink", "card_shove"]
	check(st.hold_card(p, 1) and p.held_id == "card_blink" and p.actions_left == 1, "Hold costs 1 Action")
	check(st.hold_block(p) != "", "only 1 card can be held")
	var before: int = p.deck.discard.size()
	st._discard_hand(p)
	check(p.deck.hand == ["card_blink"] and p.deck.discard.size() == before + 2, "End Turn discards everything but the held card")


func test_undo_until_a_roll() -> void:
	var st := fight(["P.......E", "........."], [enemy("pom_pom_wisp")])
	var p = me(st)
	var start: Vector2i = p.cell
	check(st.move(p, Vector2i(2, 0)) and st.can_undo(p), "a move can be undone")
	check(st.undo(p) and p.cell == start and p.actions_left == 2, "undo puts the unit and its Actions back")
	foe(st).cell = Vector2i(1, 0)
	foe(st).hp = 999
	check(st.strike(p, Vector2i(1, 0)), "Strike")
	check(not st.can_undo(p) and st.undo_reason(p) != "", "a crit roll locks the turn (%s)" % st.undo_reason(p))


func test_arena_party_first() -> void:
	var st := fight(["P.......E", "........."], [enemy("detention_slip")], { "partyFirst": true })
	check(st.order[0].team == "party", "arena round 1: the party acts first")
	var fast := enemy("detention_slip")
	fast["initiative"] = 99
	var st2 := fight(["P.......E", "........."], [fast])
	check(st2.order[0].team == "enemy", "otherwise initiative decides")


func test_opportunity_strike_and_double_attack() -> void:
	var st := fight(["..P......", "....E...."], [enemy("pom_pom_wisp")])
	var p = me(st)
	var e = foe(st)
	e.hp = 999
	st.current = e
	e.move_left = e.movement
	e.intent = { "kind": "attack", "action": { "kind": "strike", "name": "Bop", "damage": 4 }, "move": p.cell, "target": p.cell + Vector2i(-1, 0), "cells": [p.cell + Vector2i(-1, 0)], "mode": "locked", "charge": 0 }
	check(st.blocking(p).has(e), "standing on its planned tile blocks its path")
	st.execute_intent(e)
	check(e.hp < 999, "the blocker gets an opportunity strike")
	var st2 := fight(["PE.......", "........."], [enemy("pom_pom_wisp")])
	var w = foe(st2)
	w.double_attack = true
	var it := AI.plan_intent(st2, w)
	if str(it.get("kind", "")) == "attack" and it["move"] == w.cell:
		check(int(it.get("repeat", 1)) == 2, "an enemy already in reach can attack twice")
	var far := fight(["P.........", ".........E"], [enemy("hall_rusher")])
	var r = foe(far)
	r.double_attack = false
	var mv := AI.plan_intent(far, r)
	if str(mv.get("kind", "")) == "move":
		check(bool(mv.get("double_move", false)), "nothing in reach: move + move")


func test_role_cards() -> void:
	var st := fight(["P.E......", ".........", "........."], [enemy("pom_pom_wisp")])
	var p = me(st)
	var e = foe(st)
	e.hp = 999
	e.cell = Vector2i(1, 0)
	p.deck.hand = ["card_hit_and_run", "card_intercept", "card_ward"]
	p.mp = 10
	check(st.play_card(p, 0, e.cell) and e.hp < 999 and p.statuses.has("free_move"), "Hit and Run strikes, then gives a free move")
	var actions: int = p.actions_left
	check(st.move(p, Vector2i(0, 2)) and p.actions_left == actions, "the free move costs no Action")
	var ally := Char.create(db(), "fighter", seeded(2), { "id": "brick" })
	var st2 := StateScript.new(db(), seeded(5), { "layout": { "map": ["PP.....E.", "........."] }, "party": [{ "char": hero() }, { "char": ally }], "enemies": [enemy("pom_pom_wisp")] })
	var a: UnitScript = st2.units[0]
	var b: UnitScript = st2.units[1]
	b.statuses["intercept"] = 2
	check(st2._interceptor(a) == b, "Intercept: an adjacent ally takes the hit")
	a.statuses["sanctuary"] = 2
	check(float(st2._sanctuary_spec({ "areaMul": 1.0 }, a)["areaMul"]) == 0.5, "Sanctuary halves telegraphed hits")


func test_sealed_exit() -> void:
	var f := { "rooms": [{ "type": "start", "cleared": true }, { "type": "combat", "cleared": false }, { "type": "elite", "cleared": true },
		{ "type": "treasure", "cleared": false }, { "type": "exit", "cleared": true }] }
	check(Night.fights_left(f) == 1, "treasure is optional; one fight left keeps the exit sealed")
	f["rooms"][1]["cleared"] = true
	check(Night.fights_left(f) == 0, "every fight won: the exit opens")


func test_tutorial_floor() -> void:
	var rooms := Tutorial.rooms(db())
	check(rooms.size() == 10, "10 tutorial rooms")
	check(Tutorial.route(db(), {}).size() == 10 and not Tutorial.route(db(), { "w1_shortcut": true }).has(7), "the shortcut skips room 7")
	check(not bool(Tutorial.ui_open(db(), 3)["hand"]) and bool(Tutorial.ui_open(db(), 4)["hand"]), "the hand unlocks in room 4")
	check(not bool(Tutorial.ui_open(db(), 8)["wheel"]) and bool(Tutorial.ui_open(db(), 9)["wheel"]), "the Vector Wheel unlocks in room 9")
	check(not bool(Tutorial.ui_open(db(), 9)["threat"]) and bool(Tutorial.ui_open(db(), 10)["threat"]), "the threat view unlocks in room 10")
	var player := hero()
	for r in rooms:
		var opts := Tutorial.setup_opts(db(), int(r["id"]), player, {})
		check(not opts["enemies"].is_empty(), "room %d has enemies to win against" % int(r["id"]))
		check(not DT.record(db(), "rooms/combat_layouts", str(opts["layout"])).is_empty(), "room %d layout exists" % int(r["id"]))
		for s in opts["lesson"]:
			check(Tutorial.WAITS.has(str(s.get("wait", "next"))), "room %d: known wait %s" % [int(r["id"]), s.get("wait", "")])
			check(Str.t(db(), str(s["say"])) != str(s["say"]), "room %d: line %s is in strings.json" % [int(r["id"]), s["say"]])
	var r5 := Tutorial.setup_opts(db(), 5, player, {})
	check(r5["enemies"][0]["weakTo"] == ["heat"] and r5["enemies"][1]["strongAgainst"] == ["heat"], "room 5: weak and strong to your spark")
	check(bool(Tutorial.setup_opts(db(), 9, player, {})["guaranteeImprovise"]), "room 9: the first improvise always works")
	check(Tutorial.setup_opts(db(), 10, player, { "w1_shortcut": true })["lesson"].size() > Tutorial.setup_opts(db(), 10, player, {})["lesson"].size(), "after the shortcut, room 10 adds the push hint")
	check(Tutorial.setup_opts(db(), 1, player, {}, false)["lesson"].is_empty(), "skip the lessons: fights stay, prompts go")
	var l := Tutorial.Lesson.new([{ "say": "a", "wait": "next" }, { "say": "b", "wait": "moved", "hint": "h" }, { "say": "c", "wait": "struck" }])
	check(l.notify("next") and not l.notify("struck") and l.notify("dodged") and l.notify("struck") and l.done(), "lesson steps wait for their events")
	var l2 := Tutorial.Lesson.new([{ "say": "b", "wait": "moved", "hint": "h" }])
	check(not l2.tick(5.0, 20.0) and l2.tick(16.0, 20.0), "a hint after 20 seconds stuck")
	var st := StateScript.new(db(), seeded(5), { "layout": DT.record(db(), "rooms/combat_layouts", "tut_r1"), "party": [{ "char": player }],
		"enemies": Tutorial.setup_opts(db(), 1, player, {})["enemies"], "hpFloor": true, "fair": true })
	var p = me(st)
	st._damage(p, 999, null, "", "hit")
	check(p.hp == 1 and p.crit_pct == 0.0, "training floor: hits can't drop you, and no crits yet")


func test_deck_rules() -> void:
	var rng := seeded(1)
	var run := RM.new_run(db(), 1, "mage", rng)
	var p: Dictionary = run["player"]
	var big: Array = p["deck"].duplicate()
	for i in 40:
		big.append(p["deck"][i % p["deck"].size()])
		run["collection"][str(p["deck"][i % p["deck"].size()])] = 99
	var cap := int(db()["leveling"]["maxCopies"])
	check(Char.deck_max(db(), p) == 0, "no maximum deck size (PT Part 2)")
	check(Crafting.removals(["a", "b", "b"], ["b", "c"]) == 2, "removed cards are counted (they cost AP)")
	check(Crafting.copies_ok(db(), ["x", "x"], "x") == (cap <= 0 or cap > 2), "copy limit from data")
	var ch := { "deck": ["card_dash"] }
	check(Crafting.add_to_deck(db(), ch, "card_blink") and ch["deck"].has("card_blink"), "crafted cards go straight into the deck")


## CT Part 4 card text audit: every card says when it applies.
func test_card_text_audit() -> void:
	for key in ["cards/vector_cards", "cards/basic_cards", "cards/tier3_cards", "cards/class_cards", "cards/starter_cards"]:
		for c in db()[key]["cards"]:
			var text := str(c.get("text", ""))
			check(text != "", "%s has text" % c["id"])
			if bool(c.get("quick", false)):
				check(text.begins_with("Quick"), "%s is quick and its text says so" % c["id"])
			var moves := str(c.get("action", "")) == "dash"
			for e in c.get("effects", []):
				moves = moves or str(e.get("op", "")) in ["dash", "tailwind"]
			if moves:
				check(text.contains("next turn"), "%s: movement cards say they carry over to next turn" % c["id"])
			if bool(c.get("oncePerFight", false)):
				check(text.to_lower().contains("once per fight"), "%s says once per fight" % c["id"])
			var short := str(c.get("short", ""))
			if c.get("kind", "") == "spell" and not bool(c.get("effectsOnly", false)):
				check(not short.contains("{") or short.contains("{power}"), "%s short line uses {power}" % c["id"])

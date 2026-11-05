## Combat Lab Part 2: the new core rules behind their levers (docs/COMBAT_LAB.md).
extends "res://tests/suite.gd"

const StateScript := preload("res://src/core/combat/combat_state.gd")
const RM := preload("res://src/core/run/run_model.gd")
const DTX := preload("res://src/core/data_tables.gd")
const Goals := preload("res://src/core/combat/fight_goals.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")


func _ch() -> Dictionary:
	var run := RM.new_run(db(), 3, "fighter", seeded(3))
	var ch: Dictionary = run["player"]
	ch["knownVectors"] = ["force", "heat", "cold"]
	return ch


func _enemy(id: String, over: Dictionary = {}) -> Dictionary:
	var rec: Dictionary = DTX.index_under(db(), "enemies/", "enemies")[id].duplicate(true)
	rec.merge(over, true)
	return rec


## A fight under cl_base (or another preset) on a small map.
func _fight(map: Array, enemies: Array, levers: Dictionary = {}, setup_more: Dictionary = {}, preset: String = "cl_base") -> Object:
	var setup := { "layout": { "map": map }, "party": [{ "char": _ch() }], "enemies": enemies, "preset": preset, "levers": levers, "difficulty": "normal", "ramp": 1.0 }
	setup.merge(setup_more, true)
	return StateScript.new(db(), seeded(5), setup)


func _foe(st: Object) -> Object:
	for u in st.units:
		if u.team == "enemy" and u.alive():
			return u
	return null


func _me(st: Object) -> Object:
	return st.unit_by_id("player")


## Hand this card to the acting unit and make it their turn.
func _ready_turn(st: Object, ids: Array = []) -> Object:
	var me: Object = _me(st)
	st.current = me
	me.action_used = false
	me.actions_left = st.actions_per_turn()
	me.quick_used = false
	me.quicks_taken = 0
	me.move_left = st.move_budget(me)
	me.moved_steps = 0
	me.mp = me.max_mp
	if not ids.is_empty():
		me.deck.hand = ids.duplicate()
	return me


func test_turn_is_one_move_and_one_action() -> void:
	var st := _fight(["P.....E"], [_enemy("dust_gremlin")])
	check(st.turn_mode == "move_and_act" and st.actions_per_turn() == 1, "cl_base is a Move and one Action")
	var me := _ready_turn(st, ["card_strike"])
	var foe := _foe(st)
	foe.cell = me.cell + Vector2i(3, 0)
	check(st.move(me, me.cell + Vector2i(1, 0)), "move part of the way")
	check(st.move(me, me.cell + Vector2i(1, 0)), "and a bit more")
	check(st.strike(me, foe.cell) or foe.dead, "Strike uses the Action")
	check(st.act_block(me) != "", "only one Action")
	check(me.move_left > 0 and st.can_move(me), "split move: keep moving after acting")


func test_split_move_lever_off() -> void:
	var st := _fight(["P.....E"], [_enemy("bleacher_creeper")], { "splitMove": false })
	var me := _ready_turn(st)
	var foe := _foe(st)
	foe.cell = me.cell + Vector2i(2, 0)
	st.move(me, me.cell + Vector2i(1, 0))
	st.strike(me, foe.cell)
	check(me.move_left == 0, "split move off: acting after moving ends the Move")


func test_move_separate_lever_off_uses_the_action() -> void:
	var st := _fight(["P.....E"], [_enemy("dust_gremlin")], { "moveSeparate": false, "actionsPerTurn": 2 })
	check(st.turn_mode == "two_actions" and st.uses_actions(_me(st)), "off: moving uses an Action, as today")


func test_quicks_per_turn_cap() -> void:
	var quick := { "id": "q", "name": "Q", "kind": "basic", "action": "effects", "cost": 0, "quick": true, "targeting": { "type": "self" }, "effects": [] }
	var lib := { "q": quick }
	var st := _fight(["P.....E"], [_enemy("dust_gremlin")], {}, { "library": lib })
	var me := _ready_turn(st, ["q", "q", "q"])
	check(st.play_card(me, 0, me.cell) and me.quick_used and not me.action_used, "a Quick doesn't use the Action")
	check(st.play_card(me, 0, me.cell) and me.action_used, "past the cap it costs the Action")
	var free := _fight(["P.....E"], [_enemy("dust_gremlin")], { "quicksPerTurn": 0 }, { "library": lib })
	var f := _ready_turn(free, ["q", "q", "q"])
	free.play_card(f, 0, f.cell)
	free.play_card(f, 0, f.cell)
	check(not f.quick_used and not f.action_used, "0 means no cap")


func test_keywords() -> void:
	var base := { "kind": "basic", "action": "effects", "cost": 0, "targeting": { "type": "self" }, "effects": [] }
	var lib := {}
	for k in ["free", "swift", "heavy", "exhaust"]:
		var c := base.duplicate()
		c["id"] = k
		c["name"] = k
		c[k] = true
		lib[k] = c
	var fu := base.duplicate()
	fu["id"] = "fu"
	fu["name"] = "fu"
	fu["followUp"] = "push"
	lib["fu"] = fu
	var pusher := base.duplicate()
	pusher["id"] = "pusher"
	pusher["name"] = "pusher"
	pusher["labels"] = ["push"]
	lib["pusher"] = pusher
	var st := _fight(["P.....E"], [_enemy("dust_gremlin")], {}, { "library": lib })
	var me := _ready_turn(st, ["free", "free"])
	st.play_card(me, 0, me.cell)
	check(not me.action_used and not me.quick_used, "Free uses neither the Action nor the Quick")
	me = _ready_turn(st, ["swift"])
	st.move(me, me.cell + Vector2i(2, 0))
	var left: int = me.move_left
	st.play_card(me, 0, me.cell)
	check(me.action_used and me.move_left > left and me.move_left == st.move_budget(me), "Swift gives your Move back")
	me = _ready_turn(st, ["heavy"])
	st.play_card(me, 0, me.cell)
	check(me.action_used and me.move_left == 0, "Heavy uses the Action and the Move")
	me = _ready_turn(st, ["heavy"])
	st.move(me, me.cell + Vector2i(1, 0))
	check(st.card_block(me, st.card_of(me, 0)) != "", "Heavy can't be played after moving")
	me = _ready_turn(st, ["fu", "pusher", "pusher"])
	st.play_card(me, 0, me.cell)
	check(me.action_used, "Follow-up uses the Action")
	check(st.card_block(me, st.card_of(me, 0)) == "" and st.play_card(me, 0, me.cell), "and opens one card with its tag")
	check(st.card_block(me, st.card_of(me, 0)) != "", "only one")
	me = _ready_turn(st, ["exhaust"])
	st.play_card(me, 0, me.cell)
	check(me.deck.exhausted.has("exhaust") and not me.deck.discard.has("exhaust"), "Exhaust leaves the fight")
	var off := _fight(["P.....E"], [_enemy("dust_gremlin")], { "keywordsOn": false, "exhaustOn": false }, { "library": lib })
	var o := _ready_turn(off, ["free", "exhaust"])
	off.play_card(o, 0, o.cell)
	check(o.action_used, "keywords off: Free is an ordinary card")
	o = _ready_turn(off, ["exhaust"])
	off.play_card(o, 0, o.cell)
	check(o.deck.discard.has("exhaust"), "Exhaust off: it goes to the discard")


func test_hand_and_deck_levers() -> void:
	var st := _fight(["P.....E"], [_enemy("dust_gremlin")])
	var me := _me(st)
	check(me.deck.hand_limit == 4, "the hand is 4")
	var ids: Array = []
	for i in 12:
		ids.append("card_strike")
	me.deck.draw_pile = ids.duplicate()
	me.deck.hand = ["card_strike"]
	st.current = me
	st._discard_hand(me)
	check(me.deck.hand.size() == 1, "leftover cards stay")
	st._start_turn(me)
	check(me.deck.hand.size() == 4, "drawn back up to the hand size")
	var two := _fight(["P.....E"], [_enemy("dust_gremlin")], { "keepHand": false })
	var t := _me(two)
	t.deck.hand = ["card_strike"]
	two._discard_hand(t)
	check(t.deck.hand.is_empty(), "keepHand off: the hand is discarded")
	var slow := _fight(["P.....E"], [_enemy("dust_gremlin")], { "drawPerTurn": "1" })
	var s := _me(slow)
	s.deck.hand = []
	s.deck.draw_pile = ids.duplicate()
	slow._start_turn(s)
	check(s.deck.hand.size() == 1, "drawPerTurn: a number draws that many")
	var dry := _fight(["P.....E"], [_enemy("dust_gremlin")])
	var d := _me(dry)
	d.deck.hand = []
	d.deck.draw_pile = []
	d.deck.discard = ids.duplicate()
	var hp: int = d.hp
	dry._start_turn(d)
	check(d.hp == hp and d.deck.hand.size() == 4, "the discard shuffles back, with no Fatigue")
	var never := _fight(["P.....E"], [_enemy("dust_gremlin")], { "reshuffle": "never" })
	var n := _me(never)
	n.deck.hand = []
	n.deck.draw_pile = []
	n.deck.discard = ids.duplicate()
	never._start_turn(n)
	check(n.deck.hand.is_empty(), "reshuffle never: the deck stays empty")


func test_mp_levers() -> void:
	var st := _fight(["P.....E"], [_enemy("dust_gremlin")])
	var me := _me(st)
	check(me.max_mp == 6 and me.mp_regen == 2, "a small pool that refills a little")
	var spell := { "id": "x", "kind": "spell", "vectors": { "heat": 1.0 }, "form": "bolt", "magnitude": "standard" }
	check(st.card_cost(me, spell) > 0, "cards cost MP")
	var free := _fight(["P.....E"], [_enemy("dust_gremlin")], { "cardsCostMp": false })
	check(free.card_cost(_me(free), spell) == 0, "the alternative: Standard is free")
	var big := spell.duplicate()
	big["magnitude"] = "major"
	check(free.card_cost(_me(free), big) > 0, "only Major and Grand cost MP")


func test_small_numbers_keep_everything_at_one_or_more() -> void:
	var index: Dictionary = DTX.index_under(db(), "enemies/", "enemies")
	for id in index:
		var st := _fight(["P...E"], [index[id].duplicate(true)])
		for u in st.units:
			if u.team == "enemy":
				check(u.max_hp >= 1 and u.hp >= 1, "%s has at least 1 HP" % id)
	var st := _fight(["P...E"], [_enemy("dust_gremlin")])
	var me := _me(st)
	var foe := _foe(st)
	check(me.max_hp >= 8 and me.max_hp <= 20, "party HP is small (%d)" % me.max_hp)
	check(foe.max_hp >= 1 and foe.max_hp <= 2, "minions have 1 to 2 HP (%d)" % foe.max_hp)
	var normal := _foe(_fight(["P...E"], [_enemy("pom_pom_wisp")]))
	check(normal.max_hp >= 3 and normal.max_hp <= 8, "normal enemies 3 to 8 HP (%d)" % normal.max_hp)
	var boss := _foe(_fight(["P...E"], [_enemy("hollow_mascot")]))
	check(boss.max_hp >= 15 and boss.max_hp <= 35, "bosses about 20 to 30 HP (%d)" % boss.max_hp)
	var tiny := { "name": "t", "vectors": { "heat": 1.0 }, "form": st.form_rec("bolt"), "power": 0.5, "mult": 1.0, "heal": false, "ranged": true, "kind": "spell" }
	var hit := _fight(["P...E"], [_enemy("bleacher_creeper")])
	var f2 := _foe(hit)
	var hp0: int = f2.hp
	hit._hit_unit(_me(hit), f2, tiny, false)
	check(hp0 - f2.hp >= 1, "every hit deals at least 1")
	var big := _fight(["P...E"], [_enemy("bleacher_creeper")], { "smallNumbers": false })
	check(_foe(big).max_hp > f2.max_hp, "small numbers off: the data's real values")


func test_no_dice() -> void:
	var st := _fight(["P.E.."], [_enemy("anvil_crab")])
	var me := _ready_turn(st)
	me.crit_pct = 100.0
	me.high_crit_pct = 100.0
	var foe := _foe(st)
	foe.cell = me.cell + Vector2i(1, 0)
	var before: int = st.rng.state
	var dmg: Dictionary = st._finalize(5.0, me)
	check(not bool(dmg["crit"]) and st.rng.state == before, "no crits and no dice rolled")
	me.statuses["blind"] = 2
	var hp0: int = foe.hp
	st.strike(me, foe.cell)
	check(foe.hp < hp0, "no misses, even blind")
	var dice := _fight(["P.E.."], [_enemy("anvil_crab")], { "crits": true })
	var dm := _me(dice)
	dm.crit_pct = 100.0
	check(bool(dice._finalize(5.0, dm)["crit"]), "the crits lever brings them back")


func test_no_difficulty_multiplier_and_no_hit_cap() -> void:
	var st := _fight(["P.E.."], [_enemy("pom_pom_wisp")])
	var cur := _fight(["P.E.."], [_enemy("pom_pom_wisp")], {}, {}, "current")
	var a: Dictionary = _enemy("pom_pom_wisp")["actions"][0]
	var strike_like := { "kind": "strike", "damage": 10 }
	check(st.action_spec(_foe(st), strike_like)["base"] == 10.0, "cl_base has no difficulty damage multiplier")
	check(cur.action_spec(_foe(cur), strike_like)["base"] > 10.0, "current does")
	check(st._hit_cap(_me(st)) > 1000, "and no hit cap")


func test_exact_telegraphs_at_the_start_of_the_party_turn() -> void:
	var st := _fight(["P.....E", ".......", "......E"], [_enemy("pom_pom_wisp"), _enemy("bleacher_creeper")])
	var me := _me(st)
	check(st.current == me, "the party goes first")
	for u in st.units:
		if u.team == "enemy":
			check(not u.intent.is_empty(), "%s telegraphed before you act" % u.name)


func test_redirect_and_surge() -> void:
	var st := _fight(["P.E.E.."], [_enemy("bleacher_creeper"), _enemy("bleacher_creeper")])
	var me := _ready_turn(st)
	var es: Array = st.units.filter(func(u: Object) -> bool: return u.team == "enemy")
	var a: Object = es[0]
	var b: Object = es[1]
	b.intent = { "kind": "attack", "mode": "locked", "action": { "kind": "strike", "damage": 10 }, "move": b.cell, "target": a.cell, "cells": [a.cell], "unit": me.id, "charge": 0 }
	st.current = b
	var hp0: int = a.hp
	st._resolve_locked(b, b.intent)
	check(a.hp < hp0, "an enemy on another enemy's tiles takes the hit")
	check(st.surge >= 1, "and that fills Surge")
	var off := _fight(["P.E.E.."], [_enemy("bleacher_creeper"), _enemy("bleacher_creeper")], { "redirect": false })
	var oes: Array = off.units.filter(func(u: Object) -> bool: return u.team == "enemy")
	var ob: Object = oes[1]
	var oa: Object = oes[0]
	var oh: int = oa.hp
	off._resolve_locked(ob, { "kind": "attack", "mode": "locked", "action": { "kind": "strike", "damage": 10 }, "move": ob.cell, "target": oa.cell, "cells": [oa.cell], "unit": "", "charge": 0 })
	check(oa.hp == oh, "lever off: it passes through")


func test_dodging_and_cancelling_fill_surge() -> void:
	var st := _fight(["P.E...."], [_enemy("bleacher_creeper")])
	var me := _ready_turn(st)
	var foe := _foe(st)
	st.current = foe
	st._resolve_locked(foe, { "kind": "attack", "mode": "locked", "action": { "kind": "strike", "damage": 10 }, "move": foe.cell, "target": Vector2i(6, 0), "cells": [Vector2i(6, 0)], "unit": me.id, "charge": 0 })
	check(st.surge == 1, "a telegraph aimed at you that missed fills Surge")
	st = _fight(["P.E...."], [_enemy("bleacher_creeper", { "hp": 500 })])
	me = _ready_turn(st)
	foe = _foe(st)
	foe.cell = me.cell + Vector2i(1, 0)
	foe.intent = { "kind": "attack", "mode": "locked", "action": { "kind": "strike", "damage": 10 }, "move": foe.cell, "target": me.cell, "cells": [me.cell], "unit": me.id, "charge": 0 }
	st.surge = 0
	st._push(me, foe, Vector2i(1, 0), 2)
	check(foe.intent.is_empty() and st.surge == 1, "pushing an attacker out of reach cancels it, and fills Surge")


func test_surge_spend() -> void:
	var st := _fight(["P.E...."], [_enemy("anvil_crab", { "hp": 500 })])
	var me := _ready_turn(st)
	check(not st.spend_surge(me), "not until it's full")
	for i in 9:
		st.add_surge("combo")
	check(st.surge == 5, "it stops at its size")
	check(st.can_surge(me) and st.spend_surge(me) and st.surge == 0, "spend it")
	var card := { "id": "boom", "name": "Boom", "kind": "spell", "vectors": { "heat": 1.0 }, "form": "bolt", "magnitude": "minor" }
	st.library["boom"] = card
	me.deck.hand = ["boom"]
	me.mp = 0
	var foe := _foe(st)
	foe.cell = me.cell + Vector2i(2, 0)
	check(st.card_cost(me, card) == 0 and st.card_block(me, card) == "", "the next card is free")
	var hp0: int = foe.hp
	check(st.play_card(me, 0, foe.cell), "and plays")
	check(not me.action_used and foe.hp < hp0, "it took no Action")
	check(not me.links.has("surged"), "only one card")
	check(str(st._surge_card(card)["magnitude"]) == "standard", "one Magnitude higher")
	var off := _fight(["P.E"], [_enemy("anvil_crab")], { "surge": false })
	off.add_surge("combo")
	check(off.surge == 0, "the lever turns it off")


func test_kill_refund() -> void:
	var st := _fight(["P.E...."], [_enemy("dust_gremlin", { "hp": 1 })])
	st.goal = {}
	var me := _ready_turn(st)
	var extra := _fight(["P.E...E"], [_enemy("dust_gremlin", { "hp": 1 }), _enemy("bleacher_creeper")])
	me = _ready_turn(extra)
	var foe := _foe(extra)
	foe.cell = me.cell + Vector2i(1, 0)
	me.move_left = 0
	extra.strike(me, foe.cell)
	check(foe.dead and me.move_left == extra.move_budget(me), "a kill gives back your Move")
	var act := _fight(["P.E...E"], [_enemy("dust_gremlin", { "hp": 1 }), _enemy("bleacher_creeper")], { "killRefund": "action" })
	me = _ready_turn(act)
	foe = _foe(act)
	foe.cell = me.cell + Vector2i(1, 0)
	act.strike(me, foe.cell)
	check(act.act_block(me) == "", "as a lever: your Action")
	var none := _fight(["P.E...E"], [_enemy("dust_gremlin", { "hp": 1 }), _enemy("bleacher_creeper")], { "killRefund": "off" })
	me = _ready_turn(none)
	foe = _foe(none)
	foe.cell = me.cell + Vector2i(1, 0)
	me.move_left = 0
	none.strike(me, foe.cell)
	check(me.move_left == 0, "off: nothing")


func test_combo_chain() -> void:
	var st := _fight(["P.E"], [_enemy("anvil_crab", { "hp": 500 })])
	var me := _me(st)
	var foe := _foe(st)
	check(st._chain_bonus(me, foe) == 0, "nothing at first")
	st.chain[foe.id] = ["ally_a"]
	check(st._chain_bonus(me, foe) == 1, "a teammate's card adds 1")
	st.chain[foe.id] = ["ally_a", "ally_b", me.id]
	check(st._chain_bonus(me, foe) == 2, "each different teammate, not you")
	var hit1 := int(st._final_number(5.0, me, foe))
	st.chain.clear()
	check(hit1 > int(st._final_number(5.0, me, foe)), "it adds to the damage")
	st._note_chain(me, foe)
	check(st.chain[foe.id] == [me.id], "playing on an enemy joins the chain")
	st._end_round()
	check(st.chain.is_empty(), "it resets each round")
	var off := _fight(["P.E"], [_enemy("anvil_crab")], { "comboChain": false })
	off.chain["x"] = ["a"]
	check(off._chain_bonus(_me(off), _foe(off)) == 0, "the lever turns it off")


func test_round_cap_shift() -> void:
	var st := _fight(["P.E"], [_enemy("anvil_crab")], { "roundCap": 2 })
	var foe := _foe(st)
	var me := _me(st)
	var base := int(st._final_number(5.0, foe, me))
	st.round_num = 2
	st._end_round()
	check(st.shift_bonus == 1, "past the cap, the Upside-Down shifts")
	check(int(st._final_number(5.0, foe, me)) == base + 1, "enemies hit for 1 more")
	st._end_round()
	check(st.shift_bonus == 2, "and 1 more each round")
	var cur := _fight(["P.E"], [_enemy("anvil_crab")], {}, {}, "current")
	cur.round_num = 50
	cur._end_round()
	check(cur.shift_bonus == 0, "current has no cap")


func test_hit_hard_rarely() -> void:
	var st := _fight(["P.....E"], [_enemy("bleacher_creeper")], { "hitHardRarely": true })
	var foe := _foe(st)
	foe.turns_taken = 1
	check(str(AI.plan_intent(st, foe).get("kind", "")) == "wait", "every other turn is quiet")
	foe.turns_taken = 2
	check(str(AI.plan_intent(st, foe).get("kind", "")) != "wait", "and then it acts")
	check(st.action_spec(foe, { "kind": "strike", "damage": 10 })["base"] == 20.0, "with a bigger hit")


func test_path_blocking() -> void:
	var st := _fight(["P...E..", "....E.."], [_enemy("pom_pom_wisp"), _enemy("bleacher_creeper")])
	var es: Array = st.units.filter(func(u: Object) -> bool: return u.team == "enemy")
	var shooter: Object = es[0]
	var other: Object = es[1]
	var me := _me(st)
	shooter.cell = Vector2i(5, 0)
	me.cell = Vector2i(0, 0)
	other.cell = Vector2i(3, 0)
	var it := { "kind": "attack", "mode": "locked", "action": { "form": "bolt", "vectors": { "heat": 1.0 }, "power": 5 }, "move": shooter.cell, "target": me.cell, "cells": [me.cell], "unit": me.id, "charge": 0 }
	check(st.blocked_cells(shooter, it) == [other.cell], "a shot stops at the enemy in its path")
	var off := _fight(["P...E..", "....E.."], [_enemy("pom_pom_wisp"), _enemy("bleacher_creeper")], { "pathBlocking": false })
	check(off.blocked_cells(shooter, it) == [me.cell], "lever off: the telegraph stays")


func test_blind_moves_the_telegraph() -> void:
	var st := _fight(["P.....E", "......."], [_enemy("bleacher_creeper")])
	var foe := _foe(st)
	var me := _me(st)
	foe.intent = { "kind": "attack", "mode": "locked", "action": { "kind": "strike", "damage": 5 }, "move": foe.cell, "target": me.cell, "cells": [me.cell], "unit": me.id, "charge": 0 }
	st.blind_shift(foe)
	var c: Vector2i = foe.intent["cells"][0]
	check(c != me.cell and (c - me.cell).length_squared() == 1, "Blind: the tile next to its target")
	var before: Array = foe.intent["cells"].duplicate()
	st.blind_shift(foe)
	check(foe.intent["cells"] == before, "only once")
	var old := _fight(["P.....E"], [_enemy("bleacher_creeper")], { "blindMode": "miss_chance" })
	var ofoe := _foe(old)
	ofoe.intent = { "kind": "attack", "action": {}, "cells": [Vector2i(0, 0)] }
	old.blind_shift(ofoe)
	check(ofoe.intent["cells"] == [Vector2i(0, 0)], "the old rule leaves it")


func test_undo_lever() -> void:
	var st := _fight(["P.....E"], [_enemy("bleacher_creeper")])
	var me := _ready_turn(st)
	var start: Vector2i = me.cell
	me.start_cell = start
	me.undo_ok = true
	st.move(me, start + Vector2i(2, 0))
	check(st.can_undo_move(me) and st.undo_move(me) and me.cell == start, "undo a Move before you play a card")
	st.move(me, start + Vector2i(1, 0))
	me.undo_ok = false
	check(not st.can_undo_move(me), "not after a card or something random")
	var off := _fight(["P.....E"], [_enemy("bleacher_creeper")], { "undo": "off" })
	var o := _ready_turn(off)
	o.undo_ok = true
	off.move(o, o.cell + Vector2i(1, 0))
	check(not off.can_undo_move(o), "the lever turns it off")


func test_hold_lever() -> void:
	var st := _fight(["P.....E"], [_enemy("bleacher_creeper")])
	check(st.hold_block(_ready_turn(st, ["card_strike"])) != "", "Hold is off in cl_base")


func test_goals() -> void:
	check(Goals.TYPES.size() == 7, "seven goal types")
	var survive := _fight(["P.....E"], [_enemy("anvil_crab")], {}, { "goal": { "type": "survive", "rounds": 2 } })
	check(survive.goal_line() != "", "the goal is shown")
	survive._end_round()
	survive._check_end()
	check(survive.result == "", "not yet")
	survive._end_round()
	survive._check_end()
	check(survive.result == "win", "survive N rounds")
	var reach := _fight(["P...<.E"], [_enemy("anvil_crab")], {}, { "goal": { "type": "reach_exit" } })
	reach._check_end()
	check(reach.result == "", "not at the exit yet")
	_me(reach).cell = Vector2i(4, 0)
	reach._check_end()
	check(reach.result == "win", "reach the exit")
	var brk := _fight(["P.....E", "......E"], [_enemy("anvil_crab"), _enemy("ward_totem")], {}, { "goal": { "type": "break", "unit": "ward_totem" } })
	brk._check_end()
	check(brk.result == "", "the totem stands")
	brk.unit_by_id("ward_totem").dead = true
	brk._check_end()
	check(brk.result == "win", "break the totem")
	var rit := _fight(["P.....E", "......E"], [_enemy("anvil_crab"), _enemy("night_nurse")], {}, { "goal": { "type": "stop_ritual", "unit": "night_nurse", "rounds": 2 } })
	rit._end_round()
	rit._check_end()
	check(rit.result == "", "the ritual charges")
	var nurse: Object = rit.unit_by_id("night_nurse")
	nurse.cell = Vector2i(3, 1)
	rit._push(_me(rit), nurse, Vector2i(1, 0), 1)
	check(rit.goal_left == 2, "a push delays it")
	rit._end_round()
	rit._end_round()
	rit._check_end()
	check(rit.result == "lose", "it lands: you lose")
	var rit2 := _fight(["P.....E", "......E"], [_enemy("anvil_crab"), _enemy("night_nurse")], {}, { "goal": { "type": "stop_ritual", "unit": "night_nurse", "rounds": 2 } })
	rit2.unit_by_id("night_nurse").dead = true
	rit2._check_end()
	check(rit2.result == "win", "kill the ritualist: you win")
	var cap := _fight(["P.....E"], [_enemy("anvil_crab")], {}, { "goal": { "type": "capture", "cell": [2, 0], "rounds": 2 } })
	cap._end_round()
	check(cap.goal_left == 2, "nobody on the tile")
	_me(cap).cell = Vector2i(2, 0)
	cap._end_round()
	cap._end_round()
	cap._check_end()
	check(cap.result == "win", "capture the tile")
	var over := _fight(["P.....E"], [_enemy("anvil_crab")], { "goal": "survive" }, { "goal": { "type": "kill" } })
	check(str(over.goal["type"]) == "survive", "the goal lever overrides the fight's")


func test_objects_are_targets_without_turns() -> void:
	var st := _fight(["P.....E"], [_enemy("bleacher_creeper")], {}, { "objects": [{ "id": "case", "name": "Case", "hp": 5, "cell": [3, 0] }], "goal": { "type": "protect", "unit": "case", "rounds": 2 } })
	var o: Object = st.unit_by_id("case")
	check(o != null and o.team == "party" and not st.order.has(o), "a protected object has no turn")
	check(st.opponents_of(_foe(st)).has(o), "enemies can aim at it")
	st._damage(o, 99, _foe(st), "", "hit")
	st._check_end()
	check(st.result == "lose", "if it breaks, you lose")
	var keep := _fight(["P.....E"], [_enemy("bleacher_creeper")], {}, { "objects": [{ "id": "case", "hp": 5, "cell": [3, 0] }], "goal": { "type": "protect", "unit": "case", "rounds": 2 } })
	keep._end_round()
	keep._end_round()
	keep._check_end()
	check(keep.result == "win", "protect it for N rounds to win")


func test_boss_phase_event_collapses_the_floor() -> void:
	var st := _fight(["P.....E", "......."], [_enemy("hollow_mascot")], {}, { "phaseEvents": { "1": { "collapse": [[3, 0]], "rounds": 1 } }, "boss": true })
	var boss := _foe(st)
	st._damage(boss, roundi(float(boss.max_hp) * 0.5), _me(st), "", "hit")
	check(st.grid.collapsing.has(Vector2i(3, 0)), "phase 2: telegraphed tiles")
	st._end_round()
	check(st.grid.get_terrain(Vector2i(3, 0)) == "pit", "then they fall")


func test_current_preset_keeps_todays_rules() -> void:
	var st := _fight(["P.....E"], [_enemy("bleacher_creeper")], {}, {}, "current")
	check(st.turn_mode == "two_actions" and st.actions_per_turn() == 2, "2 Actions")
	check(st.hand_size(_me(st)) == 3 and st.rules.flag("crits") and st.rules.flag("misses"), "hand of 3, dice on")
	var plain: Object = StateScript.new(db(), seeded(5), { "layout": { "map": ["P.....E"] }, "party": [{ "char": _ch() }], "enemies": [_enemy("bleacher_creeper")] })
	check(plain.rules.preset == "current", "a fight with no preset uses today's rules")
	var e: Object = _foe(plain)
	check(e.max_hp == int(_enemy("bleacher_creeper")["hp"]), "with the data's real numbers")

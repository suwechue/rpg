## Combat Lab Parts 3 and 3b: the new cards, keywords and the board.
extends "res://tests/suite.gd"

const StateScript := preload("res://src/core/combat/combat_state.gd")
const RM := preload("res://src/core/run/run_model.gd")
const LabOps := preload("res://src/core/combat/lab_ops.gd")
const CardText := preload("res://src/core/combat/card_text.gd")
const CardRules := preload("res://src/core/card.gd")
const Setup := preload("res://src/core/lab/lab_setup.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")


func _ch(id: String, cls: String = "fighter", player: bool = false) -> Dictionary:
	var run := RM.new_run(db(), 3, cls, seeded(3))
	var ch: Dictionary = run["player"]
	ch["id"] = id
	ch["isPlayer"] = player
	return ch


func _enemy(hp: int = 500, over: Dictionary = {}) -> Dictionary:
	var rec: Dictionary = DT.index_under(db(), "enemies/", "enemies")["bleacher_creeper"].duplicate(true)
	rec["hp"] = hp * 4
	rec.merge(over, true)
	return rec


## A two-person cl_base fight on a map. The player is at the first P, the ally at the second.
func _fight(map: Array, enemies: Array = [], levers: Dictionary = {}) -> Object:
	if enemies.is_empty():
		enemies = [_enemy()]
	var setup := { "layout": { "map": map }, "party": [{ "char": _ch("player", "fighter", true) }, { "char": _ch("ally", "mage") }], "enemies": enemies, "preset": "cl_base", "levers": levers, "difficulty": "normal", "ramp": 1.0 }
	return StateScript.new(db(), seeded(5), setup)


func _me(st: Object) -> Object:
	return st.unit_by_id("player")


func _ally(st: Object) -> Object:
	return st.unit_by_id("ally")


func _foe(st: Object) -> Object:
	for u in st.units:
		if u.team == "enemy" and u.alive():
			return u
	return null


func _foes(st: Object) -> Array:
	return st.units.filter(func(u: Object) -> bool: return u.team == "enemy")


func _turn(st: Object, hand: Array) -> Object:
	var me: Object = _me(st)
	st.current = me
	me.action_used = false
	me.actions_left = 1
	me.quick_used = false
	me.quicks_taken = 0
	me.moved_steps = 0
	me.move_left = st.move_budget(me)
	me.mp = me.max_mp
	me.links.erase("followUp")
	me.deck.hand = hand.duplicate()
	return me


func _play(st: Object, id: String, target: Vector2i, extra_hand: Array = []) -> bool:
	var me := _turn(st, [id] + extra_hand)
	return st.play_card(me, 0, target)


func test_forty_new_cards_with_text_and_real_ops() -> void:
	var cards: Array = db()["cards/lab_cards"]["cards"]
	check(cards.size() >= 40, "at least 40 new cards (%d)" % cards.size())
	var seen := {}
	for c in cards:
		seen[str(c["id"])] = true
		check(bool(c.get("labOnly", false)), "%s stays out of the story and arena for now" % c["id"])
		var text := CardRules.describe(db(), c)
		check(text.length() > 5 and not text.contains("card_op.") and not text.contains("{"), "%s has clear text: %s" % [c["id"], text])
		for e in c["effects"]:
			check(LabOps.OPS.has(str(e["op"])), "%s: op %s is real" % [c["id"], e["op"]])
	for k in db()["lab/lab"]["classDecks"]:
		var deck: Array = db()["lab/lab"]["classDecks"][k]
		check(deck.size() >= 8 and deck.size() <= 10, "%s's deck has 8 to 10 cards" % k)
		var zero := false
		for id in deck:
			var c := CardRules.resolve(db(), str(id))
			check(not c.is_empty(), "%s: %s exists" % [k, id])
			zero = zero or int(c.get("cost", 1)) == 0
		check(zero, "%s has a 0 MP card" % k)
	for id in db()["lab/lab"]["keywordCards"]:
		check(seen.has(str(id)), "keyword pool: %s is a Lab card" % id)
	check(CardText.keyword_line(db(), { "free": true, "swift": true }).contains("Free"), "keywords are in the text")


func test_every_lab_card_plays_without_error() -> void:
	for c in db()["cards/lab_cards"]["cards"]:
		var st := _fight(["P.....", "P..E.b", ".oo..."])
		var me := _me(st)
		var foe := _foe(st)
		foe.cell = me.cell + Vector2i(1, 0)
		me.deck.discard = ["lab_spark", "lab_ignite"]
		me.deck.draw_pile = ["lab_spark", "lab_shove", "lab_jab", "card_strike"]
		_ally(st).deck.draw_pile = ["lab_spark"]
		st.last_played["ally"] = { "id": "lab_spark", "target": foe.cell, "vectors": { "heat": 1.0 } }
		st.last_motion_target["player"] = "ally"
		st.pushed_this_round[foe.id] = { "dir": Vector2i(1, 0), "by": "ally", "ally": true }
		st.grid.burning[Vector2i(4, 0)] = 2
		st.current = me
		var hand := _turn(st, [str(c["id"]), "card_strike"])
		var targets: Array = st.card_targets(hand, c)
		var at: Vector2i = targets[0] if not targets.is_empty() else me.cell
		for t in targets:
			if st.unit_at(t) == foe or st.unit_at(t) == _ally(st):
				at = t
		st.preview(me, c, at)
		var block: String = st.card_block(me, c)
		if block == "" and targets.has(at):
			check(st.play_card(me, 0, at), "%s plays" % c["id"])


func test_discard_cards() -> void:
	var st := _fight(["PP..E"])
	var me := _turn(st, ["lab_recall"])
	me.deck.discard = ["lab_spark", "lab_jab"]
	st.card_choice = "lab_spark"
	check(st.play_card(me, 0, me.cell) and me.deck.hand.has("lab_spark"), "Recall: your pick comes back")
	check(me.quick_used and not me.action_used, "as a Quick")
	me = _turn(st, ["lab_recall"])
	me.deck.discard = []
	check(st.card_block(me, st.card_of(me, 0)) != "", "Recall needs a discard")
	var foe := _foe(st)
	foe.cell = me.cell + Vector2i(2, 0)
	me = _turn(st, ["lab_kindling"])
	me.deck.discard = ["lab_spark", "lab_ignite", "card_strike"]
	var hp: int = foe.hp
	check(st.play_card(me, 0, foe.cell) and hp - foe.hp == 3, "Kindling: 1 + 1 per Heat card (%d)" % (hp - foe.hp))
	me = _turn(st, ["lab_burnout"])
	me.deck.discard = ["a", "b", "c", "d"]
	hp = foe.hp
	st.chain.clear()
	check(st.play_card(me, 0, foe.cell) and hp - foe.hp == 7 and me.deck.exhausted.size() == 3, "Burnout: exhausts 3 for +2 each")
	me = _turn(st, ["lab_scrapheap"])
	me.deck.discard = ["a", "b"]
	me.deck.draw_pile = []
	check(st.play_card(me, 0, me.cell) and me.deck.hand.size() >= 1 and me.deck.discard.size() == 1, "Scrapheap: shuffles back and draws")
	me = _turn(st, ["lab_echo"])
	me.deck.discard = ["lab_spark"]
	hp = foe.hp
	st.chain.clear()
	check(st.play_card(me, 0, foe.cell) and foe.hp < hp and me.deck.discard.has("lab_spark"), "Echo replays the last discard, which stays")
	me = _turn(st, ["lab_afterimage"])
	check(st.card_block(me, st.card_of(me, 0)) != "", "Afterimage Step needs a Motion target")
	st.last_motion_target["player"] = foe.id
	var mine: Vector2i = me.cell
	var theirs: Vector2i = foe.cell
	check(st.play_card(me, 0, me.cell) and me.cell == theirs and foe.cell == mine and not me.action_used, "Afterimage Step swaps, for free")


func test_deck_cards() -> void:
	var st := _fight(["PP..E"])
	var me := _turn(st, ["lab_foresight"])
	me.deck.draw_pile = ["x", "a", "b", "c"]
	st.card_choice = ["a", "b", "c"]
	st.play_card(me, 0, me.cell)
	check(me.deck.draw_pile == ["x", "c", "b", "a"], "Foresight: the first pick is on top (%s)" % str(me.deck.draw_pile))
	me = _turn(st, ["lab_gamble", "card_strike"])
	me.deck.draw_pile = ["lab_spark", "lab_jab"]
	st.card_choice = "card_strike"
	st.play_card(me, 0, me.cell)
	check(me.deck.hand.size() == 2 and me.deck.discard.has("card_strike"), "Gamble: draw 2, discard 1")
	me = _turn(st, ["lab_deep_pocket"])
	me.deck.draw_pile = ["lab_spark", "lab_shove"]
	st.play_card(me, 0, me.cell)
	check(me.deck.hand.has("lab_shove") and me.deck.exhausted.has("lab_deep_pocket"), "Deep Pocket finds a tagged card, and Exhausts")
	me = _turn(st, ["lab_stacked_deck", "lab_burnout"])
	me.deck.draw_pile = []
	st.card_choice = "lab_burnout"
	st.play_card(me, 0, me.cell)
	check(me.deck.draw_pile == ["lab_burnout"] and st.card_cost(me, CardRules.resolve(db(), "lab_burnout")) == 0, "Stacked Deck: on top, and costs no MP")
	var foe := _foe(st)
	me.cell = Vector2i(2, 0)
	foe.cell = Vector2i(3, 0)
	me = _turn(st, ["lab_rehearsed"])
	me.played_turn = 0
	me.deck.draw_pile = ["lab_jab"]
	st.play_card(me, 0, foe.cell)
	check(me.deck.hand.has("lab_jab"), "Rehearsed: first card draws 1")
	me = _turn(st, ["lab_rehearsed"])
	me.played_turn = 1
	me.deck.draw_pile = ["lab_jab"]
	st.play_card(me, 0, foe.cell)
	check(not me.deck.hand.has("lab_jab"), "not when it isn't the first")


func test_teammate_cards_across_two_decks() -> void:
	var st := _fight(["PP..E"])
	var ally := _ally(st)
	var foe := _foe(st)
	var me := _turn(st, ["lab_pass", "lab_spark"])
	ally.deck.hand = []
	st.card_choice = "lab_spark"
	check(st.play_card(me, 0, ally.cell) and ally.deck.hand == ["lab_spark"] and me.deck.hand.is_empty(), "Pass moves a card to an ally's hand")
	me = _turn(st, ["lab_setup", "lab_burnout"])
	ally.deck.draw_pile = []
	st.card_choice = "lab_burnout"
	st.play_card(me, 0, ally.cell)
	var burn := CardRules.resolve(db(), "lab_burnout")
	check(ally.deck.draw_pile == ["lab_burnout"] and st.card_cost(ally, burn) == st.card_cost(me, burn) - 1, "Setup: on top of their deck, 1 less MP for them")
	me = _turn(st, ["lab_borrow"])
	ally.deck.draw_pile = ["lab_spark"]
	ally.deck.discard = []
	foe.cell = me.cell + Vector2i(3, 0)
	var hp: int = foe.hp
	st.chain.clear()
	check(st.play_card(me, 0, ally.cell), "Borrow plays")
	check(foe.hp < hp and ally.deck.discard.has("lab_spark") and ally.deck.draw_pile.is_empty(), "Borrow: your position, their top card, their discard")
	me = _turn(st, ["lab_harmony"])
	st.last_played["ally"] = { "id": "x", "target": foe.cell, "vectors": { "cold": 1.0 } }
	check(not st.free_now(me, st.card_of(me, 0)), "Harmony isn't free without a shared Vector")
	st.last_played["ally"] = { "id": "x", "target": foe.cell, "vectors": { "heat": 1.0 } }
	st._play_target = foe.cell
	check(st.free_now(me, st.card_of(me, 0)), "Harmony is free with one")
	st._play_target = Vector2i(-1, -1)
	me = _turn(st, ["lab_encore_two"])
	st.chain.clear()
	foe.cell = ally.cell + Vector2i(2, 0)
	st.last_played["ally"] = { "id": "lab_spark", "target": foe.cell, "vectors": { "heat": 1.0 } }
	hp = foe.hp
	check(st.play_card(me, 0, ally.cell) and foe.hp < hp, "Encore for Two: the ally replays their last card")
	me = _turn(st, ["lab_shared_burden"])
	me.statuses["burning"] = 2
	st.play_card(me, 0, ally.cell)
	check(not me.statuses.has("burning") and ally.statuses.has("burning"), "Shared Burden moves your status")
	me = _turn(st, ["lab_shared_burden"])
	st.play_card(me, 0, ally.cell)
	check(me.statuses.has("burning") and not ally.statuses.has("burning"), "or theirs to you")
	me = _turn(st, ["lab_relay"])
	foe.cell = me.cell + Vector2i(1, 0)
	if st.unit_at(foe.cell) != foe:
		foe.cell = Vector2i(3, 0)
		me.cell = Vector2i(2, 0)
	st.pushed_this_round[foe.id] = { "dir": Vector2i(1, 0), "by": "ally", "ally": true }
	var was: Vector2i = foe.cell
	st.play_card(me, 0, foe.cell)
	check(foe.cell.x > was.x, "Relay pushes it again")
	var off := _fight(["PP..E"], [], { "teammateCards": false, "discardCards": false })
	var om := _turn(off, ["lab_pass", "lab_recall"])
	check(off.card_block(om, off.card_of(om, 0)) != "" and off.card_block(om, off.card_of(om, 1)) != "", "the levers turn these cards off")


func test_board_cards() -> void:
	var st := _fight(["P..E..#", "P......", "...www."], [_enemy(), _enemy()])
	var me := _me(st)
	var es := _foes(st)
	var a: Object = es[0]
	var b: Object = es[1]
	_ally(st).cell = Vector2i(0, 2)
	a.cell = Vector2i(1, 0)
	b.cell = Vector2i(2, 0)
	me.cell = Vector2i(0, 0)
	_play(st, "lab_shove_line", Vector2i(1, 0))
	check(a.cell == Vector2i(3, 0) and b.cell == Vector2i(4, 0), "Shove Line pushes everything in the line 2 (%s %s)" % [a.cell, b.cell])
	a.cell = Vector2i(3, 0)
	b.cell = Vector2i(5, 0)
	me.cell = Vector2i(2, 1)
	_play(st, "lab_undertow", Vector2i(4, 0))
	check(a.cell == Vector2i(4, 0) or b.cell == Vector2i(4, 0), "Undertow pulls toward the tile")
	_play(st, "lab_flash_freeze", Vector2i(4, 2))
	check(st.grid.get_terrain(Vector2i(4, 2)) == GridScript.ICE, "Flash Freeze: water to ice")
	var fresh := _fight(["P..E...", "P......", "...www."])
	_me(fresh).cell = Vector2i(2, 1)
	_play(fresh, "lab_steam_vent", Vector2i(3, 2))
	check(fresh.grid.steam.has(Vector2i(3, 2)), "Steam Vent: Heat on water makes steam")
	check(fresh.grid.blocks_sight(Vector2i(3, 2)), "steam blocks sight")
	_play(fresh, "lab_anchor_point", Vector2i(3, 0))
	check(fresh.grid.anchors.has(Vector2i(3, 0)), "Anchor Point marks the tile")
	var foe := _foe(fresh)
	var m2 := _me(fresh)
	m2.cell = Vector2i(0, 0)
	foe.cell = Vector2i(1, 0)
	fresh._push(m2, foe, Vector2i(1, 0), 5)
	check(foe.cell == Vector2i(2, 0), "nothing is pushed past it")
	m2.cell = Vector2i(2, 1)
	_play(fresh, "lab_bridge", Vector2i(3, 2))
	check(fresh.grid.walkable_terrain(Vector2i(3, 2)), "Bridge: walkable over water")
	fresh._end_round()
	fresh._end_round()
	check(not fresh.grid.walkable_terrain(Vector2i(3, 2)), "for 2 rounds")
	var col := _fight(["P..E...", "P......"])
	_play(col, "lab_collapse", Vector2i(2, 1))
	check(col.grid.collapsing.has(Vector2i(2, 1)), "Collapse is telegraphed")
	var f2 := _foe(col)
	f2.cell = Vector2i(2, 1)
	col._end_round()
	check(f2.alive() and col.grid.get_terrain(Vector2i(2, 1)) != GridScript.PIT, "it holds for now")
	col._end_round()
	check(col.grid.get_terrain(Vector2i(2, 1)) == GridScript.PIT and f2.dead, "then a pit: whoever's on it falls")
	var sw := _fight(["P..E...", "P.....E"], [_enemy(), _enemy()])
	var ses := _foes(sw)
	var s1: Object = ses[0]
	var s2: Object = ses[1]
	s1.cell = Vector2i(2, 0)
	s2.cell = Vector2i(3, 1)
	_me(sw).cell = Vector2i(1, 0)
	var sm := _turn(sw, ["lab_swap"])
	sw.card_choice = s2.cell
	check(sw.play_card(sm, 0, s1.cell) and s1.cell == Vector2i(3, 1) and s2.cell == Vector2i(2, 0), "Swap: any two units")
	var toss := _fight(["P.b...E", "P......"])
	var tm := _turn(toss, ["lab_barrel_toss"])
	tm.cell = Vector2i(1, 0)
	var tf := _foe(toss)
	tf.cell = Vector2i(5, 0)
	var thp: int = tf.hp
	check(toss.card_block(tm, toss.card_of(tm, 0)) == "", "a barrel is in reach")
	check(toss.play_card(tm, 0, Vector2i(4, 0)) and tf.hp < thp, "Barrel Toss: it blows where it lands")
	var none := _fight(["P.....E", "P......"])
	var nm := _turn(none, ["lab_barrel_toss"])
	check(none.card_block(nm, none.card_of(nm, 0)) != "", "it needs a prop")


func test_payoffs() -> void:
	var st := _fight(["PP..E.."])
	var me := _me(st)
	var foe := _foe(st)
	me.cell = Vector2i(2, 0)
	foe.cell = me.cell + Vector2i(1, 0)
	var hp: int = foe.hp
	_play(st, "lab_shatter", foe.cell)
	var plain: int = hp - foe.hp
	foe.statuses["frozen"] = 2
	hp = foe.hp
	st.chain.clear()
	_play(st, "lab_shatter", foe.cell)
	check(hp - foe.hp == plain * 3, "Shatter: triple on Frozen")
	st.grid.burning[foe.cell] = 2
	hp = foe.hp
	_play(st, "lab_detonate", me.cell)
	check(foe.hp < hp, "Detonate: burning tiles explode")
	var fin := _fight(["PP..E.."])
	var fm := _me(fin)
	var ff := _foe(fin)
	fm.cell = Vector2i(2, 0)
	ff.cell = fm.cell + Vector2i(1, 0)
	var card := CardRules.resolve(db(), "lab_finisher")
	fin._play_target = ff.cell
	check(not fin.free_now(fm, card), "Finisher costs an Action first")
	fin.pushed_this_round[ff.id] = { "dir": Vector2i(1, 0), "by": "ally", "ally": true }
	check(fin.free_now(fm, card), "Free once the target was pushed this round")


func test_preview_is_the_truth() -> void:
	var st := _fight(["P.Epp..", "P......"])
	var me := _me(st)
	var foe := _foe(st)
	me.cell = Vector2i(1, 0)
	foe.cell = Vector2i(2, 0)
	var card := CardRules.resolve(db(), "lab_shove")
	var p: Dictionary = st.preview(me, card, foe.cell)
	check(bool(p["pushes"][0].get("falls", false)), "a push into a pit shows the fall")
	check(p["deaths"].has(foe.id), "and who dies")
	_play(st, "lab_shove", foe.cell)
	check(foe.dead, "and it happens")
	var st2 := _fight(["P.E#...", "P......"])
	var m2 := _me(st2)
	var f2 := _foe(st2)
	m2.cell = Vector2i(1, 0)
	f2.cell = Vector2i(2, 0)
	var p2: Dictionary = st2.preview(m2, card, f2.cell)
	check(bool(p2["pushes"][0]["collide"]) and int(p2["pushes"][0]["damage"]) == 2, "collisions show their damage")
	var water := _fight(["P.....", "P..www"])
	check(not water.preview(_me(water), CardRules.resolve(db(), "lab_flash_freeze"), Vector2i(4, 1))["notes"].is_empty(), "tile reactions are in the preview")
	check(not water.preview(_me(water), CardRules.resolve(db(), "lab_undertow"), Vector2i(4, 1))["cells"].is_empty(), "area shows")


func test_collisions_and_domino() -> void:
	var st := _fight(["P.EE.#", "P....."], [_enemy(), _enemy()])
	var es := _foes(st)
	var a: Object = es[0]
	var b: Object = es[1]
	var me := _me(st)
	me.cell = Vector2i(1, 0)
	a.cell = Vector2i(2, 0)
	b.cell = Vector2i(3, 0)
	var ah: int = a.hp
	var bh: int = b.hp
	st._push(me, a, Vector2i(1, 0), 1)
	check(ah - a.hp == 2 and bh - b.hp == 2, "both take the lever's collision damage")
	check(b.cell == Vector2i(3, 0), "no Domino: it stays")
	var dom := _fight(["P.EE..#", "P......"], [_enemy(), _enemy()], { "domino": true })
	var des := _foes(dom)
	var da: Object = des[0]
	var db2: Object = des[1]
	_me(dom).cell = Vector2i(1, 0)
	da.cell = Vector2i(2, 0)
	db2.cell = Vector2i(3, 0)
	dom._push(_me(dom), da, Vector2i(1, 0), 1)
	check(db2.cell == Vector2i(4, 0), "the Domino lever chains the push")


func test_pits_and_ledges() -> void:
	var st := _fight(["P.Ep..", "P....."], [_enemy(), _enemy()])
	var foe := _foe(st)
	var me := _me(st)
	me.cell = Vector2i(1, 0)
	foe.cell = Vector2i(2, 0)
	st.surge = 0
	st._push(me, foe, Vector2i(1, 0), 1)
	check(foe.dead and st.surge >= 1, "pits kill enemies, and count as a board kill")
	var boss := _fight(["P.Ep..", "P....."], [DT.index_under(db(), "enemies/", "enemies")["hollow_mascot"].duplicate(true)])
	var bf := _foe(boss)
	_me(boss).cell = Vector2i(1, 0)
	bf.cell = Vector2i(2, 0)
	var bh: int = bf.hp
	boss._push(_me(boss), bf, Vector2i(1, 0), 1)
	check(not bf.dead and bf.hp < bh and boss.grid.walkable_terrain(bf.cell), "bosses climb out, badly hurt")
	var pit := _fight(["P.p...", "P.....", "E....."])
	var pm := _me(pit)
	pm.cell = Vector2i(1, 0)
	var ph: int = pm.hp
	pit._push(_foe(pit), pm, Vector2i(1, 0), 1)
	check(ph - pm.hp == 3 and pit.grid.walkable_terrain(pm.cell), "party members take the lever's damage and come back at the edge")
	var off := _fight(["P.Ep..", "P....."], [], { "pitKillsEnemies": false })
	var of2 := _foe(off)
	_me(off).cell = Vector2i(1, 0)
	of2.cell = Vector2i(2, 0)
	off._push(_me(off), of2, Vector2i(1, 0), 1)
	check(not of2.dead, "the lever keeps enemies alive")
	var led := _fight(["P.Ee..", "P....."])
	var lf := _foe(led)
	_me(led).cell = Vector2i(1, 0)
	lf.cell = Vector2i(2, 0)
	var lh: int = lf.hp
	led._push(_me(led), lf, Vector2i(1, 0), 1)
	check(lh - lf.hp == 2 and lf.cell == Vector2i(4, 0), "a ledge: fall damage, and you land below it (%s)" % lf.cell)
	check(not led.grid.walkable_terrain(Vector2i(3, 0)), "you can't walk onto a ledge")


func test_ice_barrels_oil_spikes_conveyors() -> void:
	var st := _fight(["P.Eiii#", "P......"])
	var foe := _foe(st)
	var me := _me(st)
	me.cell = Vector2i(1, 0)
	foe.cell = Vector2i(2, 0)
	var hp: int = foe.hp
	st._push(me, foe, Vector2i(1, 0), 1)
	check(foe.cell == Vector2i(5, 0), "ice: pushed units slide until they hit something (%s)" % foe.cell)
	check(hp - foe.hp == 2, "and collide")
	var off := _fight(["P.Eiii#", "P......"], [], { "iceSlide": false })
	var of2 := _foe(off)
	_me(off).cell = Vector2i(1, 0)
	of2.cell = Vector2i(2, 0)
	off._push(_me(off), of2, Vector2i(1, 0), 1)
	check(of2.cell == Vector2i(3, 0), "the lever stops the slide")
	var bar := _fight(["P.b...", "P....E"])
	var pf := _foe(bar)
	pf.cell = Vector2i(3, 0)
	var bh: int = pf.hp
	var prop: Object = bar.unit_at(Vector2i(2, 0))
	check(prop != null and prop.is_prop(), "a barrel on the map")
	bar._apply_vector_effects(_me(bar), { "vectors": { "heat": 1.0 }, "power": 5.0 }, [Vector2i(2, 0)], [])
	check(prop.dead and pf.hp < bh, "Heat blows it up in a plus shape")
	var hard := _fight(["P.b...#", "P....E."])
	var hprop: Object = hard.unit_at(Vector2i(2, 0))
	_me(hard).cell = Vector2i(1, 0)
	hard._push(_me(hard), hprop, Vector2i(1, 0), 9)
	check(hprop.dead, "a hard push into a wall does too")
	var spill := _fight(["P.O...", "P....E"])
	var sp: Object = spill.unit_at(Vector2i(2, 0))
	spill._damage(sp, 5, null, "", "hit")
	check(spill.grid.oil.has(Vector2i(2, 0)) and spill.grid.oil.has(Vector2i(3, 0)), "an oil barrel spills")
	var oil := _fight(["P.ooo.", "P....E"])
	oil._apply_vector_effects(_me(oil), { "vectors": { "heat": 1.0 }, "power": 5.0 }, [Vector2i(2, 0)], [])
	check(oil.grid.burning.has(Vector2i(4, 0)), "oil spreads fire")
	var gas := _fight(["P.G...", "P.E..."])
	var gf := _foe(gas)
	var gh: int = gf.hp
	gas._apply_vector_effects(_me(gas), { "vectors": { "heat": 1.0 }, "power": 5.0 }, [Vector2i(2, 0)], [])
	check(gf.hp < gh, "gas explodes")
	var lit := _fight(["P.www.", "P....E"])
	var lf := _foe(lit)
	lf.cell = Vector2i(4, 0)
	var lh: int = lf.hp
	lit._apply_vector_effects(_me(lit), { "vectors": { "lightning": 1.0 }, "power": 5.0 }, [Vector2i(2, 0)], [])
	check(lf.hp < lh, "Lightning arcs through water")
	var sp2 := _fight(["P.sE..", "P....."])
	var mv := _turn(sp2, [])
	mv.cell = Vector2i(1, 0)
	var mh: int = mv.hp
	sp2.move(mv, Vector2i(2, 0))
	check(mh - mv.hp == 2, "spikes hurt on entry")
	var con := _fight(["P.R...", "P....E"])
	var cu := _me(con)
	cu.cell = Vector2i(2, 0)
	con._end_round()
	check(cu.cell == Vector2i(3, 0), "conveyors move units at round end")
	var crate := _fight(["P.x...", "P....E"])
	var cp: Object = crate.unit_at(Vector2i(2, 0))
	_me(crate).cell = Vector2i(1, 0)
	crate._push(_me(crate), cp, Vector2i(1, 0), 1)
	check(cp.cell == Vector2i(3, 0), "crates push")
	crate._damage(cp, 99, null, "", "hit")
	check(cp.dead, "and break")


func test_reactions_table_lever() -> void:
	var off := _fight(["P.www.", "P....E"], [], { "reactionsTable": "off" })
	off._apply_vector_effects(_me(off), { "vectors": { "cold": 1.0 }, "power": 5.0 }, [Vector2i(2, 0)], [])
	check(off.grid.get_terrain(Vector2i(2, 0)) == GridScript.ICE, "off: the old Vector rules still work")
	for type in db()["lab/reactions"]["tiles"]:
		for axis in db()["lab/reactions"]["tiles"][type]:
			check(db()["spaces"]["arcane"]["axes"].has(axis), "reactions: %s is a Vector" % axis)


func test_immovable_and_ai_avoids_edges() -> void:
	var st := _fight(["P.Ep..", "P....."], [_enemy(500, { "immovable": true })])
	var foe := _foe(st)
	_me(st).cell = Vector2i(1, 0)
	foe.cell = Vector2i(2, 0)
	st._push(_me(st), foe, Vector2i(1, 0), 2)
	check(foe.cell == Vector2i(2, 0) and not foe.dead, "immovable enemies don't budge")
	var ai := _fight(["P....p", "P....."], [_enemy()])
	var e := _foe(ai)
	e.cell = Vector2i(3, 0)
	e.move_left = 3
	e.action_used = false
	check(not AI.options(ai, e).is_empty(), "the AI still plans with the lever on")

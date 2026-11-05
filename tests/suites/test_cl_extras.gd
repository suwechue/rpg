## Combat Lab Part 3c: each extra mechanic works with its lever on and changes
## nothing with it off.
extends "res://tests/suite.gd"

const StateScript := preload("res://src/core/combat/combat_state.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Extras := preload("res://src/core/combat/extras.gd")
const CardRules := preload("res://src/core/card.gd")
const Rules := preload("res://src/core/combat/rules.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const Setup := preload("res://src/core/lab/lab_setup.gd")

const FELL := ["hitstop", "killSlowmo", "killCam", "speedControls", "plainLog"]


func _ch(id: String, cls: String = "fighter", player: bool = false) -> Dictionary:
	var run := RM.new_run(db(), 3, cls, seeded(3))
	var ch: Dictionary = run["player"]
	ch["id"] = id
	ch["isPlayer"] = player
	return ch


func _enemy(id: String = "bleacher_creeper", over: Dictionary = {}) -> Dictionary:
	var rec: Dictionary = DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)
	rec["hp"] = 2000
	rec.merge(over, true)
	return rec


func _fight(map: Array, levers: Dictionary = {}, enemies: Array = [], more: Dictionary = {}) -> Object:
	if enemies.is_empty():
		enemies = [_enemy()]
	var setup := { "layout": { "map": map }, "party": [{ "char": _ch("player", "fighter", true) }, { "char": _ch("ally", "mage") }], "enemies": enemies, "preset": "cl_base", "levers": levers, "difficulty": "normal", "ramp": 1.0, "seed": 4 }
	setup.merge(more, true)
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


func _turn(st: Object, hand: Array = []) -> Object:
	var me: Object = _me(st)
	st.current = me
	me.action_used = false
	me.actions_left = 1
	me.quick_used = false
	me.quicks_taken = 0
	me.moved_steps = 0
	me.move_left = st.move_budget(me)
	me.mp = me.max_mp
	if not hand.is_empty():
		me.deck.hand = hand.duplicate()
	return me


func test_part_3c_levers_are_off_in_cl_base_except_feel() -> void:
	var vals := Rules.values_for(db(), "cl_base")
	for k in ["chooseOrder", "cardInitiative", "delay", "facing", "highGround", "bodyBlock", "lineOfSight", "fog", "chargeSpells", "lingeringFields", "weather", "allyReactions", "fightUpgrade", "statusCards", "signatureCard", "retainKeyword", "duetCards", "enemyRoles", "weakPoints", "morale", "reserves", "bondInCombat", "classGauges", "fightWaves", "bonusObjectives", "retreat", "envTimers", "postFightChoice", "cardMastery", "storyRelics"]:
		check(vals.has(k) and vals[k] == false, "%s is off in cl_base" % k)
	check(vals["zoneOfControl"] == "off" and vals["overload"] == "off" and vals["reshuffleEffect"] == "none" and vals["downedRules"] == "current" and int(vals["bossLookahead"]) == 1 and vals["turnStructure"] == "team", "the enum levers default off")
	for k in FELL:
		check(vals[k] == true, "%s is on" % k)
	var cur := Rules.values_for(db(), "current")
	for k in FELL:
		check(cur[k] == false, "current leaves today's feel alone: %s" % k)
	for s in Rules.lever_specs(db()):
		if not ["turn", "numbers"].has(str(s["group"])) and bool(s.has("tag")):
			check(str(s.get("hint", "")) != "", "%s says what it does" % s["id"])


func test_turn_structures() -> void:
	var team := _fight(["P.....E", "P.....E"], {}, [_enemy(), _enemy()])
	check(team.order[0].team == "party" and team.order[1].team == "party" and team.order[2].team == "enemy", "team: the party, then the enemies")
	var alt := _fight(["P.....E", "P.....E"], { "turnStructure": "alternate" }, [_enemy(), _enemy()])
	check(alt.order[0].team == "party" and alt.order[1].team == "enemy" and alt.order[2].team == "party", "alternate: one ally, one enemy")


func test_choose_order() -> void:
	var st := _fight(["P.....E", "P......"], { "chooseOrder": true })
	var me: Object = st.current
	var other: Object = _ally(st) if me == _me(st) else _me(st)
	check(Extras.can_pick_turn(st, other), "you can pick who goes next")
	me.move_left = 1
	check(Extras.pick_turn(st, other) and st.current == other, "they go now")
	check(st.order.find(me) > st.order.find(other), "the first one still has their turn")
	var kept: int = me.move_left
	st.end_turn()
	check(st.current == me and me.move_left == kept, "and picks up where they left off")
	var off := _fight(["P.....E", "P......"])
	var o2: Object = _ally(off) if off.current == _me(off) else _me(off)
	check(not Extras.can_pick_turn(off, o2), "off: no picking")


func test_card_initiative() -> void:
	var st := _fight(["P.....E"], { "cardInitiative": true })
	var me := _me(st)
	var base: int = me.initiative
	Extras.card_initiative(st, me, { "quick": true })
	check(me.init_bonus > 0, "a Quick card moves you earlier")
	Extras.card_initiative(st, me, { "heavy": true })
	check(me.init_bonus < 0, "Heavy moves you later")
	st._build_order()
	check(me.init_bonus == 0 and me.initiative == base, "for one round")
	var off := _fight(["P.....E"])
	Extras.card_initiative(off, _me(off), { "quick": true })
	check(_me(off).init_bonus == 0, "off: nothing")


func test_delay() -> void:
	var st := _fight(["P.....E", "P......"], { "delay": true })
	var me: Object = st.current
	check(Extras.can_delay(st, me), "you can pass")
	var foe := _foe(st)
	check(Extras.delay(st, me) and st.current != me, "the turn moves on")
	check(st.order.find(me) > st.order.find(foe), "you act after the next enemy")
	me.links["delayed_round"] = str(st.round_num)
	st.current = me
	check(not Extras.can_delay(st, me), "once a round")
	var off := _fight(["P.....E", "P......"])
	check(not Extras.can_delay(off, off.current), "off: no")


func test_facing() -> void:
	var st := _fight(["P.E.P.."], { "facing": true })
	var a := _me(st)
	var foe := _foe(st)
	a.cell = Vector2i(1, 0)
	foe.cell = Vector2i(2, 0)
	foe.facing_dir = Vector2i(-1, 0)
	check(Extras.facing_mul(st, a, foe) == 1.0, "from the front: normal")
	foe.facing_dir = Vector2i(1, 0)
	check(Extras.facing_mul(st, a, foe) == 1.5, "from behind: more")
	foe.facing_dir = Vector2i(0, 1)
	check(Extras.facing_mul(st, a, foe) == 1.25, "from the side: some more")
	var me2 := _turn(st)
	me2.cell = Vector2i(4, 0)
	st.grid.terrain[0][5] = "floor"
	st.move(me2, Vector2i(5, 0))
	check(me2.facing_dir == Vector2i(1, 0), "you face the way you moved")
	check(Extras.facing_mul(_fight(["P.E"]), a, foe) == 1.0, "off: nothing")


func test_zone_of_control() -> void:
	var st := _fight(["P.E...", "......"], { "zoneOfControl": "extra_move" })
	var me := _turn(st)
	var foe := _foe(st)
	me.cell = Vector2i(1, 0)
	foe.cell = Vector2i(2, 0)
	var off := _fight(["P.E...", "......"])
	var om := _turn(off)
	var of2 := _foe(off)
	om.cell = Vector2i(1, 0)
	of2.cell = Vector2i(2, 0)
	check(st.reachable_cells(me).size() < off.reachable_cells(om).size(), "leaving costs +1 Movement")
	var dest := Vector2i(1, 1)
	var before: int = me.move_left
	st.move(me, dest)
	check(before - me.move_left == 2, "and it's spent")
	var hit := _fight(["P.E...", "......"], { "zoneOfControl": "free_hit" })
	var hm := _turn(hit)
	var hf := _foe(hit)
	hm.cell = Vector2i(1, 0)
	hf.cell = Vector2i(2, 0)
	var hp: int = hm.hp
	hit.move(hm, Vector2i(1, 1))
	check(hm.hp < hp, "or gives that enemy a free hit")
	var quiet := _fight(["P.E...", "......"])
	var qm := _turn(quiet)
	var qf := _foe(quiet)
	qm.cell = Vector2i(1, 0)
	qf.cell = Vector2i(2, 0)
	hp = qm.hp
	quiet.move(qm, Vector2i(1, 1))
	check(qm.hp == hp, "off: nothing")


func test_high_ground() -> void:
	var st := _fight(["PH..E..", "......."], { "highGround": true })
	var me := _me(st)
	var foe := _foe(st)
	check(st.grid.high.has(Vector2i(1, 0)), "H is a raised tile")
	me.cell = Vector2i(1, 0)
	foe.cell = Vector2i(3, 0)
	check(Extras.high_range(st, me) == 1 and Extras.high_bonus(st, me, foe) == 1.0, "+range and +damage downhill")
	var low: float = st._final_number(5.0, foe, me)
	me.cell = Vector2i(0, 1)
	check(st._final_number(5.0, me, foe) >= 1.0 and Extras.high_bonus(st, me, foe) == 0.0, "not from low ground")
	me.cell = Vector2i(0, 0)
	foe.cell = Vector2i(1, 0)
	var hp: int = foe.hp
	st._push(me, foe, Vector2i(1, 0), 1)
	check(foe.hp < hp, "pushed off a raised tile: a fall")
	var off := _fight(["PH..E.."])
	var om := _me(off)
	om.cell = Vector2i(1, 0)
	check(Extras.high_range(off, om) == 0 and Extras.high_bonus(off, om, _foe(off)) == 0.0, "off: nothing")


func test_body_block() -> void:
	var st := _fight(["P.P..E."], { "bodyBlock": true })
	var me := _me(st)
	var ally := _ally(st)
	var foe := _foe(st)
	me.cell = Vector2i(0, 0)
	ally.cell = Vector2i(2, 0)
	foe.cell = Vector2i(5, 0)
	var it := { "kind": "attack", "mode": "locked", "action": { "form": "bolt", "vectors": { "heat": 1.0 }, "power": 5 }, "move": foe.cell, "target": me.cell, "cells": [me.cell], "unit": me.id, "charge": 0 }
	check(st.blocked_cells(foe, it) == [ally.cell], "the ally between takes it")
	var off := _fight(["P.P..E."])
	_me(off).cell = Vector2i(0, 0)
	_ally(off).cell = Vector2i(2, 0)
	check(off.blocked_cells(_foe(off), it) == [me.cell], "off: it passes allies")


func test_line_of_sight_and_fog() -> void:
	var st := _fight(["P.x.E..", "......."], { "lineOfSight": true })
	var me := _me(st)
	var foe := _foe(st)
	me.cell = Vector2i(0, 0)
	foe.cell = Vector2i(4, 0)
	var spell := { "id": "x", "kind": "spell", "vectors": { "heat": 1.0 }, "form": "bolt", "magnitude": "minor" }
	check(not st.card_targets(me, spell).has(foe.cell), "a crate blocks the line")
	var off := _fight(["P.x.E..", "......."])
	_me(off).cell = Vector2i(0, 0)
	_foe(off).cell = Vector2i(4, 0)
	check(off.card_targets(_me(off), spell).has(Vector2i(4, 0)), "off: it doesn't")
	var fog := _fight(["P.....E"], { "fog": true })
	var ff := _foe(fog)
	check(fog.grid.fog.has(ff.cell), "fog covers the far side")
	ff.intent = { "kind": "attack", "action": { "kind": "strike", "damage": 3 }, "cells": [Vector2i(0, 0)], "move": ff.cell, "target": Vector2i(0, 0), "mode": "locked" }
	check(Extras.plan_hidden(fog, ff) and fog.intent_cells(ff).is_empty(), "the plan is hidden")
	fog.grid.lit[ff.cell] = 2
	check(not Extras.plan_hidden(fog, ff) and not fog.intent_cells(ff).is_empty(), "Light shows it")
	fog.grid.lit.clear()
	_me(fog).cell = ff.cell + Vector2i(-1, 0)
	check(not Extras.plan_hidden(fog, ff), "so does standing next to it")
	var nofog := _fight(["P.....E"])
	check(nofog.grid.fog.is_empty() and not Extras.plan_hidden(nofog, _foe(nofog)), "off: nothing hidden")


func test_charge_spells() -> void:
	var st := _fight(["P.....E"], { "chargeSpells": true })
	var me := _turn(st, ["lab_charge_ram"])
	var foe := _foe(st)
	foe.cell = me.cell + Vector2i(3, 0)
	var hp: int = foe.hp
	check(st.play_card(me, 0, foe.cell) and foe.hp == hp and st.charges.size() == 1, "a Charge card waits")
	check(not st.threats().get(foe.cell, []).is_empty(), "and its tiles are telegraphed")
	check(str(st.charges[0]["card"]["magnitude"]) == "major", "a Magnitude higher")
	Extras.fire_charges(st, me)
	check(foe.hp < hp and st.charges.is_empty(), "it fires at the start of your next turn")
	var off := _fight(["P.....E"])
	var om := _turn(off, ["lab_charge_ram"])
	var of2 := _foe(off)
	of2.cell = om.cell + Vector2i(3, 0)
	hp = of2.hp
	off.play_card(om, 0, of2.cell)
	check(of2.hp < hp and off.charges.is_empty(), "off: it fires at once")
	var count := 0
	for c in db()["cards/lab_cards"]["cards"]:
		if bool(c.get("charge", false)):
			count += 1
	check(count == 6, "6 Charge cards")


func test_lingering_fields() -> void:
	var st := _fight(["P.....E", "......."], { "lingeringFields": true })
	var me := _me(st)
	Extras.linger(st, me, { "heat": 1.0 }, [Vector2i(2, 0)])
	check(int(st.grid.burning.get(Vector2i(2, 0), 0)) == 3, "Heat leaves fire")
	Extras.linger(st, me, { "cold": 1.0 }, [Vector2i(3, 0)])
	check(st.grid.get_terrain(Vector2i(3, 0)) == GridScript.ICE, "Cold ice")
	Extras.linger(st, me, { "binding": 1.0 }, [Vector2i(4, 0)])
	check(st.grid.sticky.has(Vector2i(4, 0)), "Binding sticky ground")
	check(Extras.leave_costs(st, me).has(Vector2i(4, 0)), "which costs +1 Movement")
	Extras.linger(st, me, { "light": 1.0 }, [Vector2i(5, 0)])
	check(st.grid.lit.has(Vector2i(5, 0)), "Light glare")
	Extras.linger(st, me, { "force": 1.0 }, [Vector2i(2, 1)])
	check(st.grid.get_terrain(Vector2i(2, 1)) != GridScript.PIT, "Force cracks")
	Extras.linger(st, me, { "force": 1.0 }, [Vector2i(2, 1)])
	check(st.grid.get_terrain(Vector2i(2, 1)) == GridScript.PIT, "and 2 hits make a pit")
	for i in 3:
		st._end_round()
	check(st.grid.get_terrain(Vector2i(3, 0)) == GridScript.FLOOR and not st.grid.sticky.has(Vector2i(4, 0)), "for N rounds")
	var off := _fight(["P.....E"])
	Extras.linger(off, _me(off), { "binding": 1.0 }, [Vector2i(2, 0)])
	check(off.grid.sticky.is_empty(), "off: nothing")


func test_weather() -> void:
	var st := _fight(["P.....E"], { "weather": true }, [], { "weather": { "strong": "heat", "weak": "cold" } })
	var hot := { "vectors": { "heat": 1.0 }, "form": "bolt", "magnitude": "standard" }
	var cold := { "vectors": { "cold": 1.0 }, "form": "bolt", "magnitude": "standard" }
	var plain := { "vectors": { "force": 1.0 }, "form": "bolt", "magnitude": "standard" }
	check(str(Extras.weather_card(st, hot)["magnitude"]) == "major", "strong: a Magnitude up")
	check(str(Extras.weather_card(st, cold)["magnitude"]) == "minor", "weak: a Magnitude down")
	check(str(Extras.weather_card(st, plain)["magnitude"]) == "standard", "others: the same")
	check(st._spell_spec(_me(st), hot)["power"] > st._spell_spec(_me(st), plain)["power"], "the spell really is stronger")
	check(Extras.active_line(st).contains("Heat+"), "shown on the HUD")
	var off := _fight(["P.....E"])
	check(str(Extras.weather_card(off, hot)["magnitude"]) == "standard", "off: nothing")


func test_overload() -> void:
	var big := { "id": "big", "name": "Big", "kind": "spell", "vectors": { "force": 1.0 }, "form": "bolt", "magnitude": "major" }
	var lib := { "big": big }
	var st := _fight(["P.....E"], { "overload": "hp" }, [], { "library": lib })
	var me := _turn(st, ["big"])
	var foe := _foe(st)
	foe.cell = me.cell + Vector2i(3, 0)
	me.mp = 1
	check(st.card_block(me, big) == "", "one Magnitude above what you can afford")
	var hp: int = me.hp
	check(st.play_card(me, 0, foe.cell) and me.hp == hp - 3 and me.mp == 0, "pays HP")
	var ex := _fight(["P.....E"], { "overload": "exhaust" }, [], { "library": lib })
	var em := _turn(ex, ["card_strike", "big"])
	var ef := _foe(ex)
	ef.cell = em.cell + Vector2i(3, 0)
	em.mp = 1
	check(ex.play_card(em, 1, ef.cell) and em.deck.exhausted.has("card_strike"), "or Exhausts a card")
	var off := _fight(["P.....E"], {}, [], { "library": lib })
	var om := _turn(off, ["big"])
	om.mp = 1
	check(off.card_block(om, big) != "", "off: you can't")


func test_ally_reactions() -> void:
	var st := _fight(["P.E....", "P......"], { "allyReactions": true })
	var foe := _foe(st)
	var hp: int = foe.hp
	Extras.ally_hit(st, _me(st), foe.cell, "cold")
	Extras.ally_hit(st, _me(st), foe.cell, "force")
	check(foe.hp == hp, "one ally alone sets nothing off")
	st.reaction_hits.clear()
	st.surge = 0
	Extras.ally_hit(st, _me(st), foe.cell, "cold")
	Extras.ally_hit(st, _ally(st), foe.cell, "force")
	check(foe.hp < hp and st.surge >= 1 and st.combos_cast.has("Shatter"), "two allies, two Vectors: a named reaction, Surge and discovery")
	var off := _fight(["P.E....", "P......"])
	var of2 := _foe(off)
	hp = of2.hp
	Extras.ally_hit(off, _me(off), of2.cell, "cold")
	Extras.ally_hit(off, _ally(off), of2.cell, "force")
	check(of2.hp == hp, "off: nothing")


func test_fight_upgrade_and_mastery() -> void:
	var st := _fight(["P.....E"], { "fightUpgrade": true, "fightUpgradeAt": 2 })
	var me := _turn(st, ["lab_spark"])
	check(not str(st.card_of(me, 0)["name"]).ends_with("+"), "not yet")
	Extras.note_play(st, me, "lab_spark")
	Extras.note_play(st, me, "lab_spark")
	check(str(st.card_of(me, 0)["name"]).ends_with("+"), "played N times: its + version")
	var off := _fight(["P.....E"])
	var om := _turn(off, ["lab_spark"])
	Extras.note_play(off, om, "lab_spark")
	Extras.note_play(off, om, "lab_spark")
	Extras.note_play(off, om, "lab_spark")
	check(not str(off.card_of(om, 0)["name"]).ends_with("+"), "off: never")
	var uses := {}
	var mas := _fight(["P.....E"], { "cardMastery": true, "masteryUses": 2 }, [], { "mastery": uses })
	var mm := _turn(mas, ["lab_spark"])
	Extras.note_play(mas, mm, "lab_spark")
	Extras.note_play(mas, mm, "lab_spark")
	check(int(uses["lab_spark"]) == 2, "mastery counts across the run")
	var later := _fight(["P.....E"], { "cardMastery": true, "masteryUses": 2 }, [], { "mastery": uses })
	check(str(later.card_of(_turn(later, ["lab_spark"]), 0)["name"]).ends_with("+"), "and it stays mastered next fight")


func test_status_cards() -> void:
	var st := _fight(["P.....E"], { "statusCards": true })
	var me := _turn(st, ["card_strike", "status_fear"])
	var foe := _foe(st)
	check(st.card_block(me, CardRules.resolve(db(), "status_fear")) != "", "Fear can't be played")
	me.deck.draw_pile = []
	Extras.status_card(st, { "addsStatusCard": "status_burned" }, me)
	check(me.deck.draw_pile.has("status_burned"), "an enemy attack shuffles junk into your deck")
	var hp: int = me.hp
	Extras.on_drawn(st, me, ["status_burned"])
	check(me.hp == hp - 1, "Burned: lose 1 HP when drawn")
	me.deck.hand = ["card_strike", "status_fear"]
	Extras.on_drawn(st, me, ["status_fear"])
	check(not me.deck.hand.has("card_strike"), "Fear: discards 1 when drawn")
	var t := _turn(st, ["status_tangled"])
	check(st.play_card(t, 0, t.cell) and t.move_left == 0 and t.deck.exhausted.has("status_tangled"), "Tangled: costs your Move to play away")
	var clean := _turn(st, ["lab_clear_head", "status_fear"])
	clean.deck.discard = ["status_burned"]
	st.play_card(clean, 0, clean.cell)
	check(not clean.deck.hand.has("status_fear") and not clean.deck.discard.has("status_burned"), "a cleanse card removes them")
	var off := _fight(["P.....E"])
	var om := _turn(off)
	om.deck.draw_pile = []
	Extras.status_card(off, { "addsStatusCard": "status_burned" }, om)
	check(om.deck.draw_pile.is_empty(), "off: no junk")
	var with_junk := 0
	for rec in DT.records_under(db(), "enemies/", "enemies"):
		for a in rec.get("actions", []):
			if a.has("addsStatusCard"):
				with_junk += 1
				check(not CardRules.resolve(db(), str(a["addsStatusCard"])).is_empty(), "%s's junk card exists" % rec["id"])
	check(with_junk >= 6, "on 6 enemies (%d)" % with_junk)


func test_signature_retain_duet_reshuffle() -> void:
	var st := _fight(["P.....E"], { "signatureCard": true })
	check(_me(st).deck.hand.has("sig_brick"), "the signature card is in the opening hand")
	var off := _fight(["P.....E"])
	check(not _me(off).deck.hand.has("sig_brick"), "off: no")
	var sigs: Dictionary = db()["cards/signature_cards"]["signatures"]
	check(sigs.size() == 9, "5 preset characters and the Core Four")
	for k in sigs:
		check(not CardRules.resolve(db(), str(sigs[k])).is_empty(), "%s's signature exists" % k)
	var ret := _fight(["P.....E"], { "keepHand": false, "retainKeyword": true })
	var rm := _me(ret)
	rm.deck.hand = ["lab_shatter", "card_strike"]
	ret._discard_hand(rm)
	check(rm.deck.hand == ["lab_shatter"], "Retain stays when the hand is discarded")
	var nr := _fight(["P.....E"], { "keepHand": false })
	var nm := _me(nr)
	nm.deck.hand = ["lab_shatter"]
	nr._discard_hand(nm)
	check(nm.deck.hand.is_empty(), "off: it goes")
	check(db()["cards/duet_cards"]["cards"].size() == 5, "5 duets")
	var duet := CardRules.resolve(db(), "duet_molten_shove")
	var d := _fight(["PP....E"], { "duetCards": true })
	_me(d).source["partyBonds"] = { "ally": 80.0 }
	check(Extras.duet_block(d, _me(d), duet) == "", "the fighter and mage are adjacent")
	_ally(d).cell = Vector2i(3, 0)
	check(Extras.duet_block(d, _me(d), duet) != "", "apart, it can't be played")
	var dn := _fight(["PP....E"])
	check(Extras.duet_block(dn, _me(dn), duet) != "", "off: never")
	var built := Setup.build(db(), "ledge_day", "cl_base", { "duetCards": true }, [{ "class": "fighter", "level": 1 }, { "class": "mage", "level": 1 }])
	check(built["run"]["player"]["deck"].has("duet_molten_shove"), "the Lab gives matching parties their duets")
	var r := _fight(["P.....E"], { "reshuffleEffect": "surge" })
	Extras.on_reshuffle(r, _me(r))
	check(r.surge == 1, "reshuffle: +1 Surge")
	var h := _fight(["P.....E"], { "reshuffleEffect": "hp_cost" })
	var hp: int = _me(h).hp
	Extras.on_reshuffle(h, _me(h))
	check(_me(h).hp == hp - 1, "or -1 HP")
	var n := _fight(["P.....E"])
	hp = _me(n).hp
	Extras.on_reshuffle(n, _me(n))
	check(n.surge == 0 and _me(n).hp == hp, "none: nothing")


func test_enemy_roles() -> void:
	var st := _fight(["P.E...#", "P.E...."], { "enemyRoles": true }, [_enemy("bleacher_creeper", { "labRole": "shield" }), _enemy("bleacher_creeper", { "labRole": "anchor" })])
	var es: Array = st.units.filter(func(u: Object) -> bool: return u.team == "enemy")
	check(float(es[0].source.get("frontBlock", 0.0)) > 0.0, "Shield bearer: the front is blocked")
	check(bool(es[1].source.get("immovable", false)), "Anchor: immovable")
	var me := _me(st)
	es[0].cell = Vector2i(2, 0)
	es[1].cell = Vector2i(4, 1)
	me.cell = Vector2i(1, 0)
	st._push(me, es[0], Vector2i(1, 0), 3)
	check(es[0].cell.x <= 3, "and it stops pushes next to it")
	var bm := _fight(["P.E...", "...E..", "......"], { "enemyRoles": true }, [_enemy("bleacher_creeper", { "labRole": "bomber" }), _enemy()])
	var bs: Array = bm.units.filter(func(u: Object) -> bool: return u.team == "enemy")
	var mb := _me(bm)
	mb.cell = Vector2i(1, 0)
	bs[0].cell = Vector2i(2, 0)
	bs[1].cell = Vector2i(3, 1)
	var hp: int = bs[1].hp
	bm._push(mb, bs[0], Vector2i(1, 0), 1)
	check(bs[0].dead and bs[1].hp < hp, "Bomber: goes off when pushed, for you too")
	var sm := _fight(["P.....E"], { "enemyRoles": true }, [_enemy("bleacher_creeper", { "labRole": "summoner" })])
	check(str(_foe(sm).source.get("behavior", "")) == "summoner", "Summoner")
	var cp := _fight(["P.....E"], { "enemyRoles": true }, [_enemy("bleacher_creeper", { "labRole": "copycat" })])
	check(str(_foe(cp).source.get("behavior", "")) == "mirror", "Copycat")
	var off := _fight(["P.E...#"], {}, [_enemy("bleacher_creeper", { "labRole": "anchor" })])
	check(not bool(_foe(off).source.get("immovable", false)), "off: a plain enemy")


func test_weak_points_morale_lookahead() -> void:
	var st := _fight(["P.E...."], { "weakPoints": true }, [_enemy("bleacher_creeper", { "weakPoint": "back" })])
	var foe := _foe(st)
	var me := _me(st)
	me.cell = Vector2i(3, 0)
	foe.cell = Vector2i(2, 0)
	foe.facing_dir = Vector2i(-1, 0)
	check(Extras.weak_from(st, me, foe), "the marked side")
	check(Extras.weak_cells(st, foe) == [Vector2i(3, 0)], "shown on the field")
	foe.intent = { "kind": "attack", "action": { "kind": "strike", "damage": 3 }, "cells": [me.cell], "move": foe.cell, "target": me.cell, "mode": "locked", "unit": me.id }
	st._damage(foe, 1, me, "", "hit")
	check(foe.intent.is_empty() and foe.links.has("staggered"), "a hit there Staggers and cancels the telegraph")
	var off := _fight(["P.E...."], {}, [_enemy("bleacher_creeper", { "weakPoint": "back" })])
	check(not Extras.weak_from(off, _me(off), _foe(off)), "off: no")
	var mo := _fight(["P.EE..."], { "morale": true }, [_enemy(), _enemy()])
	var ms: Array = mo.units.filter(func(u: Object) -> bool: return u.team == "enemy")
	mo.rng.seed = 1
	var panicked := false
	for i in 12:
		ms[1].intent = {}
		ms[1].disposition = {}
		Extras.on_enemy_death(mo, ms[0])
		panicked = panicked or str(ms[1].intent.get("kind", "")) == "move"
	check(panicked, "a death nearby can cause panic")
	var boss := _fight(["P.EE..."], { "morale": true }, [_enemy(), _enemy("hollow_mascot")])
	var bs: Array = boss.units.filter(func(u: Object) -> bool: return u.team == "enemy")
	for i in 12:
		bs[1].intent = {}
		Extras.on_enemy_death(boss, bs[0])
	check(bs[1].intent.is_empty(), "bosses don't panic")
	var mf := _fight(["P.EE..."], {}, [_enemy(), _enemy()])
	var mfs: Array = mf.units.filter(func(u: Object) -> bool: return u.team == "enemy")
	mfs[1].intent = {}
	for i in 12:
		Extras.on_enemy_death(mf, mfs[0])
	check(mfs[1].intent.is_empty(), "off: nothing")
	var look := _fight(["P.....E", "......."], { "bossLookahead": 2 }, [_enemy("hollow_mascot")])
	var lb := _foe(look)
	Extras.plan_ahead(look, lb)
	check(not lb.intent_next.is_empty(), "bosses show their next plan")
	var nl := _fight(["P.....E", "......."], {}, [_enemy("hollow_mascot")])
	Extras.plan_ahead(nl, _foe(nl))
	check(_foe(nl).intent_next.is_empty(), "1: just this one")


func test_carry_downed() -> void:
	var st := _fight(["PP.....", ".......", "......E"], { "downedRules": "carry" })
	var ally := _ally(st)
	var me := _turn(st)
	ally.hp = 1
	st._damage(ally, 5, null, "", "pit")
	check(ally.downed and not ally.dead, "a downed ally lies on the board")
	for i in 5:
		st._end_round()
	check(not ally.dead, "and doesn't bleed out")
	me.cell = ally.cell + Vector2i(-1, 0)
	check(Extras.can_drag(st, me, ally), "you can drag them")
	var to: Vector2i = ally.cell + Vector2i(1, 0)
	check(Extras.drag(st, me, ally, to) and ally.cell == to and me.move_left == 0, "1 tile, with your Move")
	st._heal(me, ally, 3, false)
	check(not ally.downed, "a heal revives them")
	ally.hp = 1
	st._damage(ally, 5, null, "", "pit")
	st._damage(ally, 1, _foe(st), "", "hit")
	check(ally.dead, "hit while down: out")
	var off := _fight(["PP.....", "......E"])
	check(not Extras.can_drag(off, _me(off), _ally(off)), "off: no dragging")


func test_reserves_and_bond() -> void:
	var reserve := _ch("bench", "healer")
	var st := _fight(["P.....E", "P......"], { "reserves": true }, [], { "reserves": [reserve] })
	_turn(st)
	var ally := _ally(st)
	check(Extras.can_bring_reserve(st), "a reserve is ready")
	check(Extras.bring_reserve(st, ally) and ally.dead and st.unit_by_id("bench") != null, "they come in for the chosen ally")
	check(st.unit_by_id("bench").last_turn_round == st.round_num, "their turn is spent")
	check(not Extras.can_bring_reserve(st), "once")
	var off := _fight(["P.....E", "P......"], {}, [], { "reserves": [reserve] })
	_turn(off)
	check(not Extras.can_bring_reserve(off), "off: no")
	check(not Setup.build(db(), "ledge_day", "cl_base", { "reserves": true })["setup"]["reserves"].is_empty(), "the Lab benches a class the party doesn't have")
	var a := _ch("player", "fighter", true)
	var b := _ch("ally", "mage")
	a["partyBonds"] = { "ally": 80.0 }
	var q := { "id": "q", "name": "q", "kind": "basic", "action": "effects", "cost": 0, "quick": true, "targeting": { "type": "self" }, "effects": [] }
	var bo: Object = StateScript.new(db(), seeded(5), { "layout": { "map": ["PP....E"] }, "party": [{ "char": a }, { "char": b }], "enemies": [_enemy()], "preset": "cl_base", "levers": { "bondInCombat": true }, "library": { "q": q } })
	var me := _turn(bo, ["q", "q", "q"])
	bo.play_card(me, 0, me.cell)
	check(me.quick_used and not me.action_used, "first Quick")
	bo.play_card(me, 0, me.cell)
	check(not me.action_used and bo.bond_quicks.size() == 1, "the bonded neighbor shares a free Quick")
	bo.play_card(me, 0, me.cell)
	check(me.action_used, "one a round")
	var nb := _ch("player", "fighter", true)
	nb["partyBonds"] = { "ally": 80.0 }
	var nbo: Object = StateScript.new(db(), seeded(5), { "layout": { "map": ["PP....E"] }, "party": [{ "char": nb }, { "char": _ch("ally", "mage") }], "enemies": [_enemy()], "preset": "cl_base", "library": { "q": q } })
	var n2 := _turn(nbo, ["q", "q"])
	nbo.play_card(n2, 0, n2.cell)
	nbo.play_card(n2, 0, n2.cell)
	check(n2.action_used, "off: no sharing")


func test_class_gauges() -> void:
	var gauges: Dictionary = db()["lab/gauges"]["gauges"]
	check(gauges.size() == 5, "a gauge per class")
	var st := _fight(["P.E....", "P......"], { "classGauges": true })
	var me := _turn(st)
	var foe := _foe(st)
	me.cell = Vector2i(1, 0)
	foe.cell = Vector2i(2, 0)
	st._push(me, foe, Vector2i(1, 0), 1)
	check(me.gauge >= 1, "Fighter: Momentum fills on pushes")
	me.gauge = int(gauges["fighter"]["max"])
	check(Extras.gauge_full(st, me), "full")
	foe.cell = me.cell + Vector2i(1, 0)
	var at: Vector2i = foe.cell
	check(Extras.spend_gauge(st, me) and foe.cell != at and me.gauge == 0, "spend: pushes adjacent enemies")
	var mg := _fight(["P.....E", "P......"], { "classGauges": true })
	var mu := _ally(mg)
	mu.gauge = int(gauges["mage"]["max"])
	mg.current = mu
	check(Extras.spend_gauge(mg, mu) and mu.links.has("overheat"), "Mage: the next cast overheats")
	Extras.gauge_add(mg, mu)
	check(mu.gauge == 0, "and the meter locks")
	var ro: Object = StateScript.new(db(), seeded(5), { "layout": { "map": ["P.....E"] }, "party": [{ "char": _ch("player", "rogue", true) }], "enemies": [_enemy()], "preset": "cl_base", "levers": { "classGauges": true } })
	var ru := _me(ro)
	var fo := _foe(ro)
	fo.intent = {}
	Extras.gauges_round(ro)
	check(ru.gauge == 1, "Rogue: Shadow fills in rounds nobody aims at you")
	ru.gauge = int(gauges["rogue"]["max"])
	ro.current = ru
	var mv: int = ru.move_left
	check(Extras.spend_gauge(ro, ru) and ru.move_left > mv and ru.links.has("back_hit"), "spend: a reposition and a back hit")
	var he: Object = StateScript.new(db(), seeded(5), { "layout": { "map": ["PP....E"] }, "party": [{ "char": _ch("player", "healer", true) }, { "char": _ch("ally", "fighter") }], "enemies": [_enemy()], "preset": "cl_base", "levers": { "classGauges": true } })
	var hu := _me(he)
	he.current = hu
	he._heal(hu, _ally(he), 1, false)
	check(hu.gauge >= 1, "Healer: Faith fills on healing")
	hu.gauge = int(gauges["healer"]["max"])
	_ally(he).hp = 1
	var sh: int = _ally(he).shield
	check(Extras.spend_gauge(he, hu) and _ally(he).shield > sh, "spend: a shield")
	var ba: Object = StateScript.new(db(), seeded(5), { "layout": { "map": ["PP....E"] }, "party": [{ "char": _ch("player", "bard", true) }, { "char": _ch("ally", "fighter") }], "enemies": [_enemy()], "preset": "cl_base", "levers": { "classGauges": true } })
	var bu := _me(ba)
	ba.current = bu
	ba.chain["x"] = ["ally"]
	ba._emit({ "t": "cast", "unit": bu.id })
	check(bu.gauge == 1, "Bard: Tempo fills when you chain with allies")
	bu.gauge = int(gauges["bard"]["max"])
	check(Extras.spend_gauge(ba, bu) and _ally(ba).links.has("extra_action"), "spend: an ally gets an extra Action")
	ba._start_turn(_ally(ba))
	check(_ally(ba).actions_left == 2, "on their next turn")
	var off := _fight(["P.E....", "P......"])
	var om := _turn(off)
	om.cell = Vector2i(1, 0)
	_foe(off).cell = Vector2i(2, 0)
	off._push(om, _foe(off), Vector2i(1, 0), 1)
	check(om.gauge == 0 and not Extras.gauge_full(off, om), "off: nothing fills")


func test_waves_and_doors() -> void:
	var wave := [{ "round": 2, "enemies": ["dust_gremlin"], "door": [5, 0] }]
	var st := _fight(["P.....E", "......."], { "fightWaves": true }, [], { "waves": wave })
	check(st.grid.doors.has(Vector2i(5, 0)), "the door is marked")
	var n: int = st.units.filter(func(u: Object) -> bool: return u.team == "enemy").size()
	st.round_num = 1
	Extras.waves_tick(st)
	check(st.units.filter(func(u: Object) -> bool: return u.team == "enemy").size() == n, "warned a round early")
	st.round_num = 2
	Extras.waves_tick(st)
	check(st.units.filter(func(u: Object) -> bool: return u.team == "enemy").size() == n + 1, "then they arrive")
	var blocked := _fight(["P.....E", "......."], { "fightWaves": true }, [], { "waves": wave })
	_me(blocked).cell = Vector2i(5, 0)
	blocked.round_num = 2
	Extras.waves_tick(blocked)
	check(blocked.units.filter(func(u: Object) -> bool: return u.team == "enemy").size() == n and blocked.waves.is_empty(), "standing on the door stops that group")
	var off := _fight(["P.....E", "......."], {}, [], { "waves": wave })
	check(off.waves.is_empty() and off.grid.doors.is_empty(), "off: no waves")


func test_bonus_retreat_timers() -> void:
	var st := _fight(["P.....E"], { "bonusObjectives": true, "bonusCount": 3 })
	check(st.bonus_goals.size() == 3, "optional goals")
	st.bonus_goals = [{ "id": "a", "check": "no_down", "text": "a" }, { "id": "b", "check": "board", "n": 1, "text": "b" }]
	st.result = "win"
	var res: Array = Extras.bonus_results(st)
	check(bool(res[0]["done"]) and not bool(res[1]["done"]), "checked at the end")
	check(st.finish()["bonus"].size() == 2, "on the result screen")
	var no := _fight(["P.....E"])
	check(no.bonus_goals.is_empty(), "off: none")
	var ret := _fight(["P.....E"], { "retreat": true }, [], { "fleeAllowed": false })
	_ally(ret).cell = Vector2i(0, 0) if false else _ally(ret).cell
	for u in ret.units:
		if u.team == "party":
			ret.grid.exits.append(u.cell)
	check(ret.can_flee(), "retreat: the whole party on the exit")
	var nr := _fight(["P.....E"], {}, [], { "fleeAllowed": false })
	for u in nr.units:
		if u.team == "party":
			nr.grid.exits.append(u.cell)
	check(not nr.can_flee(), "off: no")
	var wat := _fight([".......", ".......", "P.....E"], { "envTimers": true }, [], { "timer": { "type": "rising_water", "row": 2, "stopRow": 1 } })
	check(wat.grid.env_warn.size() > 0, "water: warned tiles")
	var me := _me(wat)
	me.cell = Vector2i(0, 2)
	Extras.env_tick(wat)
	check(wat.grid.get_terrain(Vector2i(3, 2)) == GridScript.WATER and me.cell.y != 2, "a row floods; whoever's there is moved")
	var col := _fight(["P.....E", "......."], { "envTimers": true }, [], { "timer": { "type": "collapsing_floor", "tiles": 2 } })
	check(col.grid.env_warn.size() == 2, "collapse: telegraphed tiles")
	Extras.env_tick(col)
	check(col.grid.collapsing.size() == 2, "they start to go")
	var fi := _fight(["P.....E", "......."], { "envTimers": true }, [], { "timer": { "type": "spreading_fire", "col": 5, "stopCol": 2 } })
	Extras.env_tick(fi)
	check(fi.grid.burning.has(Vector2i(5, 1)), "fire spreads")
	check(Extras.active_line(fi).contains("fire"), "shown on the HUD")
	var ot := _fight(["P.....E", "......."], {}, [], { "timer": { "type": "spreading_fire", "col": 5 } })
	Extras.env_tick(ot)
	check(ot.env_timer.is_empty() and ot.grid.burning.is_empty(), "off: no clock")


func test_post_fight_and_relics() -> void:
	var picks := Extras.post_fight_cards(db(), seeded(1))
	check(picks.size() == 3 and picks[0] != picks[1], "1 of 3 new cards")
	check(db()["lab/board_relics"]["relics"].size() == 10, "10 board relics")
	var src := FileAccess.get_file_as_string("res://src/core/combat/combat_state.gd") + FileAccess.get_file_as_string("res://src/core/combat/extras.gd")
	for r in db()["lab/board_relics"]["relics"]:
		check(src.contains("\"%s\"" % r["id"]), "%s does something" % r["id"])
	var st := _fight(["P.E...#"], { "storyRelics": true, "collisionDamage": 2 }, [], { "labRelics": ["collision_plus", "surge_start"] })
	check(st.collision_damage(null) == 3, "a relic changes a rule")
	check(st.surge == 1, "Live Wire: start with Surge")
	var off := _fight(["P.E...#"], {}, [], { "labRelics": ["collision_plus"] })
	check(off.collision_damage(null) == 2, "off: no relics")


func test_plain_log() -> void:
	var st := _fight(["P.Ep..", "......"])
	var foe := _foe(st)
	_me(st).cell = Vector2i(1, 0)
	foe.cell = Vector2i(2, 0)
	st.take_events()
	st._push(_me(st), foe, Vector2i(1, 0), 1)
	var said := false
	for e in st.take_events():
		if str(e.get("t", "")) == "log" and str(e.get("text", "")).contains("into the pit"):
			said = true
	check(said, "plain words: pushed into the pit")
	var quiet := _fight(["P.Ep..", "......"], { "plainLog": false })
	var qf := _foe(quiet)
	_me(quiet).cell = Vector2i(1, 0)
	qf.cell = Vector2i(2, 0)
	quiet.take_events()
	quiet._push(_me(quiet), qf, Vector2i(1, 0), 1)
	var pushed_line := false
	for e in quiet.take_events():
		if str(e.get("text", "")).contains("pushed"):
			pushed_line = true
	check(not pushed_line, "off: no plain line")


func test_all_levers_together_do_not_crash() -> void:
	var levers := {}
	for s in Rules.lever_specs(db()):
		if s.get("type") == "bool" and str(s["group"]) in ["positioning", "spells", "enemies", "party", "structure", "rewards"] or str(s["id"]) in ["chooseOrder", "cardInitiative", "delay", "fightUpgrade", "statusCards", "signatureCard", "retainKeyword", "duetCards"]:
			levers[str(s["id"])] = true
	levers["zoneOfControl"] = "free_hit"
	levers["overload"] = "both"
	levers["downedRules"] = "carry"
	levers["bossLookahead"] = 2
	levers["reshuffleEffect"] = "surge"
	var st := _fight(["P.....E", "P.....E"], levers, [_enemy(), _enemy("hollow_mascot")], { "goal": { "type": "survive", "rounds": 3 } })
	var guard := 0
	while st.result == "" and guard < 200:
		guard += 1
		AI.take_turn(st, st.current)
	check(st.result != "", "a fight with everything on ends")

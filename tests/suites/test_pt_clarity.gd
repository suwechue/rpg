## PT Part 3: the rules behind the clarity fixes (numbered duplicates, bleed-out
## and Out, enemy action summaries in words, shape text on cards).
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")


func enemy(id: String) -> Dictionary:
	return DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)


func party_fight(classes: Array, enemies: Array) -> StateScript:
	var party: Array = []
	for i in classes.size():
		var ch := Char.create(db(), str(classes[i]), seeded(i + 1), { "id": "p%d" % i, "isPlayer": i == 0 })
		party.append({ "char": ch })
	return StateScript.new(db(), seeded(5), { "layout": { "map": ["PP......E", "P.......E", "........E"] }, "party": party, "enemies": enemies })


func test_duplicate_tags() -> void:
	var st := party_fight(["mage"], [enemy("pom_pom_wisp"), enemy("pom_pom_wisp"), enemy("detention_slip")])
	var tags: Array = []
	for u in st.units:
		if u.team == "enemy":
			tags.append(st.dup_index(u))
	check(tags == [1, 2, 0], "duplicates get numbers, the only one of its kind doesn't (%s)" % str(tags))
	check(st.display_name(st.units[2]).ends_with("2"), "Wisp 2")


func test_bleed_out() -> void:
	var st := party_fight(["mage", "healer", "fighter"], [enemy("pom_pom_wisp")])
	var ally = st.units[2]
	check(st.party_can_heal(), "the healer can heal")
	st._damage(ally, 999, null, "", "hit")
	check(ally.downed and ally.bleed == int(db()["stats"]["combat"]["bleedOutRounds"]), "downed allies get a bleed-out counter")
	st._end_round()
	st._end_round()
	check(ally.out and ally.dead, "not revived in time: out for this fight")
	var st2 := party_fight(["mage", "fighter"], [enemy("pom_pom_wisp")])
	for u in st2.units:
		if u.deck != null:
			u.deck.hand = []
			u.deck.draw_pile = ["card_dash"]
			u.deck.discard = []
	check(not st2.party_can_heal(), "no heals in any deck")
	st2._damage(st2.units[1], 999, null, "", "hit")
	check(st2.units[1].out, "nobody can heal: out at once")


func test_enemy_summaries() -> void:
	var st := party_fight(["mage"], [enemy("pom_pom_wisp"), enemy("pom_pom_wisp")])
	var e = st.units[1]
	var sm := st.action_summary(e, e.actions[0])
	check(str(sm["name"]) != "" and str(sm["shape"]) != "" and int(sm["range"]) >= 1 and int(sm["damage"]) > 0, "an action in words: name, shape, range, damage (%s)" % str(sm))
	e.intent = { "kind": "attack", "action": e.actions[0], "move": e.cell, "target": st.units[0].cell, "cells": [st.units[0].cell], "mode": "locked", "charge": 0 }
	var words := st.intent_words(e)
	check(words.contains(str(sm["name"])) and words.contains(st.units[0].name), "the plan in words names the attack and who it hits: %s" % words)


func test_card_shape_text() -> void:
	var burst := CardRules.make_spell(db(), { "heat": 1.0 }, "burst", "minor")
	check(CardRules.describe(db(), burst).contains("Plus shape, range 4"), "card text names the shape: %s" % CardRules.describe(db(), burst))
	var aura := CardRules.make_spell(db(), { "light": 1.0 }, "aura", "major")
	check(CardRules.describe(db(), aura).contains("around you"), "self shapes say so")

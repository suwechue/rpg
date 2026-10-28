## AR Part 3: every new card effect, rarity and upgrades, Tier 3 cards, and
## the rebuilt class starter decks.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const Effects := preload("res://src/core/combat/card_effects.gd")


func enemy(id: String, hp: int = 200) -> Dictionary:
	var e: Dictionary = DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)
	e["hp"] = hp
	e["maxHp"] = hp
	return e


## A fight where the player acts first, in move_and_act so tests can set up freely.
func fight(map: Array, enemies: Array, allies: int = 0) -> StateScript:
	var party: Array = [{ "char": Char.create(db(), "mage", seeded(1), { "isPlayer": true,
		"stats": { "str": 8, "dex": 40, "con": 8, "int": 8, "per": 40, "wil": 6, "cha": 4 } }) }]
	for i in allies:
		party.append({ "char": Char.create(db(), "healer", seeded(2 + i), { "id": "ally%d" % i, "name": "Ally %d" % i,
			"stats": { "str": 5, "dex": 30, "con": 8, "int": 6, "per": 30, "wil": 6, "cha": 4 } }) })
	var st := StateScript.new(db(), seeded(9), { "layout": { "map": map }, "party": party, "enemies": enemies, "turnMode": "move_and_act" })
	return st


func me(st: StateScript):
	for u in st.units:
		if u.is_player:
			return u
	return null


func unit_named(st: StateScript, id: String):
	for u in st.units:
		if u.id == id:
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


## Play a card by id at a target as the player; resets the action first.
func play(st: StateScript, id: String, target: Vector2i) -> bool:
	var p = me(st)
	p.action_used = false
	p.quick_used = false
	p.mp = 50
	p.deck.hand = [id]
	return st.play_card(p, 0, target)


func test_card_counts() -> void:
	var new := 0
	for key in ["cards/vector_cards", "cards/basic_cards", "cards/tier3_cards", "cards/class_cards"]:
		new += db()[key]["cards"].size()
	check(new >= 48, "at least 48 new cards (%d)" % new)
	var per := {}
	for c in db()["cards/vector_cards"]["cards"]:
		for v in c.get("vectors", {}):
			per[v] = int(per.get(v, 0)) + 1
	for v in ["heat", "cold", "force", "motion", "binding", "light"]:
		check(int(per.get(v, 0)) >= 7, "%s has about 8 cards (%d)" % [v, per.get(v, 0)])
	var t3 := {}
	for c in db()["cards/tier3_cards"]["cards"]:
		check(int(c.get("minTier", 0)) == 3, "%s needs Knowledge Tier 3" % c["id"])
		for v in c.get("vectors", {}):
			t3[v] = int(t3.get(v, 0)) + 1
	for v in ["transmutation", "vitality", "corrosion"]:
		check(int(t3.get(v, 0)) >= 3, "%s has 3 Tier 3 cards" % v)
	for key in ["cards/vector_cards", "cards/basic_cards", "cards/tier3_cards"]:
		for c in db()[key]["cards"]:
			check(["common", "uncommon", "rare"].has(str(c.get("rarity", ""))), "%s has a rarity" % c["id"])
			check(not CardRules.art_ids(db(), c).is_empty() and c.has("vfx") and c.has("sfx"), "%s names art, VFX and sound" % c["id"])
			check(CardRules.summary(db(), c).length() <= 11, "%s fits a one-line effect" % c["id"])


func test_upgrades() -> void:
	var up := CardRules.resolve(db(), "card_frost_bolt+")
	check(str(up["name"]) == "Frost Bolt+" and str(up["magnitude"]) == "major", "Frost Bolt+ is a Major Bolt")
	var shove := CardRules.resolve(db(), "card_shove+")
	check(int(shove["effects"][0]["steps"]) == 3, "Shove+ pushes 3")


func test_class_decks() -> void:
	var expect := { "fighter": ["card_intercept", "card_lunge", "card_parry", "card_brace", "card_taunt"], "rogue": ["card_hit_and_run", "card_shadow_step", "card_dash", "card_smoke_bomb"],
		"healer": ["card_ward", "card_mend", "card_guiding_light", "card_sanctuary", "card_cleanse"], "bard": ["card_haste", "card_tailwind", "card_dazzle", "card_encore"] }
	for c in db()["classes"]["classes"]:
		if int(c.get("tier", 1)) > 1:
			continue
		var deck := Char.create(db(), str(c["id"]), seeded(4))["deck"] as Array
		check(not deck.has("card_strike") and not deck.has("card_guard"), "%s: Strike and Guard are built-in Quicks, not cards (PT Part 1)" % c["id"])
		check(deck.size() >= int(db()["leveling"]["deckMin"]), "%s starts with at least the minimum deck (%d)" % [c["id"], deck.size()])
	for cls in expect:
		var ch := Char.create(db(), cls, seeded(4))
		for id in expect[cls]:
			check(ch["deck"].has(id), "%s starts with %s" % [cls, id])
	var f := Char.create(db(), "fighter", seeded(4))
	var movers := 0
	for id in f["deck"]:
		if bool(CardRules.resolve(db(), str(id)).get("moves", false)) or str(id) == "card_dash":
			movers += 1
	check(movers >= 2, "a melee class starts with at least two lunge or dash cards")


func test_heat_cards() -> void:
	var st := fight(["P........", "...E.....", "........."], [enemy("pom_pom_wisp")])
	check(play(st, "card_fire_wall", Vector2i(1, 0)), "Fire Wall")
	check(st.grid.fire_walls.has(Vector2i(2, 0)) and not st.grid.walkable_terrain(Vector2i(2, 0)), "Fire Wall blocks paths")
	check(play(st, "card_kindle", me(st).cell) and me(st).quick_used, "Kindle is quick")
	var ember := CardRules.make_spell(db(), { "heat": 1.0 }, "bolt", "minor")
	var normal := st._spell_spec(me(st), ember)
	check(float(normal["power"]) > CardRules.power(db(), ember), "Kindle empowers the next Heat card")
	st.grid.burning[foe(st).cell] = 2
	var hp: int = foe(st).hp
	check(play(st, "card_ignite", me(st).cell) and foe(st).hp < hp and st.grid.burning.is_empty(), "Ignite detonates burning tiles")
	check(play(st, "card_smoke_screen", Vector2i(2, 1)) and st.grid.steam.has(Vector2i(2, 1)), "Smoke Screen makes steam")
	me(st).statuses["slow"] = 1
	check(play(st, "card_cauterize", me(st).cell) and not me(st).statuses.has("slow") and st.grid.burning.has(me(st).cell), "Cauterize cleanses and burns your tile")
	var e = foe(st)
	st.grid.steam.clear()
	var zap := { "id": "zap", "name": "Zap", "form": "bolt", "power": 5, "vectors": { "heat": 1.0 } }
	e.intent = { "kind": "attack", "action": zap, "move": e.cell, "target": Vector2i(0, 0), "cells": [Vector2i(0, 0)], "mode": "locked", "charge": 0 }
	check(play(st, "card_heat_mirage", Vector2i(1, 1)) and e.intent["cells"] == [Vector2i(1, 1)], "Heat Mirage draws the telegraph to the decoy")
	var burst := CardRules.resolve(db(), "card_flashover")
	st.grid.burning[me(st).cell] = 2
	check(str(st._spell_spec(me(st), burst)["form"]["footprint"]) == "square_3x3", "Flashover grows on a burning tile")


func test_cold_cards() -> void:
	var st := fight(["P........", "...E.....", "........."], [enemy("pom_pom_wisp")])
	check(play(st, "card_flash_freeze", Vector2i(2, 1)), "Flash Freeze")
	check(st.grid.get_terrain(Vector2i(2, 1)) == GridScript.ICE, "it turns tiles to ice")
	var e = foe(st)
	var shatter := CardRules.resolve(db(), "card_shatter")
	var plain: float = st._expected_hit(me(st), e, st._spell_spec(me(st), shatter))
	e.statuses["slow"] = 1
	check(st._expected_hit(me(st), e, st._spell_spec(me(st), shatter)) > plain * 1.9, "Shatter doubles against Slowed")
	e.intent = { "kind": "attack", "action": e.actions[0], "move": e.cell, "target": Vector2i(0, 0), "cells": [Vector2i(0, 0)], "mode": "locked", "charge": 1 }
	check(play(st, "card_cold_snap", e.cell) and e.intent.is_empty(), "Cold Snap cancels the planned attack")
	check(play(st, "card_rime_armor", me(st).cell) and me(st).statuses.has("rime"), "Rime Armor")
	check(play(st, "card_hailstorm", Vector2i(4, 1)) and st.delayed.size() == 2, "Hailstorm telegraphs two waves")
	check(not st.threats().is_empty(), "hail shows as a threat for everyone")


func test_force_cards() -> void:
	var st := fight(["PE.......", "....E....", "........."], [enemy("pom_pom_wisp"), enemy("pom_pom_wisp")])
	var e = foe(st)
	check(play(st, "card_shove", e.cell) and e.cell == Vector2i(3, 0), "Shove pushes 2 (%s)" % str(e.cell))
	me(st).statuses["brace"] = 1
	st._push(foe(st, 1), me(st), Vector2i(0, 1), 2)
	check(me(st).cell == Vector2i(0, 0), "Brace stops pushes")
	me(st).statuses.erase("brace")
	check(play(st, "card_gravity_well", Vector2i(3, 1)), "Gravity Well")
	check(GridScript.manhattan(foe(st, 1).cell, Vector2i(3, 1)) <= 1, "pulls toward the center")
	st.grid.set_terrain(Vector2i(1, 2), GridScript.COVER)
	check(play(st, "card_breach", Vector2i(1, 2)) and st.grid.get_terrain(Vector2i(1, 2)) == GridScript.FLOOR, "Breach destroys cover")
	check(play(st, "card_hammerfall", foe(st, 1).cell) and st.delayed.size() == 1, "Hammerfall waits a round")
	var st2 := fight(["PE#......", "........."], [enemy("pom_pom_wisp")])
	check(play(st2, "card_pin", foe(st2).cell) and foe(st2).statuses.has("root"), "Pin against a wall Roots")
	var st3 := fight(["...PE....", "........."], [enemy("pom_pom_wisp")])
	check(play(st3, "card_recoil", foe(st3).cell) and me(st3).cell == Vector2i(2, 0), "Recoil pushes you back")


func test_motion_cards() -> void:
	var st := fight(["P........", "P...E....", "........."], [enemy("pom_pom_wisp")], 1)
	var ally = unit_named(st, "ally0")
	check(play(st, "card_haste", ally.cell) and ally.statuses.has("haste_full"), "Haste lets an ally move and act")
	var before: Vector2i = ally.cell
	check(play(st, "card_reposition", ally.cell) and ally.cell != before, "Reposition moves an ally (%s -> %s)" % [str(before), str(ally.cell)])
	check(play(st, "card_tailwind", me(st).cell) and ally.statuses.has("haste"), "Tailwind speeds everyone")
	check(play(st, "card_blink", Vector2i(2, 0)) and me(st).cell == Vector2i(2, 0), "Blink teleports")
	var e = foe(st)
	var ecell: Vector2i = e.cell
	check(play(st, "card_swap", ecell) and me(st).cell == ecell, "Swap trades places")
	var st2 := fight(["P........", "........."], [enemy("pom_pom_wisp")])
	check(play(st2, "card_afterimage", me(st2).cell) and me(st2).quick_used, "Afterimage is quick")
	st2.move(me(st2), Vector2i(2, 0))
	var decoy := false
	for u in st2.units:
		if u.is_prop() and u.name == "Decoy" and u.cell == Vector2i(0, 0):
			decoy = true
	check(decoy, "a decoy appears where you stood")
	var st3 := fight(["P..E.....", "........."], [enemy("pom_pom_wisp")])
	var hp: int = foe(st3).hp
	check(play(st3, "card_lunge", foe(st3).cell) and me(st3).cell == Vector2i(2, 0) and foe(st3).hp < hp, "Lunge closes in and strikes")


func test_binding_cards() -> void:
	var st := fight(["PE.......", "PE.......", "........."], [enemy("pom_pom_wisp"), enemy("pom_pom_wisp")], 1)
	var a = foe(st)
	var b = foe(st, 1)
	check(play(st, "card_tether", a.cell) and a.statuses.has("tether"), "Tether links two enemies")
	var hp: int = b.hp
	st._damage(a, 10, me(st), "", "hit")
	check(b.hp < hp, "hitting one hurts the other")
	var st_l := fight(["P..E.....", "........."], [enemy("pom_pom_wisp")])
	check(play(st_l, "card_leash", foe(st_l).cell) and foe(st_l).cell == Vector2i(1, 0), "Leash pulls next to you")
	var ally = unit_named(st, "ally0")
	ally.hp = 5
	check(play(st, "card_bind_wounds", ally.cell) and ally.statuses.has("regen"), "Bind Wounds")
	st._start_turn(ally)
	check(ally.hp > 5, "it heals at the start of their turn")
	check(play(st, "card_net", a.cell) and a.statuses.has("root"), "Net roots without damage")
	check(play(st, "card_pact", ally.cell) and me(st).statuses.has("pact"), "Pact")
	var mine: int = me(st).hp
	var theirs: int = ally.hp
	st._damage(me(st), 10, a, "", "hit")
	check(ally.hp < theirs and mine - me(st).hp == 5, "Pact splits the damage")


func test_light_cards() -> void:
	var st := fight(["P........", "...E.....", "........."], [enemy("pom_pom_wisp")], 1)
	var ally = unit_named(st, "ally0")
	ally.hp = 3
	check(play(st, "card_mend", ally.cell) and ally.hp > 3, "Mend heals")
	var e = foe(st)
	e.intent = { "kind": "attack", "action": e.actions[0], "move": e.cell, "target": ally.cell, "cells": [ally.cell], "mode": "locked", "charge": 0 }
	check(play(st, "card_beacon", me(st).cell) and me(st).statuses.has("taunting"), "Beacon taunts")
	check(play(st, "card_halo", me(st).cell) and me(st).shield > 0, "Halo shields")
	check(play(st, "card_dazzle", e.cell) and e.statuses.has("blind") and me(st).quick_used, "Dazzle is a quick blind")
	st.units.append(_burrowed(st))
	check(play(st, "card_reveal", me(st).cell) and st.revealed > 0, "Reveal")
	var st2 := fight(["P........", "E........", "........."], [enemy("pom_pom_wisp")])
	var hp: int = foe(st2).hp
	check(play(st2, "card_radiance", me(st2).cell) and foe(st2).hp < hp, "Radiance hurts adjacent enemies")


func _burrowed(st: StateScript):
	var u = foe(st)
	u.statuses["burrowed"] = 1
	return u


func test_basic_cards() -> void:
	var st := fight(["PE.......", "........."], [enemy("pom_pom_wisp")])
	check(play(st, "card_parry", me(st).cell) and me(st).statuses.has("parry"), "Parry")
	var e = foe(st)
	var hp: int = me(st).hp
	check(st.parried(e, me(st)) and me(st).hp == hp, "a parried melee hit is countered")
	check(play(st, "card_shove_basic", e.cell) and e.cell == Vector2i(2, 0), "Shoulder Shove pushes 1")
	var ehp: int = e.hp
	check(play(st, "card_throw", e.cell) and e.hp < ehp, "Throw hits at range")
	me(st).hp = 10
	check(play(st, "card_second_breath", me(st).cell) and me(st).hp > 10, "Second Breath heals")
	check(me(st).deck.exhausted.size() >= 1, "and is gone for the fight")
	check(play(st, "card_overwatch", Vector2i(4, 0)) and st.glyphs.size() == 1, "Overwatch watches a tile")
	check(play(st, "card_taunt", me(st).cell) and me(st).statuses.has("taunting"), "Taunt")


func test_tier3_cards() -> void:
	var st := fight(["P..hh....", "...E.....", "........."], [enemy("pom_pom_wisp")])
	check(play(st, "card_transmute_ground", Vector2i(3, 0)) and st.grid.get_terrain(Vector2i(3, 0)) == GridScript.FLOOR, "Transmute Ground fixes hazards")
	var e = foe(st)
	e.shield = 7
	check(play(st, "card_alchemize", e.cell) and e.shield == 0 and me(st).shield >= 7, "Alchemize steals a Shield")
	check(play(st, "card_toxic_pool", Vector2i(1, 2)) and st.grid.toxic.has(Vector2i(1, 2)), "Toxic Pool")
	check(play(st, "card_rust", e.cell) and e.defense_shred >= 4, "Rust shreds")


func test_effect_ops_are_all_used() -> void:
	var used := {}
	for key in ["cards/vector_cards", "cards/basic_cards", "cards/tier3_cards", "cards/class_cards"]:
		for c in db()[key]["cards"]:
			for e in c.get("effects", []):
				used[str(e["op"])] = true
	for op in Effects.OPS:
		if not ["burn_tiles", "dash"].has(op):
			check(used.has(op), "op %s is used by a card" % op)

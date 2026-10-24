## M3: grid combat rules, forms, effects, AI and the 2.5D projection.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const Forms := preload("res://src/core/combat/forms.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")
const Res := preload("res://src/core/combat/resolver.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const Proj := preload("res://src/scenes/combat/grid_projection.gd")


func layout(map: Array) -> Dictionary:
	return { "map": map }


func enemy(id: String) -> Dictionary:
	return DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)


func mage(seed_value: int = 1) -> Dictionary:
	return Char.create(db(), "mage", seeded(seed_value), { "knownVectors": ["heat", "force"], "isPlayer": true })


func fight(map: Array, party: Array, enemies: Array, seed_value: int = 7) -> StateScript:
	var p: Array = []
	for ch in party:
		p.append({ "char": ch })
	return StateScript.new(db(), seeded(seed_value), { "layout": layout(map), "party": p, "enemies": enemies })


func form(id: String) -> Dictionary:
	return DT.record(db(), "forms", id)


# --- Grid ------------------------------------------------------------------------

func test_grid_parse() -> void:
	var g := GridScript.new(layout(["<P.#.E", "<P.w.E", "<..x.E"]))
	check(g.cols == 6 and g.rows == 3, "size from map")
	check(g.party_spawns.size() == 2 and g.enemy_spawns.size() == 3, "spawns")
	check(g.exits.size() == 3, "exits")
	check(g.get_terrain(Vector2i(3, 0)) == "wall" and g.get_terrain(Vector2i(3, 1)) == "water", "terrain letters")
	check(g.prop_spawns.size() == 1, "crate prop")
	check(not g.walkable_terrain(Vector2i(3, 1)), "water is not walkable")


func test_los_reach_path() -> void:
	var g := GridScript.new(layout([".....", "..#..", "....."]))
	check(not g.has_los(Vector2i(0, 1), Vector2i(4, 1)), "wall blocks sight")
	check(g.has_los(Vector2i(0, 0), Vector2i(4, 0)), "clear row has sight")
	var r := g.reachable(Vector2i(0, 1), 2, {})
	check(r.has(Vector2i(1, 1)) and not r.has(Vector2i(2, 1)) and not r.has(Vector2i(3, 1)), "reach stops at walls and budget")
	var p := g.path(Vector2i(0, 1), Vector2i(4, 1), {})
	check(p.size() == 6 and p[-1] == Vector2i(4, 1), "path goes around the wall")
	g.steam[Vector2i(2, 0)] = 2
	check(not g.has_los(Vector2i(0, 0), Vector2i(4, 0)), "steam blocks sight")
	g.tick_round()
	g.tick_round()
	check(g.has_los(Vector2i(0, 0), Vector2i(4, 0)), "steam clears")


# --- Forms -----------------------------------------------------------------------

func test_all_eleven_footprints() -> void:
	var g := GridScript.new(layout([".........", ".........", ".........", ".........", "........."]))
	var me := Vector2i(4, 2)
	var occ := { Vector2i(7, 2): true }
	check(Forms.footprint(g, form("touch"), me, Vector2i(5, 2), occ) == [Vector2i(5, 2)], "touch")
	check(Forms.footprint(g, form("bolt"), me, Vector2i(8, 2), occ) == [Vector2i(8, 2)], "bolt")
	check(Forms.footprint(g, form("projectile"), me, Vector2i(8, 2), occ) == [Vector2i(7, 2)], "projectile stops at first unit")
	check(Forms.footprint(g, form("line"), me, Vector2i(5, 2), occ).size() == 4, "line 4 long")
	check(Forms.footprint(g, form("line"), me, Vector2i(4, 1), occ).size() == 2, "line clipped by the edge")
	check(Forms.footprint(g, form("burst"), me, Vector2i(6, 2), occ).size() == 9, "burst 3x3")
	check(Forms.footprint(g, form("sphere"), me, me, occ).size() == 12, "sphere diamond r2 without the caster")
	check(Forms.footprint(g, form("aura"), me, me, occ).size() == 9, "aura r1 zone")
	check(Forms.footprint(g, form("shield"), me, Vector2i(5, 3), occ) == [Vector2i(5, 3)], "shield one ally")
	check(Forms.footprint(g, form("weapon_infusion"), me, me, occ) == [me], "infusion self")
	check(Forms.footprint(g, form("construct"), me, Vector2i(5, 2), occ) == [Vector2i(5, 2)], "construct one tile")
	check(Forms.footprint(g, form("glyph"), me, Vector2i(6, 2), occ) == [Vector2i(6, 2)], "glyph one tile")
	var bolt_targets := Forms.valid_targets(g, form("bolt"), me, occ)
	check(not bolt_targets.has(me) and bolt_targets.has(Vector2i(8, 1)) and not bolt_targets.has(Vector2i(8, 0)), "bolt range is 5 by Manhattan distance")
	check(Forms.valid_targets(g, form("touch"), me, occ).size() == 4, "touch has 4 adjacent targets")
	check(Forms.valid_targets(g, form("glyph"), me, occ).size() > 0, "glyph targets empty tiles")


# --- Damage ------------------------------------------------------------------------

func test_contest_damage() -> void:
	var st := fight(["P...E"], [mage()], [enemy("bleacher_creeper")])
	var me: UnitScript = st.units[0]
	var creeper: UnitScript = st.units[1]
	var bolt := CardRules.make_spell(db(), { "heat": 1 }, "bolt", "standard")
	var spec := st._spell_spec(me, bolt)
	var aff := Res.affinity_bonus(db(), { "heat": 1 }, me)
	var expected := 10.0 * 1.0 * (1.0 + aff) * 1.5 * (1.0 - 0.02)
	check_near(st.expected_damage(me, creeper, spec), expected, "heat bolt vs heat-weak creeper (x1.5, 2% MR)")
	var bind := CardRules.make_spell(db(), { "force": 1 }, "bolt", "standard")
	check(st.expected_damage(me, creeper, st._spell_spec(me, bind)) < expected, "neutral force does less")
	check_near(Res.contest_mult(db(), { "heat": 0.5, "binding": 0.5 }, creeper), 0.5 * 1.5 + 0.5 * 0.6, "hybrid contest sums axes")


func test_instability_odds() -> void:
	check(not Res.needs_roll(2, 10, false), "cheap prepared card skips the roll")
	check(Res.needs_roll(6, 10, false), "prepared card over half MP rolls")
	check(Res.needs_roll(1, 30, true), "improvised always rolls")
	check_near(Res.instability_target(db(), 5, 10, true), 10.0 + 5.0 + 3.0, "target 10 + 10 x cost/MP + 3")
	check_near(Res.stability_chance(db(), 10, 5, 10, true), float(21 - 13) / 20.0, "chance with stability 10")
	check_near(Res.stability_chance(db(), 10, 2, 30, false), 1.0, "no roll means certain")


# --- Turn flow and effects --------------------------------------------------------------

func test_initiative_and_draw() -> void:
	var st := fight(["P...E", "P...E"], [mage(), Char.create(db(), "rogue", seeded(3))], [enemy("pom_pom_wisp"), enemy("locker_lurker")])
	var order := []
	for u in st.order:
		order.append(u.initiative)
	var sorted := order.duplicate()
	sorted.sort()
	sorted.reverse()
	check(order == sorted, "timeline sorted by initiative")
	var me: UnitScript = st.unit_by_id("player")
	check(me.deck.hand.size() == 5 or st.current == me and me.deck.hand.size() == 7, "opening hand 5, +2 on own turn")
	check(st.timeline(10).size() == 10, "timeline fills across rounds")


func test_shield_and_downed_vs_player_death() -> void:
	var ally := Char.create(db(), "fighter", seeded(2), { "id": "ally" })
	var st := fight(["P..E", "P..E"], [mage(), ally], [enemy("locker_lurker")])
	var a: UnitScript = st.unit_by_id("ally")
	a.shield = 5
	a.shield_turns = 2
	st._damage(a, 8, null, "", "test")
	check(a.hp == a.max_hp - 3, "shield absorbs first")
	st._damage(a, 999, null, "", "test")
	check(a.downed and st.result == "", "party member is downed, fight goes on")
	var me: UnitScript = st.unit_by_id("player")
	st._heal(me, a, 5)
	check(not a.downed and a.hp == 5, "healing revives a downed ally")
	st._damage(me, 999, null, "", "test")
	check(st.result == "lose", "player at 0 HP loses the run")


func test_push_collision_root_slow_burn() -> void:
	var st := fight(["P.E#", "...."], [mage()], [enemy("locker_lurker")])
	var me: UnitScript = st.unit_by_id("player")
	var lurker: UnitScript = st.units[1]
	var hp0 := lurker.hp
	st._push(me, lurker, Vector2i(1, 0), 2)
	check(lurker.cell == Vector2i(2, 0) and lurker.hp == hp0 - 4, "push into a wall: no move, collision damage")
	lurker.hp = hp0
	st._apply_vector_effects(me, { "vectors": { "binding": 1.0 }, "power": 10.0 }, [lurker.cell], [lurker])
	check(lurker.statuses.has("root"), "binding roots")
	st._apply_vector_effects(me, { "vectors": { "cold": 1.0 }, "power": 10.0 }, [lurker.cell], [lurker])
	check(lurker.statuses.has("slow"), "cold slows")
	st._apply_vector_effects(me, { "vectors": { "heat": 1.0 }, "power": 10.0 }, [Vector2i(1, 1)], [])
	check(st.grid.burning.has(Vector2i(1, 1)), "heat sets the tile burning")


func test_freeze_water_and_steam() -> void:
	var st := fight(["P.w.E"], [mage()], [enemy("pom_pom_wisp")])
	var me: UnitScript = st.unit_by_id("player")
	st._apply_vector_effects(me, { "vectors": { "cold": 1.0 }, "power": 10.0 }, [Vector2i(2, 0)], [])
	check(st.grid.get_terrain(Vector2i(2, 0)) == "ice" and st.grid.walkable_terrain(Vector2i(2, 0)), "cold freezes water into walkable ice")
	var st2 := fight(["P.w.E"], [mage()], [enemy("pom_pom_wisp")])
	st2._apply_vector_effects(me, { "vectors": { "heat": 1.0 }, "power": 10.0 }, [Vector2i(2, 0)], [])
	check(st2.grid.steam.has(Vector2i(2, 0)), "heat turns water to steam")


func test_play_card_spends_mp_and_carries_over() -> void:
	var ch := mage()
	ch["mp"] = 20
	var st := fight(["P..E"], [ch], [enemy("pom_pom_wisp")])
	var me: UnitScript = st.unit_by_id("player")
	if st.current != me:
		return
	var idx := -1
	for i in me.deck.hand.size():
		var c := st.card_of(me, i)
		if CardRules.is_spell(c) and str(c["form"]) == "bolt":
			idx = i
	if idx < 0:
		me.deck.hand.append("sp:heat:bolt:standard")
		idx = me.deck.hand.size() - 1
	var mp0 := me.mp
	var ok := st.play_card(me, idx, Vector2i(3, 0))
	check(ok, "bolt played at the enemy")
	check(me.mp == mp0 - 2, "MP spent")
	var summary := st.finish()
	check(int(ch["mp"]) == me.mp, "MP written back to the character (carries over)")
	check(summary["party"].size() == 1, "summary lists the party")


func test_improvise() -> void:
	var ch := mage()
	ch["mp"] = 30
	var st := fight(["P...E"], [ch], [enemy("pom_pom_wisp")])
	var me: UnitScript = st.unit_by_id("player")
	if st.current != me:
		return
	check(st.improvise_error(me, ["cold"], "bolt", "standard") != "", "unknown Vector rejected")
	me.perk_used = true
	var hand0: int = me.deck.hand.size()
	var mp0 := me.mp
	check(st.improvise(me, ["heat"], "bolt", "standard", 0, Vector2i(4, 0)), "improvised heat bolt")
	check(me.mp == mp0 - 4 and me.deck.hand.size() == hand0 - 1, "costs ceil(2 x 1.5) + 1 and a fuel card")


func test_overchannel() -> void:
	var ch := mage()
	ch["mp"] = 30
	var st := fight(["P...E"], [ch], [enemy("pom_pom_wisp")])
	var me: UnitScript = st.unit_by_id("player")
	var card := CardRules.make_spell(db(), { "heat": 1 }, "bolt", "standard")
	check(st.improvise_cost(me, card) == 2, "Overchannel: first improvise at normal cost")
	me.perk_used = true
	check(st.improvise_cost(me, card) == 4, "then the usual cost")


func test_flee() -> void:
	var st := fight(["<P.E"], [mage()], [enemy("pom_pom_wisp")])
	check(not st.can_flee(), "not on an exit yet")
	st.unit_by_id("player").cell = Vector2i(0, 0)
	check(st.can_flee(), "party on exit tiles can flee")
	check(st.flee() and st.result == "flee", "flee ends the fight")
	var boss := StateScript.new(db(), seeded(1), { "layout": layout(["<P.E"]), "party": [{ "char": mage() }], "enemies": [enemy("pom_pom_wisp")], "boss": true })
	check(not boss.can_flee(), "no fleeing boss fights")


func test_glyph_triggers() -> void:
	var st := fight(["P...E"], [mage()], [enemy("locker_lurker")])
	var me: UnitScript = st.unit_by_id("player")
	var lurker: UnitScript = st.units[1]
	var spec := st._spell_spec(me, CardRules.make_spell(db(), { "heat": 1 }, "glyph", "standard"))
	st._resolve_spec(me, spec, Vector2i(3, 0))
	check(st.glyphs.size() == 1, "glyph placed")
	var hp0 := lurker.hp
	st._enter_cell(lurker, Vector2i(3, 0))
	check(lurker.hp < hp0 and st.glyphs.is_empty(), "glyph fires on entry")


# --- AI ------------------------------------------------------------------------------

func test_ai_disposition_bias() -> void:
	var coward := { "courage": -80 }
	var brave := { "courage": 80 }
	var st := fight(["P...E"], [mage()], [enemy("pom_pom_wisp")])
	var retreat: Dictionary = db()["ai"]["retreat"]
	check(AI.profile_weight(st, coward, retreat) > AI.profile_weight(st, brave, retreat), "cowards like retreating")
	var adv: Dictionary = db()["ai"]["advance"]
	check(AI.profile_weight(st, brave, adv) > AI.profile_weight(st, coward, adv), "the brave like advancing")


func test_turn_start_deaths_end_the_fight() -> void:
	var st := fight(["P...E"], [mage()], [enemy("pom_pom_wisp")])
	var wisp = st.units[1]
	wisp.hp = 1
	st.grid.burning[wisp.cell] = 2
	var g := 0
	while st.result == "" and g < 10:
		st.end_turn()
		g += 1
	check(st.result == "win", "an enemy burning to death at the start of its turn ends the fight (%s after %d turns)" % [st.result, g])


func test_retreat_fades_in_long_fights() -> void:
	var st := fight(["P...E..", "......."], [mage()], [enemy("pom_pom_wisp")])
	var wisp = st.units[1]
	wisp.hp = 3
	wisp.move_left = 5
	st.current = wisp
	var early := 0.0
	for o in AI.options(st, wisp):
		if o["kind"] == "move" and o["profile"] == db()["ai"]["retreat"]:
			early = float(o["ev"])
	st.round_num = 20
	var late := 0.0
	for o in AI.options(st, wisp):
		if o["kind"] == "move" and o["profile"] == db()["ai"]["retreat"]:
			late = float(o["ev"])
	check(early > 0.0 and late < early * 0.2, "running away loses its appeal as a fight drags on (%.2f -> %.2f)" % [early, late])


func auto_fight(seed_value: int) -> Dictionary:
	var ally := Char.create(db(), "fighter", seeded(seed_value + 1), { "id": "ally" })
	var p := mage(seed_value)
	var st := StateScript.new(db(), seeded(seed_value), {
		"layout": DT.record(db(), "rooms/combat_layouts", "open_field"),
		"party": [{ "char": p, "ai": true }, { "char": ally, "ai": true }],
		"enemies": [enemy("pom_pom_wisp"), enemy("megaphone_mimic"), enemy("bleacher_creeper")] })
	var guard := 0
	while st.result == "" and guard < 400:
		AI.take_turn(st, st.current)
		guard += 1
	var s := st.finish()
	s["turns"] = guard
	return s


func test_full_auto_fight_is_deterministic() -> void:
	var a := auto_fight(99)
	var b := auto_fight(99)
	check(a["result"] != "", "fight ends (%s after %d turns)" % [a["result"], a["turns"]])
	check(JSON.stringify(a) == JSON.stringify(b), "same seed, same fight")
	var wins := 0
	for s in range(10):
		if auto_fight(1000 + s)["result"] == "win":
			wins += 1
	check(wins >= 5, "a 2-person party wins most starter fights on autopilot (%d/10)" % wins)


# --- Projection ------------------------------------------------------------------------

func test_projection_inverse() -> void:
	var proj = Proj.new(9, 5)
	var bad := 0
	for r in 5:
		for c in 9:
			var cell := Vector2i(c, r)
			if proj.to_cell(proj.cell_center(cell)) != cell:
				bad += 1
			var poly: PackedVector2Array = proj.cell_polygon(cell)
			for i in 4:
				var inner: Vector2 = poly[i].lerp(proj.cell_center(cell), 0.15)
				if proj.to_cell(inner) != cell:
					bad += 1
	check(bad == 0, "every cell center and inner corner maps back to its cell (%d misses)" % bad)
	check(proj.cell_polygon(Vector2i(0, 0))[1].x - proj.cell_polygon(Vector2i(0, 0))[0].x < proj.cell_polygon(Vector2i(0, 4))[1].x - proj.cell_polygon(Vector2i(0, 4))[0].x, "back rows are narrower")
	check(proj.cell_center(Vector2i(0, 0)).y < proj.cell_center(Vector2i(0, 4)).y, "back rows are higher on screen")
	check(proj.to_cell(Vector2(0, 0)) == Vector2i(-1, -1), "outside the grid is no cell")
	var ratio: float = proj.row_scale(3) / proj.row_scale(4)
	check(ratio >= 0.88 and ratio <= 0.92, "about 10% narrower per row back")

## AR Part 4: the 12 enemy behaviors, elite affixes, minions and palette swaps.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const EnemyMods := preload("res://src/core/combat/enemy_mods.gd")
const Spec := preload("res://src/core/assets/asset_specs.gd")
const CardRules := preload("res://src/core/card.gd")


func rec(id: String) -> Dictionary:
	return DT.index_under(db(), "enemies/", "enemies")[id].duplicate(true)


## The player first (very high initiative), move_and_act so tests can set up freely.
func fight(map: Array, enemies: Array) -> StateScript:
	var p := Char.create(db(), "mage", seeded(1), { "isPlayer": true, "stats": { "str": 8, "dex": 40, "con": 10, "int": 8, "per": 40, "wil": 6, "cha": 4 } })
	return StateScript.new(db(), seeded(3), { "layout": { "map": map }, "party": [{ "char": p }], "enemies": enemies, "turnMode": "move_and_act" })


func me(st: StateScript):
	for u in st.units:
		if u.is_player:
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


## Let the enemy at index i act its intent now.
func enemy_turn(st: StateScript, e) -> void:
	var guard := 0
	while st.current != e and st.result == "" and guard < 20:
		st.end_turn()
		guard += 1
	AI.take_turn(st, e)


func test_twelve_behaviors() -> void:
	var seen := {}
	for e in DT.records_under(db(), "enemies/", "enemies"):
		if e.has("behavior"):
			seen[str(e["behavior"])] = true
	check(seen.size() >= 12, "12 enemy behaviors in data (%d)" % seen.size())
	var minions := DT.records_under(db(), "enemies/", "enemies").filter(func(e: Dictionary) -> bool: return str(e.get("tier", "")) == "minion")
	for w in [1, 2, 3, 4, 5]:
		var n := minions.filter(func(e: Dictionary) -> bool: return e.get("weeks", []).has(float(w)) or e.get("weeks", []).has(w)).size()
		check(n >= 2, "week %d has at least 2 minion types (%d)" % [w, n])


func test_charger_runs_the_line() -> void:
	var st := fight([".........", "P.......E", "........."], [rec("hall_rusher")])
	var e = foe(st)
	var act: Dictionary = e.actions[0]
	var cells := st.pattern_cells(e, "charge_line", me(st).cell)
	check(cells.size() >= 7 and cells.has(Vector2i(1, 1)), "the charge line runs to the player")
	e.intent = { "kind": "special", "action": act, "move": e.cell, "target": me(st).cell, "cells": cells, "mode": "locked", "charge": 0 }
	var hp: int = me(st).hp
	enemy_turn(st, e)
	check(e.cell == Vector2i(1, 1) and me(st).hp < hp, "it runs the line, stops at the player and hits (%s)" % str(e.cell))


func test_bomber_blows_up() -> void:
	var st := fight([".........", "P.E......", "........."], [rec("firecracker_imp")])
	var e = foe(st)
	var act: Dictionary = e.actions[0]
	e.intent = { "kind": "special", "action": act, "move": e.cell, "target": e.cell, "cells": st.pattern_cells(e, "square_self", e.cell), "mode": "locked", "charge": 0 }
	me(st).cell = Vector2i(1, 1)
	var hp: int = me(st).hp
	enemy_turn(st, e)
	check(me(st).hp < hp and e.dead, "the bomber's 3x3 hits and it dies doing it")


func test_healer_heals_in_green() -> void:
	var st := fight(["P........", "......EE.", "........."], [rec("nurse_moth"), rec("hall_rusher")])
	var healer = foe(st)
	var hurt = foe(st, 1)
	hurt.hp = 5
	var heal := { "id": "patch_up", "name": "Patch Up", "form": "shield", "vectors": { "vitality": 1.0 }, "power": 8 }
	healer.intent = { "kind": "buff", "action": heal, "move": healer.cell, "target": hurt.cell, "cells": [hurt.cell] }
	check(st.support_cells().has(hurt.cell), "heal telegraphs are shown (green)")
	enemy_turn(st, healer)
	check(hurt.hp > 5, "the healer heals its ally")


func test_summoner() -> void:
	var st := fight(["P........", "......E..", "........."], [rec("locker_hive")])
	var e = foe(st)
	e.turns_taken = 2
	var plan := AI.plan_intent(st, e)
	check(bool(plan.get("summon", false)), "every 2 turns the summoner plans a summon")
	e.intent = plan
	var before := st.units.size()
	enemy_turn(st, e)
	check(st.units.size() == before + 1, "a minion appears")


func test_shield_bearer() -> void:
	var st := fight(["P........", ".....E...", "........."], [rec("riot_shield")])
	var e = foe(st)
	var spec := st._spell_spec(me(st), CardRules.make_spell(db(), { "heat": 1.0 }, "bolt", "standard"))
	e.facing = -1
	me(st).cell = Vector2i(2, 1)
	var front: float = st._expected_hit(me(st), e, spec)
	me(st).cell = Vector2i(7, 1)
	var back: float = st._expected_hit(me(st), e, spec)
	check(front < back * 0.4, "hits from the front are mostly blocked (%.1f vs %.1f)" % [front, back])


func test_burrower() -> void:
	var st := fight(["P........", "......E..", "........."], [rec("pothole")])
	var e = foe(st)
	var plan := AI.plan_intent(st, e)
	check(bool(plan.get("action", {}).get("burrow", false)), "away from you, it plans to burrow")
	e.intent = plan
	enemy_turn(st, e)
	check(e.statuses.has("burrowed") and bool(e.intent.get("action", {}).get("resurface", false)), "it burrows and telegraphs where it comes up")
	var hp: int = e.hp
	st._damage(e, 10, me(st), "", "hit")
	check(e.hp == hp, "burrowed, it can't be hurt")
	check(not st.opponents_of(me(st)).has(e), "and can't be targeted")
	var target: Vector2i = e.intent["target"]
	var php: int = me(st).hp
	enemy_turn(st, e)
	check(not e.statuses.has("burrowed") and GridScript.manhattan(e.cell, target) <= 1, "it resurfaces at the telegraphed tile")
	check(me(st).hp < php, "and hits whoever stayed there")


func test_sniper_charges() -> void:
	var st := fight(["P.......E", ".........", "........."], [rec("bell_tower_eye")])
	var e = foe(st)
	e.move_left = e.movement
	var plan := AI.plan_intent(st, e)
	check(int(plan.get("charge", 0)) == 1 or str(plan.get("kind", "")) != "special", "a sniper shot is telegraphed a turn ahead")


func test_splitter() -> void:
	var st := fight(["P........", ".....E...", "........."], [rec("split_slime")])
	var e = foe(st)
	st._damage(e, 999, me(st), "", "hit")
	var slimes := 0
	for u in st.units:
		if u.alive() and str(u.source.get("id", "")) == "slimelet":
			slimes += 1
	check(slimes == 2, "it splits into two Slimelets")


func test_hazard_maker_trail() -> void:
	var st := fight(["P........", "......E..", "........."], [rec("ember_crawler")])
	var e = foe(st)
	var from: Vector2i = e.cell
	e.intent = { "kind": "move", "move": Vector2i(4, 1), "cells": [] }
	enemy_turn(st, e)
	check(st.grid.burning.has(from), "it leaves burning ground behind")


func test_mirror_copies() -> void:
	var st := fight(["P........", "....E....", "........."], [rec("mirror_mime")])
	var p = me(st)
	p.deck.hand = ["sp:cold:bolt:standard"]
	p.mp = 20
	st.play_card(p, 0, foe(st).cell)
	var acts := AI._actions(st, foe(st))
	var mirrored := false
	for a in acts:
		if str(a.get("action", {}).get("id", "")) == "mirror" and a["action"]["vectors"].has("cold"):
			mirrored = true
	check(mirrored, "it can copy the last card you played")


func test_leech_drains_mp() -> void:
	var st := fight(["PE.......", ".........", "........."], [rec("static_leech")])
	var p = me(st)
	p.mp = 10
	var e = foe(st)
	st._hit_unit(e, p, st.action_spec(e, e.actions[0]), false)
	check(p.mp < 10, "it drains MP")


func test_anchor_roots() -> void:
	var st := fight(["PE.......", ".........", "........."], [rec("anchor_golem")])
	var e = foe(st)
	st._start_turn(e)
	check(me(st).statuses.has("root"), "the anchor roots everyone next to it")


func test_affixes() -> void:
	var base := rec("hall_rusher")
	base["affixes"] = ["hasted", "armored"]
	var r := EnemyMods.apply(db(), base)
	check(int(r["movement"]) == int(base["movement"]) + 2 and bool(r["moveAndAct"]), "Hasted: +2 Movement and move-and-act")
	check(int(r["physDefense"]) == int(base["physDefense"]) + 4, "Armored")
	var shielded := rec("hall_rusher")
	shielded["affixes"] = ["shielded", "explosive"]
	var st := fight(["P........", "PE.......", "........."], [shielded])
	var e = foe(st)
	check(e.shield > 0, "Shielded starts with a Shield")
	st._damage(e, 999, me(st), "", "hit")
	st._damage(e, 999, me(st), "", "hit")
	check(me(st).hp < me(st).max_hp, "Explosive hurts everyone next to it when it dies")
	var vamp := rec("hall_rusher")
	vamp["affixes"] = ["vampiric"]
	var st2 := fight(["PE.......", ".........", "........."], [vamp])
	var v = foe(st2)
	v.hp = 5
	st2._hit_unit(v, me(st2), st2.action_spec(v, v.actions[1]), false)
	check(v.hp > 5, "Vampiric heals from its hits")
	check(EnemyMods.roll(db(), 2, seeded(1)).size() == 2, "elites roll 2 distinct affixes")


func test_palette_swap() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var out := Spec.to_target(img, { "scale": 1, "tint": "#ff0000" })
	check(out.get_pixel(0, 0).is_equal_approx(Color.RED), "a tint palette-swaps pack art")
	check(Spec.spec(db(), "enemy_paper_wasp").has("tint"), "minions reuse pack sprites with a tint")

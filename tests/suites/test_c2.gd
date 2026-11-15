## Combat 2.0 (docs/COMBAT_2.md): turns and movement, kits, weaknesses and the
## knockdown chain, loadouts, and the slice.
extends "res://tests/suite.gd"

const C2Rules := preload("res://src/core/combat2/c2_rules.gd")
const Kits := preload("res://src/core/combat2/kits.gd")
const Shapes := preload("res://src/core/combat2/shapes.gd")
const C2Setup := preload("res://src/core/combat2/c2_setup.gd")
const C2AI := preload("res://src/core/combat2/c2_ai.gd")
const Perks := preload("res://src/core/combat2/perks.gd")


func _fight(id: String = "c2_first_down", opts: Dictionary = {}) -> Object:
	return C2Setup.state(db(), C2Setup.build(db(), id, opts))


func _unit(st: Object, id: String) -> Object:
	for u in st.units:
		if u.id == id:
			return u
	return null


func _enemies(st: Object) -> Array:
	return st.units.filter(func(u: Object) -> bool: return u.team == "enemy" and u.alive())


## Put a unit on a tile (clearing whoever stands there).
func _put(st: Object, u: Object, cell: Vector2i) -> void:
	var o: Object = st.unit_at(cell)
	if o != null and o != u:
		o.cell = Vector2i(-5, -5)
	u.cell = cell


## Make this unit the one acting now, with a fresh turn.
func _make_current(st: Object, u: Object) -> void:
	st.order.insert(st.turn_index + 1, u)
	st.current.links["c2_extra"] = "0"
	st.turn_index += 1
	st.current = u
	st._turn_reset(u)


# --- Part 1: turns and movement ----------------------------------------------------

func test_c2_levers_read() -> void:
	var r := C2Rules.build(db(), { "moveAfterAct": true, "nope": 3 })
	check(r.flag("moveAfterAct") and not r.levers.has("nope"), "levers read from data with changes on top; unknown ones are ignored")
	check(C2Rules.by_level("4@1,5@4,6@8", 1) == 4 and C2Rules.by_level("4@1,5@4,6@8", 6) == 5 and C2Rules.by_level("4@1,5@4,6@8", 12) == 6, "slot counts by level")
	check(C2Rules.reached("7,13", 6) == 0 and C2Rules.reached("7,13", 13) == 2, "upgrade levels reached")


func test_c2_timeline_order() -> void:
	var st := _fight()
	var tl: Array = st.c2_timeline(2)
	check(tl[0]["unit"].id == "c2_quill", "the fastest unit (Quill, Agility 8) acts first")
	var ids: Array = tl.filter(func(e: Dictionary) -> bool: return int(e["round"]) == st.round_num).map(func(e: Dictionary) -> String: return e["unit"].id)
	check(ids.find("c2_ash") < ids.find(_enemies(st)[0].id), "ties go to the party (Ash and the Gremlins both have 5)")
	check(tl.any(func(e: Dictionary) -> bool: return int(e["round"]) == st.round_num + 1), "the timeline shows the next round too")
	var g: Object = _enemies(st)[0]
	g.statuses["haste"] = 1
	st._build_order()
	check(st.order.find(g) < st.order.find(_unit(st, "c2_ash")), "Haste moves a unit up the order")
	g.statuses.erase("haste")
	_unit(st, "c2_quill").statuses["slow"] = 1
	st._build_order()
	check(st.order[0].id != "c2_quill", "Slow moves a unit down the order")


func test_c2_delay() -> void:
	var st := _fight()
	var later: Object = st.order[st.order.size() - 2]
	var i: int = st.order.find(later)
	st.delay_unit(later)
	check(st.order.find(later) == i + 1, "Delay: act after the next unit")


func test_c2_move_then_ability_ends_turn() -> void:
	var st := _fight()
	var q: Object = st.current
	check(q.id == "c2_quill", "Quill starts")
	var g: Object = _enemies(st)[0]
	_put(st, g, Vector2i(3, 0))
	_put(st, q, Vector2i(0, 0))
	q.move_left = 4
	check(st.move(q, Vector2i(2, 0)), "Move first")
	check(st.use_ability(q, "move:quill_stab", Vector2i(3, 0)), "then one Ability")
	check(st.current != q, "using the Ability ends the turn")


func test_c2_move_after_act_lever() -> void:
	var st := _fight("c2_first_down", { "c2Levers": { "moveAfterAct": true } })
	var q: Object = st.current
	var g: Object = _enemies(st)[0]
	_put(st, g, Vector2i(3, 0))
	_put(st, q, Vector2i(2, 0))
	q.move_left = 4
	st.use_ability(q, "move:quill_stab", Vector2i(3, 0))
	check(st.current == q and q.move_left > 0 and st.can_move(q), "moveAfterAct on: you may move after acting")
	var st2 := _fight()
	var q2: Object = st2.current
	var g2: Object = _enemies(st2)[0]
	_put(st2, g2, Vector2i(3, 0))
	_put(st2, q2, Vector2i(2, 0))
	st2.use_ability(q2, "move:quill_stab", Vector2i(3, 0))
	check(st2.current != q2, "moveAfterAct off: no walking away after the hit")


func test_c2_free_item() -> void:
	var st := _fight()
	var q: Object = st.current
	q.hp = 5
	check(st.use_item(q, 1), "an item (the Soda)")
	check(q.hp == 15 and st.current == q, "heals and doesn't end the turn")
	check(st.item_block(q, 0) != "", "one free item per turn")


func test_c2_brace() -> void:
	var st := _fight()
	var q: Object = st.current
	st.end_turn()
	check(q.statuses.has("braced"), "ending a turn with no Ability braces")
	var g: Object = _enemies(st)[0]
	var hit: Dictionary = g.source["moves"][0]
	var ab := Kits.ability(hit, "move")
	var braced: int = st.hit_result(g, q, ab)["amount"]
	q.statuses.erase("braced")
	var open: int = st.hit_result(g, q, ab)["amount"]
	check(braced < open, "a braced unit takes less damage (%d < %d)" % [braced, open])


func test_c2_facing_and_back_attacks() -> void:
	var st := _fight()
	var q: Object = st.current
	var g: Object = _enemies(st)[0]
	_put(st, g, Vector2i(4, 2))
	g.facing_dir = Vector2i(1, 0)
	var stab: Dictionary = st.ability_of(q, "move:quill_stab")
	_put(st, q, Vector2i(5, 2))
	var front: int = st.hit_result(q, g, stab)["amount"]
	_put(st, q, Vector2i(3, 2))
	var back: Dictionary = st.hit_result(q, g, stab)
	_put(st, q, Vector2i(4, 1))
	var side: Dictionary = st.hit_result(q, g, stab)
	check(st.facing_side(q, g) == "side" and bool(side["side"]), "from above it's a side attack")
	_put(st, q, Vector2i(3, 2))
	check(bool(back["back"]) and int(back["amount"]) > front and int(side["amount"]) > front and int(back["amount"]) > int(side["amount"]), "back > side > front")


func test_c2_threat_range() -> void:
	var st := _fight()
	var g: Object = _enemies(st)[0]
	var cells: Dictionary = st.threat_cells(g)
	check(cells.has(g.cell + Vector2i(-2, 0)) or cells.has(g.cell + Vector2i(-1, 0)), "an enemy's threat covers tiles it can walk to and hit")
	check(not cells.has(Vector2i(0, 5)) or g.movement >= 8, "and not the far side of the board")
	check(st.all_threat().size() >= cells.size(), "the toggle shows every enemy's threat")


func test_c2_data_checks() -> void:
	var Check: GDScript = load("res://src/core/combat2/c2_check.gd")
	var probs: Array = Check.problems(db())
	check(probs.is_empty(), "the C2 slice data is consistent: %s" % str(probs.slice(0, 3)))
	var d := db().duplicate(true)
	d["combat2/moves"]["moves"].append({ "id": "bad", "shape": "spiral", "type": "glitter", "target": "everyone" })
	check(Check.problems(d).size() >= 3, "a bad move is reported (shape, type, target)")


# --- Part 2: kits ---------------------------------------------------------------------

const Night := preload("res://src/core/combat2/night.gd")


func _rules(over: Dictionary = {}) -> C2Rules:
	return C2Rules.build(db(), over) as C2Rules


func test_c2_slots_by_level() -> void:
	var r := _rules()
	var s1 := Kits.slots(r, 1)
	var s6 := Kits.slots(r, 6)
	var s14 := Kits.slots(r, 14)
	check(int(s1["moves"]) == 4 and int(s1["spells"]) == 2 and int(s1["perks"]) == 1, "level 1: 4 moves, 2 spells, 1 perk")
	check(int(s6["moves"]) == 5 and int(s6["spells"]) == 4 and int(s6["perks"]) == 3, "level 6: 5 moves, 4 spells, 3 perks")
	check(int(s14["moves"]) == 7 and int(s14["spells"]) == 6 and int(s14["perks"]) == 5 and int(s14["ultimateUpgrades"]) == 2, "level 14: every slot")


func test_c2_charges() -> void:
	var r := _rules()
	check(Kits.charges_for(db(), r, { "magnitude": "Minor", "vectors": ["heat"] }) == 4, "Minor: 4")
	check(Kits.charges_for(db(), r, { "magnitude": "Standard", "vectors": ["heat"] }) == 3, "Standard: 3")
	check(Kits.charges_for(db(), r, { "magnitude": "Major", "vectors": ["heat"] }) == 2, "Major: 2")
	check(Kits.charges_for(db(), r, { "magnitude": "Grand", "vectors": ["heat"] }) == 1, "Grand: 1")
	check(Kits.charges_for(db(), r, { "magnitude": "Standard", "vectors": ["heat"], "grade": "great" }) == 4, "a great craft adds 1")
	check(Kits.charges_for(db(), r, { "magnitude": "Standard", "vectors": ["heat", "cold"] }) == 2, "multi-Vector: one fewer")
	check(Kits.charges_for(db(), r, { "magnitude": "Grand", "vectors": ["heat", "cold"] }) == 1, "never under 1")
	var fx := [{ "kind": "chargeMod", "mods": { "cold": 1, "heat": -1 } }]
	check(Kits.charges_for(db(), r, { "magnitude": "Standard", "vectors": ["cold"] }, fx) == 4 and Kits.charges_for(db(), r, { "magnitude": "Standard", "vectors": ["heat"] }, fx) == 2, "Cold Heart: +1 Cold, -1 Heat")
	check(Kits.charges_for(db(), _rules({ "chargesMinor": 6 }), { "magnitude": "Minor", "vectors": ["heat"] }) == 6, "charges per Magnitude are levers")


func test_c2_kit_build() -> void:
	var r := _rules()
	var k := Kits.build(db(), r, "c2_brick", 1, C2Setup.default_loadout(db(), "c2_brick", 1))
	check((k["moves"] as Array).size() == 4 and (k["spells"] as Array).size() == 2 and not (k["ultimate"] as Dictionary).is_empty(), "a level 1 kit: 4 moves, 2 spells, an ultimate")
	check(str(k["moves"][0]["type"]) == "blunt", "the bat makes the basic attack blunt")
	var spear := C2Setup.default_loadout(db(), "c2_brick", 1)
	spear["gear"]["weapon"] = "gw_spear"
	var ks := Kits.build(db(), r, "c2_brick", 1, spear)
	check(str(ks["moves"][0]["type"]) == "pierce" and str(ks["moves"][0]["shape"]) == "line", "a weapon sets the basic attack type and shape")
	var ash := Kits.build(db(), r, "c2_ash", 1, C2Setup.default_loadout(db(), "c2_ash", 1))
	check((ash["moves"] as Array).any(func(m: Dictionary) -> bool: return str(m["id"]) == "ash_arc" and bool(m.get("fromWeapon", false))), "a weapon can add one move")
	var k6 := Kits.build(db(), r, "c2_brick", 6, C2Setup.default_loadout(db(), "c2_brick", 6))
	check(float(k6["stats"]["movement"]) == 2.0 and (k6["resist"] as Array).has("pierce"), "heavy armor: -1 Movement, resists pierce")
	check(float(k6["stats"]["hp"]) > float(k["stats"]["hp"]), "levels add HP")
	var up := Kits.build(db(), r, "c2_ash", 13, C2Setup.default_loadout(db(), "c2_ash", 6))
	check(float(up["ultimate"]["power"]) > float(ash["ultimate"]["power"]) and int(up["ultimate"]["radius"]) > int(ash["ultimate"]["radius"]), "the ultimate upgrades at 7 and 13")


func test_c2_cooldowns() -> void:
	var st := _fight()
	var q: Object = st.current
	var g: Object = _enemies(st)[0]
	_put(st, g, Vector2i(3, 2))
	_put(st, q, Vector2i(1, 2))
	check(st.use_ability(q, "move:quill_shadow_step", Vector2i(3, 2)), "Shadow Step (cooldown 2)")
	check(int(st.cooldowns[q.id]["move:quill_shadow_step"]) == 3, "set for this turn plus 2 more")
	for i in 2:
		st.current = q
		st._start_turn(q)
		check(st.ability_block(q, st.ability_of(q, "move:quill_shadow_step")).begins_with("cooling"), "still cooling on own turn %d" % (i + 1))
	st.current = q
	st._start_turn(q)
	check(not st.ability_block(q, st.ability_of(q, "move:quill_shadow_step")).begins_with("cooling"), "ready on the third own turn")


func test_c2_every_shape() -> void:
	var st := _fight()
	var q: Object = st.current
	var g: Object = _enemies(st)[0]
	var n := 0
	for u in st.units:
		if u != q and u != g:
			n += 1
			u.cell = Vector2i(-6 - n, -6)
	_put(st, q, Vector2i(2, 2))
	_put(st, g, Vector2i(3, 2))
	var at: Vector2i = q.cell
	var mk := func(shape: String, extra: Dictionary = {}) -> Dictionary:
		var a := { "id": "t_" + shape, "uid": "t:" + shape, "shape": shape, "range": 2, "power": 1, "target": "tile" }
		a.merge(extra, true)
		return a
	check(Shapes.cells(st, q, mk.call("adjacent", { "target": "enemy" }), Vector2i(3, 2)).size() == 1, "adjacent: one tile")
	check(Shapes.cells(st, q, mk.call("line"), at + Vector2i(1, 0)).size() == 2, "line: range tiles in a row")
	check(Shapes.cells(st, q, mk.call("cone"), at + Vector2i(1, 0)).size() == 4, "cone 2: 1 then 3 tiles")
	check(Shapes.cells(st, q, mk.call("plus", { "radius": 1 }), Vector2i(4, 2)).size() == 5, "plus: the tile and its four neighbors")
	check(Shapes.cells(st, q, mk.call("burst", { "range": 1 }), at).size() == 4, "burst 1: the four tiles around you")
	check(Shapes.cells(st, q, mk.call("area", { "radius": 1 }), Vector2i(4, 3)).size() == 5, "area: a radius around the aimed tile")
	check(Shapes.cells(st, q, mk.call("self"), at) == [at], "self: you")
	check(Shapes.landing(st, q, g.cell, at) == Vector2i(4, 2), "leap: land behind the target")
	_put(st, q, Vector2i(0, 2))
	check(Shapes.dash_stop(st, q, q.cell, q.cell + Vector2i(1, 0), 4) == Vector2i(2, 2), "dash: stop next to the first enemy")
	_put(st, q, Vector2i(2, 2))
	check(Shapes.targets(st, q, mk.call("projectile", { "target": "enemy", "range": 4 })).has(g.cell), "projectile: an enemy in range and sight")
	var a := _unit(st, "c2_lyric")
	a.cell = Vector2i(2, 3)
	check(Shapes.targets(st, q, mk.call("ally", { "target": "ally", "heal": 3 })).has(a.cell), "ally: a friend in range")
	check(Shapes.cells(st, q, mk.call("plus_wide", { "range": 5 }), Vector2i(4, 2)).size() >= 9, "plus_wide: the row and column")


func test_c2_refills() -> void:
	var r := _rules()
	var kits: Array = []
	for cid in ["c2_ash", "c2_brick"]:
		kits.append(Kits.build(db(), r, cid, 1, C2Setup.default_loadout(db(), cid, 1)))
	var full := Night.home(kits)
	var fb := "spell:sp_fireball"
	check(int(full["c2_ash"]["charges"][fb]) == 3, "home refills every charge")
	var spent := full.duplicate(true)
	spent["c2_ash"]["charges"][fb] = 0
	spent["c2_ash"]["hp"] = 5
	var rested := Night.rest_room(spent, kits, r)
	check(int(rested["c2_ash"]["charges"][fb]) == 1 and int(rested["c2_ash"]["hp"]) > 5, "a rest room: +1 charge on each spell and some HP")
	check(int(Night.checkpoint(kits)["c2_ash"]["charges"][fb]) == 3, "an arena checkpoint refills too")
	check(int(Night.charge_use(full, spent)["spent"]) == 3, "charges spent across a night are counted")
	var st := _fight("c2_first_down", { "carry": spent })
	var ash := _unit(st, "c2_ash")
	check(int(st.charges_left["c2_ash"][fb]) == 0 and ash.hp == 5, "charges and HP carry into the next fight")
	_make_current(st, ash)
	check(st.ability_block(ash, st.ability_of(ash, fb)) == "no charges left", "an empty spell cannot be cast")
	check(st.use_item(ash, 0, fb) and int(st.charges_left["c2_ash"][fb]) == 1, "a Focus Snack restores a charge")


func test_c2_spell_spends_charge() -> void:
	var st := _fight()
	var ash := _unit(st, "c2_ash")
	_make_current(st, ash)
	for g in _enemies(st):
		g.cell = Vector2i(-7, -7)
	var g: Object = _enemies(st)[0]
	_put(st, g, ash.cell + Vector2i(3, 0))
	var before: int = st.charges_left["c2_ash"]["spell:sp_ice_lance"]
	check(st.use_ability(ash, "spell:sp_ice_lance", g.cell), "cast Ice Lance")
	check(int(st.charges_left["c2_ash"]["spell:sp_ice_lance"]) == before - 1, "a cast spends one charge")


# --- Part 3: weaknesses, knockdown, One More, Baton Pass, All-Out --------------------

## A first_down fight with Ash acting, both Gremlins in Ember range and in sight.
func _ash_vs_gremlins(opts: Dictionary = {}) -> Dictionary:
	var st := _fight("c2_first_down", opts)
	var ash := _unit(st, "c2_ash")
	var gs := _enemies(st)
	for u in st.units:
		if u.team == "party" and u != ash:
			u.cell = Vector2i(0, 5 - st.units.find(u) % 3)
	_put(st, ash, Vector2i(2, 2))
	_put(st, gs[0], Vector2i(4, 2))
	_put(st, gs[1], Vector2i(4, 4))
	_make_current(st, ash)
	return { "st": st, "ash": ash, "g1": gs[0], "g2": gs[1] }


func test_c2_markings() -> void:
	var f := _ash_vs_gremlins()
	var st: Object = f["st"]
	var ash: Object = f["ash"]
	var g: Object = f["g1"]
	var weak: Dictionary = st.hit_result(ash, g, st.ability_of(ash, "move:ash_ember"))
	var cold: Dictionary = st.hit_result(ash, g, st.ability_of(ash, "spell:sp_ice_lance"))
	var plain: Dictionary = st.hit_result(ash, g, st.ability_of(ash, "move:ash_spark"))
	check(str(weak["mark"]) == "weak" and bool(weak["knock"]), "Gremlins are weak to Heat: knockdown")
	check(str(cold["mark"]) == "resist" and not bool(cold["knock"]), "and resist Cold")
	check(str(plain["mark"]) == "" and not bool(plain["knock"]), "Lightning is neutral")
	var mite := Kits.rec(db(), "enemies", "enemies", "c2_mite")
	check(str(mite["marks"]["cold"]) == "immune", "Frost Mites are immune to Cold")
	var st2 := _fight("c2_wrong_answer")
	var m: Object = _enemies(st2).filter(func(e: Object) -> bool: return str(e.source.get("kind", "")) == "c2_mite")[0]
	var ash2 := _unit(st2, "c2_ash")
	check(int(st2.hit_result(ash2, m, st2.ability_of(ash2, "spell:sp_ice_lance"))["amount"]) == 0, "an immune hit does nothing")


func test_c2_reveal_rules() -> void:
	var f := _ash_vs_gremlins()
	var st: Object = f["st"]
	var ash: Object = f["ash"]
	var g: Object = f["g1"]
	check(st.known_of(g).is_empty() or st.known_of(g).size() == g.source["marks"].size(), "markings start unknown (or all known after the Lens perk)")
	st.known_marks = {}
	st.first_hits = { "%s|%s" % [ash.id, g.id]: true }
	st.use_ability(ash, "move:ash_spark", g.cell)
	check(st.known_of(g).has("lightning") and not st.known_of(g).has("heat"), "a hit reveals that type only")
	var st2 := _fight("c2_wrong_answer")
	var mask: Object = _enemies(st2).filter(func(e: Object) -> bool: return bool(e.source.get("hiddenMarks", false)))[0]
	var a2 := _unit(st2, "c2_ash")
	st2.known_marks = {}
	st2._learn(a2, mask, "sound", "weak")
	check(st2.known_of(mask).is_empty(), "the Mask reveals nothing when hit")
	st2.reveal_all(mask)
	check(st2.known_of(mask).size() == mask.source["marks"].size(), "a scan reveals every marking")
	var f3 := _ash_vs_gremlins({ "c2Levers": { "revealOnHit": false } })
	var st3: Object = f3["st"]
	st3.known_marks = {}
	st3.first_hits = { "%s|%s" % [f3["ash"].id, f3["g1"].id]: true }
	st3.use_ability(f3["ash"], "move:ash_spark", f3["g1"].cell)
	check(st3.known_of(f3["g1"]).is_empty(), "revealOnHit off: hits reveal nothing")
	var st4 := _fight("c2_first_down", { "known": { "c2_gremlin": { "heat": "weak" } } })
	check(str(st4.known_of(_enemies(st4)[0]).get("heat", "")) == "weak", "markings met before are remembered")


func test_c2_knockdown_and_one_more() -> void:
	var f := _ash_vs_gremlins()
	var st: Object = f["st"]
	var ash: Object = f["ash"]
	var g1: Object = f["g1"]
	var g2: Object = f["g2"]
	check(st.use_ability(ash, "move:ash_ember", g1.cell), "Ember a Gremlin")
	check(g1.statuses.has("knocked") and st.one_more.get("unit", "") == ash.id and st.current == ash, "weakness: knocked down, One More, still Ash's turn")
	check(ash.move_left == 0, "One More has no Move (oneMoreStep 0)")
	var down: int = st.hit_result(ash, g1, st.ability_of(ash, "move:ash_spark"))["amount"]
	g1.statuses.erase("knocked")
	var up: int = st.hit_result(ash, g1, st.ability_of(ash, "move:ash_spark"))["amount"]
	g1.statuses["knocked"] = 99
	check(down > up, "knocked-down units take more damage (%d > %d)" % [down, up])
	check(st.use_ability(ash, "spell:sp_fireball", g2.cell), "the extra Ability: Fireball the other Gremlin")
	check(g2.statuses.has("knocked") and st.one_more.is_empty() and int(st.one_mores_turn) == 1, "One More once per turn: no second one")
	var f2 := _ash_vs_gremlins({ "c2Levers": { "oneMoreStep": 2, "oneMoreChain": 2 } })
	f2["st"].use_ability(f2["ash"], "move:ash_ember", f2["g1"].cell)
	check(f2["ash"].move_left == 2, "oneMoreStep: a 2-tile step")
	f2["st"].use_ability(f2["ash"], "spell:sp_fireball", f2["g2"].cell)
	check(not f2["st"].one_more.is_empty(), "oneMoreChain 2: a second One More")


func test_c2_stand_up() -> void:
	var f := _ash_vs_gremlins()
	var st: Object = f["st"]
	var g: Object = f["g1"]
	g.statuses["knocked"] = 99
	st.current = g
	st._start_turn(g)
	check(not g.statuses.has("knocked") and st.must_skip(g), "standing up uses the turn")
	var f2 := _ash_vs_gremlins({ "c2Levers": { "standUp": "half" } })
	var g2: Object = f2["g1"]
	g2.statuses["knocked"] = 99
	f2["st"].current = g2
	f2["st"]._start_turn(g2)
	check(not f2["st"].must_skip(g2) and g2.links.has("c2_half"), "standUp half: it acts at half effect")
	var q := _unit(f2["st"], "c2_quill")
	var claw := Kits.ability(g2.source["moves"][0], "move")
	var half: int = f2["st"].hit_result(g2, q, claw)["amount"]
	g2.links.erase("c2_half")
	check(half < int(f2["st"].hit_result(g2, q, claw)["amount"]), "half effect hits softer")


func test_c2_baton_pass() -> void:
	var f := _ash_vs_gremlins()
	var st: Object = f["st"]
	var ash: Object = f["ash"]
	var q := _unit(st, "c2_quill")
	st.use_ability(ash, "move:ash_ember", f["g1"].cell)
	check(st.baton_block(ash, ash) != "", "you can't pass to yourself")
	var move_before: int = q.movement
	check(st.baton_pass(ash, q), "Baton Pass to Quill")
	check(st.current == q and is_equal_approx(float(q.links.get("c2_baton", "0")), 0.25), "Quill acts now with +25% damage")
	check(q.move_left == move_before + 1, "and +1 Movement")
	var base := Kits.ability({ "id": "x", "shape": "adjacent", "power": 10, "type": "blunt" }, "move")
	var with_bonus: int = st.hit_result(q, f["g2"], base)["amount"]
	q.links.erase("c2_baton")
	var without: int = st.hit_result(q, f["g2"], base)["amount"]
	q.links["c2_baton"] = "0.25"
	check(with_bonus > without, "the baton bonus adds damage")
	st.one_more = { "unit": q.id }
	var b := _unit(st, "c2_brick")
	st.baton_pass(q, b)
	check(is_equal_approx(float(b.links.get("c2_baton", "0")), 0.5), "passed again, the bonus stacks to +50%")
	st.one_more = { "unit": b.id }
	st.baton_pass(b, _unit(st, "c2_lyric"))
	check(float(_unit(st, "c2_lyric").links.get("c2_baton", "0")) <= 0.5 + float(Perks.value(st.kit_of(b), "batonPct")) + 0.001, "and caps at +50%")
	var f2 := _ash_vs_gremlins({ "c2Levers": { "batonGate": "bond", "labBondTier": "none" } })
	f2["st"].use_ability(f2["ash"], "move:ash_ember", f2["g1"].cell)
	check(f2["st"].baton_block(f2["ash"], _unit(f2["st"], "c2_quill")).begins_with("needs a Bond"), "batonGate bond: needs Acquaintance or higher")


func test_c2_all_out() -> void:
	var f := _ash_vs_gremlins()
	var st: Object = f["st"]
	var ash: Object = f["ash"]
	f["g2"].statuses["knocked"] = 99
	st.use_ability(ash, "move:ash_ember", f["g1"].cell)
	check(st.all_out_ready, "every enemy down: the All-Out is offered")
	var hp1: int = f["g1"].hp
	var far: Object = f["g2"]
	far.cell = Vector2i(7, 5)
	for a in st.allies_of(ash):
		a.cell = Vector2i(0, st.allies_of(ash).find(a))
	ash.cell = Vector2i(3, 2)
	var hp_far: int = far.hp
	check(st.all_out(ash), "launch it")
	check(f["g1"].hp < hp1 or not f["g1"].alive(), "enemies in reach take big damage")
	check(far.hp == hp_far, "enemies out of every ally's Movement + 1 are missed")
	check(not far.statuses.has("knocked"), "then every enemy stands up")
	var f2 := _ash_vs_gremlins()
	f2["g2"].statuses["knocked"] = 99
	f2["st"].use_ability(f2["ash"], "move:ash_ember", f2["g1"].cell)
	f2["st"].use_ability(f2["ash"], "move:ash_spark", f2["g1"].cell)
	check(f2["g2"].statuses.has("knocked"), "declining keeps the knockdowns")


func test_c2_bond_team_ups() -> void:
	var f := _ash_vs_gremlins({ "c2Levers": { "followUpChance": 1.0 } })
	var st: Object = f["st"]
	var q := _unit(st, "c2_quill")
	q.cell = f["g1"].cell + Vector2i(0, -1)
	st.use_ability(f["ash"], "move:ash_ember", f["g1"].cell)
	check(int(st.tally["followUps"]) == 1, "Friend: an ally next to a knocked-down enemy follows up")
	var f2 := _ash_vs_gremlins({ "c2Levers": { "labBondTier": "close" } })
	var st2: Object = f2["st"]
	var low := _unit(st2, "c2_lyric")
	low.hp = 2
	var g: Object = f2["g1"]
	var hit := Kits.ability({ "id": "big", "shape": "adjacent", "power": 30, "type": "blunt" }, "move")
	st2._hit(g, low, hit, low.cell)
	check(low.alive() and int(st2.tally["protects"]) == 1, "Close: an ally takes the killing blow once per fight")
	check(st2.c2.text("labBondTier") == "close" and Perks.bond_tier(st2) == 3, "the Lab sets the Bond tier by lever")


func test_c2_enemy_one_more() -> void:
	var st := _fight("c2_relay")
	var w: Object = _enemies(st).filter(func(e: Object) -> bool: return bool(e.source.get("huntsWeakness", false)))[0]
	var b := _unit(st, "c2_brick")
	_put(st, w, Vector2i(5, 3))
	_put(st, b, Vector2i(3, 3))
	st.order.insert(st.turn_index + 1, w)
	st.current.links["c2_extra"] = "0"
	st.turn_index += 1
	st.current = w
	st._turn_reset(w)
	var best := C2AI.best_action(st, w, 0)
	check(str(best.get("uid", "")) == "move:wi_zap", "the Wisp picks the move that hits Brick's weakness (Lightning)")
	st.use_ability(w, "move:wi_zap", b.cell)
	check(b.statuses.has("knocked") and st.one_more.get("unit", "") == w.id, "an enemy hitting a party weakness knocks down and gets One More")


func test_c2_ultimate_meter() -> void:
	var f := _ash_vs_gremlins()
	var st: Object = f["st"]
	var ash: Object = f["ash"]
	check(st.ability_block(ash, st.ability_of(ash, "ultimate:ult_inferno")).begins_with("ultimate not ready"), "the ultimate starts empty")
	st.use_ability(ash, "move:ash_ember", f["g1"].cell)
	check(int(st.meter[ash.id]) > 0, "dealing damage and knockdowns fill the meter")
	st.meter[ash.id] = st.c2.count("ultMax", 100)
	_make_current(st, ash)
	check(st.ability_block(ash, st.ability_of(ash, "ultimate:ult_inferno")) == "", "a full meter: the ultimate is ready")
	st.use_ability(ash, "ultimate:ult_inferno", f["g2"].cell)
	check(int(st.meter[ash.id]) < st.c2.count("ultMax", 100) and int(st.tally["ultimates"]) == 1, "using it empties the meter")

## Combat 2.0 (docs/COMBAT_2.md): turns and movement, kits, weaknesses and the
## knockdown chain, loadouts, and the slice.
extends "res://tests/suite.gd"

const C2Rules := preload("res://src/core/combat2/c2_rules.gd")
const Kits := preload("res://src/core/combat2/kits.gd")
const Shapes := preload("res://src/core/combat2/shapes.gd")
const C2Setup := preload("res://src/core/combat2/c2_setup.gd")
const C2AI := preload("res://src/core/combat2/c2_ai.gd")


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


## Everything the acting party member could do next, as plain steps
## (docs/LAB_TUNER.md Parts 2 and 5): the AI players search over them and
## tools/lab_play.gd numbers them. A step is { kind, ... }:
##   move/climb { cell }, card { hand, id, target, choice }, strike { target },
##   surge, gauge, delay, pick { unit }, together { target }, hold { hand },
##   reserve { unit }, end.
## Only what a player sees is used: the hand, the board, the telegraphs.
extends RefCounted

const LabOps := preload("res://src/core/combat/lab_ops.gd")
const Extras := preload("res://src/core/combat/extras.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")

const CHOICE_CAP := 4
const NEAR := 1            # a changed tile counts when someone stands this close
# Cards whose empty target tile still matters (they change the floor).
const TILE_OPS := ["board_anchor", "board_bridge", "board_collapse", "lab_move", "ally_setup"]


## Every step, unchecked (a step can still fail: apply says so).
## opts: { "moves": false } leaves out movement, { "extras": false } the rare buttons.
static func steps(st: Object, u: Object, opts: Dictionary = {}) -> Array:
	var out: Array = []
	if st.result != "" or u == null or u != st.current or not u.alive():
		return out
	if bool(opts.get("moves", true)) and st.can_move(u):
		var reach: Dictionary = st.reachable_cells(u)
		var cells: Array = reach.keys()
		cells.sort()
		for c in cells:
			if c != u.cell:
				out.append({ "kind": "move", "cell": c })
		for c in st.climb_targets(u):
			out.append({ "kind": "climb", "cell": c })
	if u.deck != null:
		var seen := {}
		for i in u.deck.hand.size():
			var card: Dictionary = st.card_of(u, i)
			var id := str(card.get("id", ""))
			if seen.has(id) or st.card_block(u, card) != "":
				continue
			seen[id] = true
			var choices: Array = [null]
			var kind := str(card.get("choose", ""))
			if kind in ["hand", "discard"]:
				var ids: Array = []
				for x in LabOps.choice_options(st, u, card, i):
					if not ids.has(str(x)):
						ids.append(str(x))
				ids.sort()
				if not ids.is_empty():
					choices = ids.slice(0, CHOICE_CAP)
			var tile_card := has_op(card, TILE_OPS)
			for t in st.card_targets(u, card):
				if not tile_card and not touches_something(st, u, card, t):
					continue
				for ch in choices:
					out.append({ "kind": "card", "hand": i, "id": id, "target": t, "choice": ch })
	if st.quick_block(u) == "":
		for t in st._adjacent_hostiles(u, 1):
			var o: Object = st.unit_at(t)
			if o != null and not o.is_prop():
				out.append({ "kind": "strike", "target": t })
	if st.can_surge(u):
		out.append({ "kind": "surge" })
	if Extras.gauge_full(st, u):
		out.append({ "kind": "gauge" })
	if bool(opts.get("extras", true)):
		if Extras.can_delay(st, u):
			out.append({ "kind": "delay" })
		for a in st.units:
			if Extras.can_pick_turn(st, a):
				out.append({ "kind": "pick", "unit": a.id })
		for t in st.together_targets(u):
			out.append({ "kind": "together", "target": t })
		if st.hold_block(u) == "" and u.deck != null:
			for i in u.deck.hand.size():
				out.append({ "kind": "hold", "hand": i, "id": str(u.deck.hand[i]) })
		if Extras.can_bring_reserve(st):
			for a in st.allies_of(u, true):
				if not a.is_player:
					out.append({ "kind": "reserve", "unit": a.id })
	out.append({ "kind": "end" })
	return out


## Whether a card aimed here reaches a unit or a prop, or changes a tile that
## reacts near someone: a spell at empty floor far from anyone does nothing
## worth listing.
static func touches_something(st: Object, u: Object, card: Dictionary, target: Vector2i) -> bool:
	if target == u.cell:
		return true
	var cells: Array = st.effect_cells(u, card, target)
	for c in cells:
		if st.unit_at(c) != null:
			return true
	for c in cells:
		var cell: Vector2i = c
		var special: bool = st.grid.get_terrain(cell) != GridScript.FLOOR
		for layer in [st.grid.oil, st.grid.wet, st.grid.gas, st.grid.burning, st.grid.toxic, st.grid.steam]:
			special = special or (layer as Dictionary).has(cell)
		if special:
			for x in st.units:
				if x.alive() and not x.is_prop() and GridScript.manhattan(x.cell, cell) <= NEAR:
					return true
	return false


## Carry out a step. False if the game refused it.
static func apply(st: Object, u: Object, step: Dictionary) -> bool:
	match str(step.get("kind", "")):
		"move":
			return st.move(u, step["cell"])
		"climb":
			return st.climb(u, step["cell"])
		"card":
			var i := int(step["hand"])
			if u.deck == null or i >= u.deck.hand.size() or str(u.deck.hand[i]) != str(step["id"]):
				i = u.deck.hand.find(str(step["id"])) if u.deck != null else -1
			if i < 0:
				return false
			st.card_choice = step.get("choice")
			return st.play_card(u, i, step["target"])
		"strike":
			return st.strike(u, step["target"])
		"surge":
			return st.spend_surge(u)
		"gauge":
			return Extras.spend_gauge(st, u)
		"delay":
			return Extras.delay(st, u)
		"pick":
			return Extras.pick_turn(st, st.unit_by_id(str(step["unit"])))
		"together":
			return st.cast_together(u, step["target"])
		"hold":
			return st.hold_card(u, int(step["hand"]))
		"reserve":
			return Extras.bring_reserve(st, st.unit_by_id(str(step["unit"])))
		"end":
			st.end_turn()
			return true
	return false


## What a step plays, without where it moved: "" for moves. Lines that play the
## same things count as one option (Part 3, real choices).
static func play_key(step: Dictionary) -> String:
	match str(step.get("kind", "")):
		"move", "climb", "end":
			return ""
		"card":
			return "%s@%d,%d%s" % [step["id"], step["target"].x, step["target"].y, "" if step.get("choice") == null else "#" + str(step["choice"])]
		"strike", "together":
			return "%s@%d,%d" % [step["kind"], step["target"].x, step["target"].y]
		"pick", "reserve":
			return "%s:%s" % [step["kind"], step["unit"]]
	return str(step.get("kind", ""))


static func line_key(line: Array) -> String:
	var parts: Array = []
	for s in line:
		var k := play_key(s)
		if k != "":
			parts.append(k)
	return "+".join(PackedStringArray(parts))


## The card a step plays ({} if none).
static func card_rec(st: Object, step: Dictionary) -> Dictionary:
	if str(step.get("kind", "")) != "card":
		return {}
	return CardRules.resolve(st.db, str(step["id"]), st.library)


static func has_op(card: Dictionary, ops: Array) -> bool:
	for e in card.get("effects", []):
		if ops.has(str(e.get("op", ""))):
			return true
	return false

## Card ops for the Lab's cards (docs/COMBAT_LAB.md Part 3): your discard pile, your
## deck, your teammates' decks and hands, and spells that shape the board. Numbers
## on these cards are already small: they go through rules.flat. `st` is the
## CombatState (untyped: it loads this script).
extends RefCounted

const Str := preload("res://src/core/strings.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const CardRules := preload("res://src/core/card.gd")
const Forms := preload("res://src/core/combat/forms.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")
const Board := preload("res://src/core/combat/board.gd")

const OPS := ["flat_hit", "board_push", "board_pull_area", "board_react", "board_collapse", "board_anchor", "board_toss", "board_bridge", "board_swap", "board_detonate",
	"discard_recall", "discard_echo", "discard_damage", "discard_burn", "discard_swap", "discard_shuffle",
	"deck_look", "deck_draw", "deck_discard", "deck_if_first_draw", "deck_search", "deck_stack",
	"ally_pass", "ally_borrow", "ally_setup", "ally_repush", "ally_encore", "ally_move_status",
	"lab_heal", "lab_shield", "lab_move", "lab_status"]

## Statuses Shared Burden can move.
const BURDENS := ["burning", "poisoned", "frozen", "wet", "weakened", "dazed", "slow", "root", "blind", "exposed", "marked"]


static func _n(st, card: Dictionary, fx: Dictionary, key: String = "n", fallback: float = 1.0) -> float:
	var v := float(fx.get(key, fallback))
	return v * 0.5 if bool(card.get("halved", false)) else v


## Pick an id from a pool: the player's choice if it's valid, or the default.
static func _pick(st, pool: Array, fallback_last: bool = true) -> String:
	if pool.is_empty():
		return ""
	var want: Variant = st.card_choice
	if want is Array and not (want as Array).is_empty():
		want = want[0]
	if pool.has(str(want)):
		return str(want)
	return str(pool[-1] if fallback_last else pool[0])


## A hit with a number written on the card, plus the combo chain.
static func flat_hit(st, u: UnitScript, t: UnitScript, amount: float, vector: String) -> void:
	if t == null or not t.alive():
		return
	var n: int = st.rules.flat(amount) + st._chain_bonus(u, t)
	st._emit({ "t": "area", "cells": [t.cell], "vectors": { vector: 1.0 } if vector != "" else { "force": 1.0 } })
	st._damage(t, n, u, vector, "hit")
	st._after_hit(u, t, n)


static func _flat_amount(st, u: UnitScript, card: Dictionary, fx: Dictionary, t: UnitScript) -> float:
	var n := _n(st, card, fx)
	if t != null and fx.has("vsStatus") and t.statuses.has(str(fx["vsStatus"])):
		n *= float(fx.get("mul", 2.0))
	return n


static func run(st, u: UnitScript, card: Dictionary, fx: Dictionary, target: Vector2i, cells: Array) -> void:
	var grid: GridScript = st.grid
	var t: UnitScript = st.unit_at(target)
	var deck = u.deck
	var self_id := str(card.get("id", ""))
	match str(fx.get("op", "")):
		"flat_hit":
			if t != null and st.is_hostile(u, t):
				var vector := str(fx.get("vector", ""))
				flat_hit(st, u, t, _flat_amount(st, u, card, fx, t), vector)
				if vector != "" and Board.on(st):
					Board.react(st, u, { vector: 1.0 }, [target])
		"board_push":
			var steps := roundi(_n(st, card, fx, "steps", 1.0))
			var victims: Array = []
			if str(fx.get("shape", "single")) == "line":
				var dir := Forms.direction_to(u.cell, target)
				var at := u.cell + dir
				for i in int(fx.get("reach", 4)):
					if not grid.in_bounds(at) or grid.get_terrain(at) == GridScript.WALL:
						break
					var o: UnitScript = st.unit_at(at)
					if o != null and o.alive():
						victims.append(o)
					at += dir
				victims.reverse()
				for v in victims:
					st.push_with(u, v, dir, steps, bool(fx.get("domino", false)))
			elif t != null and t.alive():
				st.push_with(u, t, Forms.direction_to(u.cell, t.cell), steps, bool(fx.get("domino", false)))
		"board_pull_area":
			var list: Array = st.opponents_of(u).filter(func(o: UnitScript) -> bool: return GridScript.manhattan(o.cell, target) <= int(fx.get("radius", 2)) and o.cell != target)
			list.sort_custom(func(a: UnitScript, b: UnitScript) -> bool: return GridScript.manhattan(a.cell, target) < GridScript.manhattan(b.cell, target))
			for o in list:
				st._push(u, o, Forms.direction_to(o.cell, target), int(fx.get("steps", 1)), false)
		"board_react":
			var area: Array = cells if not cells.is_empty() else [target]
			if bool(fx.get("wet", false)):
				for c in area:
					if grid.walkable_terrain(c):
						grid.wet[c] = int(Board.cfg(st).get("wetTurns", 3))
				st._emit({ "t": "tiles", "kind": "wet", "cells": area })
			if fx.has("vector"):
				Board.react(st, u, { str(fx["vector"]): 1.0 }, area)
		"board_collapse":
			if grid.walkable_terrain(target):
				grid.collapsing[target] = int(fx.get("rounds", 2))
				st._emit({ "t": "tiles", "kind": "collapse", "cells": [target] })
				st._emit({ "t": "log", "text": Str.t(st.db, "board.cracked") })
		"board_anchor":
			grid.anchors[target] = int(fx.get("rounds", 3))
			st._emit({ "t": "tiles", "kind": "anchor", "cells": [target] })
		"board_toss":
			var prop := prop_near(st, u, int(fx.get("reach", 1)))
			if prop != null and st.unit_at(target) == null and grid.walkable_terrain(target):
				var from: Vector2i = prop.cell
				prop.cell = target
				st._emit({ "t": "push", "unit": prop.id, "from": from, "to": target })
				prop.hp = 0
				st._on_zero_hp(prop, u)
		"board_bridge":
			if grid.get_terrain(target) in [GridScript.PIT, GridScript.WATER]:
				grid.bridges[target] = int(fx.get("rounds", 2))
				st._emit({ "t": "tiles", "kind": "bridge", "cells": [target] })
		"board_swap":
			var other_cell := Vector2i(-1, -1)
			if st.card_choice is Vector2i:
				other_cell = st.card_choice
			var other: UnitScript = st.unit_at(other_cell) if other_cell.x >= 0 else _swap_partner(st, u, t)
			if t != null and other != null and t != other and not bool(t.source.get("immovable", false)) and not bool(other.source.get("immovable", false)):
				var a: Vector2i = t.cell
				var b: Vector2i = other.cell
				t.cell = b
				other.cell = a
				st._emit({ "t": "blink", "unit": t.id, "from": a, "to": b })
				st._emit({ "t": "blink", "unit": other.id, "from": b, "to": a })
				st._shift_intent(t, b - a)
				st._shift_intent(other, a - b)
				st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.swapped") % [t.name, other.name] })
		"board_detonate":
			var dmg: int = st.rules.flat(_n(st, card, fx, "n", 2.0))
			for c in grid.burning.keys():
				if grid.burning.has(c):
					grid.burning.erase(c)
					Board.explode(st, u, c, dmg)
					grid.burning.erase(c)
		"discard_recall":
			var pool: Array = deck.discard.filter(func(id: Variant) -> bool: return str(id) != self_id)
			var got := _pick(st, pool)
			if got != "":
				deck.discard.erase(got)
				deck.hand.append(got)
				st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.recalled") % [u.name, _name(st, got)] })
		"discard_echo":
			var last := last_discard(st, u, self_id)
			if last != "":
				st.replay_card(u, CardRules.resolve(st.db, last, st.library), target, true)
		"discard_damage":
			var axis := str(fx.get("vector", ""))
			var count := 0
			var skipped := false
			for id in deck.discard:
				# This card is already in the pile; it doesn't count itself.
				if str(id) == self_id and not skipped:
					skipped = true
					continue
				if axis == "" or CardRules.resolve(st.db, str(id), st.library).get("vectors", {}).has(axis):
					count += 1
			if t != null and st.is_hostile(u, t):
				flat_hit(st, u, t, _n(st, card, fx) + _n(st, card, fx, "per", 1.0) * float(count), axis)
		"discard_burn":
			var burned := 0
			for i in range(deck.discard.size() - 1, -1, -1):
				if burned >= int(fx.get("max", 3)):
					break
				if str(deck.discard[i]) == self_id:
					continue
				deck.exhausted.append(deck.discard[i])
				deck.discard.remove_at(i)
				burned += 1
			if t != null and st.is_hostile(u, t):
				flat_hit(st, u, t, _n(st, card, fx) + _n(st, card, fx, "per", 2.0) * float(burned), str(fx.get("vector", "heat")))
		"discard_swap":
			var who: UnitScript = st.unit_by_id(str(st.last_motion_target.get(u.id, "")))
			if who != null and who.alive() and who != u:
				var a: Vector2i = u.cell
				u.cell = who.cell
				who.cell = a
				st._emit({ "t": "blink", "unit": u.id, "from": a, "to": u.cell })
				st._emit({ "t": "blink", "unit": who.id, "from": u.cell, "to": a })
				st._shift_intent(who, a - u.cell)
		"discard_shuffle":
			for id in deck.discard.duplicate():
				if str(id) != self_id:
					deck.discard.erase(id)
					deck.draw_pile.append(id)
			deck.shuffle_pile(st.rng)
			_draw(st, u, int(fx.get("n", 1)))
			st.note_reshuffle(u)
		"deck_look":
			# Put the chosen cards back on top, the first chosen on the very top.
			if st.card_choice is Array:
				var order: Array = st.card_choice
				var top_n: int = mini(int(fx.get("n", 3)), deck.draw_pile.size())
				var top: Array = deck.draw_pile.slice(deck.draw_pile.size() - top_n)
				var put: Array = order.filter(func(id: Variant) -> bool: return top.has(id))
				for id in top:
					if not put.has(id):
						put.append(id)
				for i in top_n:
					deck.draw_pile.pop_back()
				put.reverse()
				deck.draw_pile.append_array(put)
			st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.foresight") % u.name })
		"deck_draw":
			_draw(st, u, int(fx.get("n", 1)))
		"deck_discard":
			var pool: Array = deck.hand.duplicate()
			var drop := _pick(st, pool, false)
			if drop != "":
				deck.hand.erase(drop)
				deck.discard.append(drop)
				st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.discarded") % [u.name, _name(st, drop)] })
		"deck_if_first_draw":
			if int(u.played_turn) <= 1:
				_draw(st, u, int(fx.get("n", 1)))
		"deck_search":
			var tag := str(fx.get("tag", ""))
			for i in range(deck.draw_pile.size() - 1, -1, -1):
				var c := CardRules.resolve(st.db, str(deck.draw_pile[i]), st.library)
				if tag == "" or st.card_has_tag(c, tag):
					var id: Variant = deck.draw_pile[i]
					deck.draw_pile.remove_at(i)
					deck.hand.append(id)
					st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.searched") % [u.name, str(c.get("name", id))] })
					break
		"deck_stack":
			var chosen := _pick(st, deck.hand.duplicate(), false)
			if chosen != "":
				deck.hand.erase(chosen)
				deck.draw_pile.append(chosen)
				u.links["free_card"] = chosen
				st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.stacked") % [u.name, _name(st, chosen)] })
		"ally_pass":
			if t != null and t != u and t.team == u.team and t.deck != null:
				var given := _pick(st, deck.hand.duplicate(), false)
				if given != "":
					deck.hand.erase(given)
					t.deck.hand.append(given)
					st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.passed") % [u.name, _name(st, given), t.name] })
		"ally_borrow":
			if t != null and t != u and t.team == u.team and t.deck != null:
				if t.deck.draw_pile.is_empty():
					t.deck.draw(0, st.rng)
				if not t.deck.draw_pile.is_empty():
					var id := str(t.deck.draw_pile.pop_back())
					t.deck.discard.append(id)
					var c := CardRules.resolve(st.db, id, st.library)
					st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.borrowed") % [u.name, str(c.get("name", id)), t.name] })
					st.replay_card(u, c, Vector2i(-1, -1), false)
		"ally_setup":
			if t != null and t != u and t.team == u.team and t.deck != null:
				var chosen := _pick(st, deck.hand.duplicate(), false)
				if chosen != "":
					deck.hand.erase(chosen)
					t.deck.draw_pile.append(chosen)
					t.links["discount_card"] = chosen
					st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.setup") % [u.name, _name(st, chosen), t.name] })
		"ally_repush":
			if t != null and t.alive() and st.pushed_this_round.has(t.id):
				var dir: Vector2i = st.pushed_this_round[t.id]["dir"]
				if bool(st.pushed_this_round[t.id]["ally"]) or str(st.pushed_this_round[t.id]["by"]) != u.id:
					st._push(u, t, dir, int(fx.get("steps", 1)))
				st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.relay") % [u.name, t.name] })
		"ally_encore":
			if t != null and t != u and t.team == u.team and st.last_played.has(t.id):
				var last: Dictionary = st.last_played[t.id]
				var c := CardRules.resolve(st.db, str(last["id"]), st.library)
				st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.encore") % [t.name, str(c.get("name", ""))] })
				st.replay_card(t, c, last["target"], true)
		"ally_move_status":
			if t != null and t != u and t.team == u.team:
				var from: UnitScript = u
				var to: UnitScript = t
				var found := _burden(u)
				if found == "":
					from = t
					to = u
					found = _burden(t)
				if found != "":
					to.statuses[found] = from.statuses[found]
					from.statuses.erase(found)
					st._emit({ "t": "status", "unit": to.id, "status": found })
					st._emit({ "t": "log", "text": Str.t(st.db, "lab_card.burden") % [from.name, found, to.name] })
		"lab_heal":
			if t != null and t.team == u.team:
				st._heal(u, t, st.rules.flat(_n(st, card, fx)), false)
		"lab_shield":
			var who: UnitScript = t if t != null and t.team == u.team else u
			var amount: int = st.rules.flat(_n(st, card, fx))
			who.shield += amount
			who.shield_turns = maxi(who.shield_turns, 2)
			st._emit({ "t": "shield", "unit": who.id, "amount": amount })
		"lab_move":
			u.move_left += int(fx.get("n", 2))
			st._emit({ "t": "status", "unit": u.id, "status": "dash" })
		"lab_status":
			if t != null and t.alive() and not t.is_prop():
				st.add_status(t, str(fx.get("status", "")), int(fx.get("turns", -1)))


static func _name(st, id: String) -> String:
	return str(CardRules.resolve(st.db, id, st.library).get("name", id))


static func _draw(st, u: UnitScript, n: int) -> void:
	if u.deck == null:
		return
	u.deck.hand_limit = maxi(u.deck.hand_limit, u.deck.hand.size() + n)
	var drew: Dictionary = u.deck.draw(n, st.rng)
	st._emit({ "t": "log", "text": Str.t(st.db, "card_effects.draws") % [u.name, drew["drawn"].size()] })


static func _burden(u: UnitScript) -> String:
	for s in BURDENS:
		if u.statuses.has(s):
			return s
	return ""


## The partner when no second tile was chosen: an enemy standing in another's
## telegraph if there is one, otherwise the unit nearest the first.
static func _swap_partner(st, u: UnitScript, t: UnitScript) -> UnitScript:
	if t == null:
		return null
	var best: UnitScript = null
	var best_d := 999
	for o in st.units:
		if o == t or not o.alive() or o.is_prop():
			continue
		var d := GridScript.manhattan(o.cell, t.cell)
		if d < best_d:
			best_d = d
			best = o
	return best


static func prop_near(st, u: UnitScript, reach: int) -> UnitScript:
	for o in st.units:
		if o.is_prop() and not o.dead and GridScript.manhattan(o.cell, u.cell) <= reach:
			return o
	return null


static func last_discard(st, u: UnitScript, not_id: String) -> String:
	if u.deck == null:
		return ""
	for i in range(u.deck.discard.size() - 1, -1, -1):
		if str(u.deck.discard[i]) != not_id:
			return str(u.deck.discard[i])
	return ""


## Why a card can't be played right now under the levers and its needs, or "".
static func block(st, u: UnitScript, card: Dictionary) -> String:
	var group := str(card.get("group", ""))
	if group == "team" and not st.rules.flag("teammateCards", true):
		return Str.t(st.db, "lab_card.off_teammates")
	if group == "discard" and not st.rules.flag("discardCards", true):
		return Str.t(st.db, "lab_card.off_discard")
	var self_id := str(card.get("id", ""))
	for e in card.get("effects", []):
		match str(e.get("op", "")):
			"discard_recall", "discard_echo":
				if last_discard(st, u, self_id) == "":
					return Str.t(st.db, "lab_card.needs_discard")
			"discard_swap":
				var who: UnitScript = st.unit_by_id(str(st.last_motion_target.get(u.id, "")))
				if who == null or not who.alive():
					return Str.t(st.db, "lab_card.needs_motion")
			"board_toss":
				if prop_near(st, u, int(e.get("reach", 1))) == null:
					return Str.t(st.db, "lab_card.needs_prop")
	return ""


## The conditional Free cards: Harmony and Finisher.
static func free_if(st, u: UnitScript, card: Dictionary, target: Vector2i) -> bool:
	match str(card.get("freeIf", "")):
		"ally_vector":
			for a in st.allies_of(u):
				if a == u or not st.last_played.has(a.id):
					continue
				for axis in card.get("vectors", {}):
					if st.last_played[a.id].get("vectors", {}).has(axis):
						return true
		"target_moved":
			if target.x >= 0:
				var t: UnitScript = st.unit_at(target)
				return t != null and (st.pushed_this_round.has(t.id) or st.collided_this_round.has(t.id))
			for o in st.opponents_of(u):
				if st.pushed_this_round.has(o.id) or st.collided_this_round.has(o.id):
					return true
	return false


## What the player chooses when playing this card ("" for nothing), and the options.
static func choice_options(st, u: UnitScript, card: Dictionary, hand_index: int) -> Array:
	var kind := str(card.get("choose", ""))
	var ids: Array = []
	match kind:
		"discard":
			ids = u.deck.discard.duplicate()
		"hand":
			ids = u.deck.hand.duplicate()
			if hand_index >= 0 and hand_index < ids.size():
				ids.remove_at(hand_index)
		"top":
			var n := int(card.get("effects", [{}])[0].get("n", 3))
			ids = u.deck.draw_pile.slice(maxi(0, u.deck.draw_pile.size() - n))
			ids.reverse()
	return ids


## Exact results for the preview: hits, pushes, chain and tile reactions.
static func preview(st, u: UnitScript, card: Dictionary, target: Vector2i, out: Dictionary) -> void:
	var t: UnitScript = st.unit_at(target)
	var notes: Array = out.get("notes", [])
	var pushes: Array = out.get("pushes", [])
	var self_id := str(card.get("id", ""))
	for e in card.get("effects", []):
		var fx: Dictionary = e
		match str(fx.get("op", "")):
			"flat_hit":
				if t != null and st.is_hostile(u, t):
					out["hits"].append({ "unit": t.id, "damage": st.rules.flat(_flat_amount(st, u, card, fx, t)) + st._chain_bonus(u, t), "cover": 1.0 })
				if str(fx.get("vector", "")) != "":
					notes.append_array(Board.preview_lines(st, { str(fx["vector"]): 1.0 }, [target]))
			"board_push":
				var steps := int(fx.get("steps", 1))
				if str(fx.get("shape", "single")) == "line":
					var dir := Forms.direction_to(u.cell, target)
					var at := u.cell + dir
					var cells: Array = []
					for i in int(fx.get("reach", 4)):
						if not st.grid.in_bounds(at) or st.grid.get_terrain(at) == GridScript.WALL:
							break
						cells.append(at)
						var o: UnitScript = st.unit_at(at)
						if o != null and o.alive():
							pushes.append(st.push_landing(u, o, dir, steps, true))
						at += dir
					out["cells"] = cells
				elif t != null:
					pushes.append(st.push_landing(u, t, Forms.direction_to(u.cell, t.cell), steps, true))
			"board_pull_area":
				var cells: Array = []
				for c in st.grid.all_cells():
					if GridScript.manhattan(c, target) <= int(fx.get("radius", 2)):
						cells.append(c)
				out["cells"] = cells
				for o in st.opponents_of(u):
					if GridScript.manhattan(o.cell, target) <= int(fx.get("radius", 2)) and o.cell != target:
						pushes.append(st.push_landing(u, o, Forms.direction_to(o.cell, target), int(fx.get("steps", 1)), false))
			"board_react":
				var area: Array = st.effect_cells(u, card, target)
				out["cells"] = area
				if fx.has("vector"):
					notes.append_array(Board.preview_lines(st, { str(fx["vector"]): 1.0 }, area))
				if bool(fx.get("wet", false)):
					notes.append(Str.t(st.db, "board.preview_wet"))
			"board_collapse":
				notes.append(Str.t(st.db, "board.preview_collapse") % int(fx.get("rounds", 2)))
			"board_anchor":
				notes.append(Str.t(st.db, "board.preview_anchor") % int(fx.get("rounds", 3)))
			"board_bridge":
				notes.append(Str.t(st.db, "board.preview_bridge") % int(fx.get("rounds", 2)))
			"board_detonate":
				var n: int = st.rules.flat(float(fx.get("n", 2)))
				out["cells"] = st.grid.burning.keys()
				notes.append(Str.t(st.db, "board.preview_detonate") % [st.grid.burning.size(), n])
			"board_swap":
				var other: UnitScript = _swap_partner(st, u, t)
				if t != null and other != null:
					notes.append(Str.t(st.db, "lab_card.swapped") % [t.name, other.name])
			"discard_echo":
				var last := last_discard(st, u, self_id)
				if last != "":
					notes.append(Str.t(st.db, "lab_card.preview_echo") % _name(st, last))
			"discard_damage":
				var axis := str(fx.get("vector", ""))
				var count := 0
				for id in u.deck.discard:
					if axis == "" or CardRules.resolve(st.db, str(id), st.library).get("vectors", {}).has(axis):
						count += 1
				if t != null and st.is_hostile(u, t):
					out["hits"].append({ "unit": t.id, "damage": st.rules.flat(float(fx.get("n", 1)) + float(fx.get("per", 1)) * count) + st._chain_bonus(u, t), "cover": 1.0 })
			"discard_burn":
				if t != null and st.is_hostile(u, t):
					var burned: int = mini(int(fx.get("max", 3)), u.deck.discard.filter(func(id: Variant) -> bool: return str(id) != self_id).size())
					out["hits"].append({ "unit": t.id, "damage": st.rules.flat(float(fx.get("n", 1)) + float(fx.get("per", 2)) * burned) + st._chain_bonus(u, t), "cover": 1.0 })
			"ally_borrow":
				if t != null and t.deck != null and not t.deck.draw_pile.is_empty():
					notes.append(Str.t(st.db, "lab_card.preview_borrow") % [_name(st, str(t.deck.draw_pile[-1])), t.name])
			"ally_encore":
				if t != null and st.last_played.has(t.id):
					notes.append(Str.t(st.db, "lab_card.preview_encore") % [t.name, _name(st, str(st.last_played[t.id]["id"]))])
			"ally_repush":
				if t != null and st.pushed_this_round.has(t.id):
					pushes.append(st.push_landing(u, t, st.pushed_this_round[t.id]["dir"], int(fx.get("steps", 1)), true))
			"lab_heal":
				if t != null and t.team == u.team:
					out["hits"].append({ "unit": t.id, "heal": st.rules.flat(float(fx.get("n", 1))) })
	out["notes"] = notes
	out["pushes"] = pushes

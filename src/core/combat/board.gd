## The board as a weapon (docs/COMBAT_LAB.md Part 3b): what Vectors do to tiles,
## explosions, ledges, spills, collapses and bridges. Reads data/lab/reactions.json.
## `st` is the CombatState (untyped: it loads this script).
extends RefCounted

const Str := preload("res://src/core/strings.gd")
const GridScript := preload("res://src/core/combat/grid.gd")

const PLUS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func cfg(st) -> Dictionary:
	return st.db.get("lab/reactions", {})


static func on(st) -> bool:
	return st.rules.text("reactionsTable", "off") != "off"


static func prop_rec(db: Dictionary, kind: String) -> Dictionary:
	return db.get("lab/reactions", {}).get("props", {}).get(kind, {})


## The kind of a prop from its id ("barrel_2" -> "barrel").
static func kind_of(u: Object) -> String:
	var id := str(u.id)
	var parts := id.rsplit("_", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int():
		return parts[0]
	return id


## Every tile type standing on a cell: its terrain, overlays and a prop there.
static func types_at(st, c: Vector2i) -> Array:
	var grid: GridScript = st.grid
	var out: Array = []
	var ter := grid.get_terrain(c)
	if ter in [GridScript.WATER, GridScript.ICE]:
		out.append(ter)
	elif ter != GridScript.WALL and ter != GridScript.PIT and ter != GridScript.LEDGE:
		out.append("floor")
	if grid.oil.has(c):
		out.append("oil")
	if grid.gas.has(c):
		out.append("gas")
	if grid.wet.has(c):
		out.append("wet")
	var p: Object = st.unit_at(c)
	if p != null and p.is_prop():
		out.append(kind_of(p))
	return out


## The reaction ops a set of Vectors would run on these cells.
static func reactions(st, vectors: Dictionary, cells: Array) -> Array:
	var out: Array = []
	var table: Dictionary = cfg(st).get("tiles", {})
	for c in cells:
		for type in types_at(st, c):
			for axis in vectors:
				for op in table.get(str(type), {}).get(str(axis), []):
					out.append({ "cell": c, "op": op, "type": str(type), "axis": str(axis) })
	return out


## Run the table on these cells.
static func react(st, u: Object, vectors: Dictionary, cells: Array) -> void:
	for r in reactions(st, vectors, cells):
		apply(st, u, r["op"], r["cell"])


static func apply(st, u: Object, op: Dictionary, c: Vector2i) -> void:
	var grid: GridScript = st.grid
	match str(op.get("op", "")):
		"burn":
			if grid.walkable_terrain(c):
				grid.burning[c] = int(cfg(st).get("burnTurns", 2))
				st._emit({ "t": "tiles", "kind": "burning", "cells": [c] })
				if grid.oil.has(c):
					ignite(st, c)
		"steam":
			grid.steam[c] = int(cfg(st).get("steamTurns", 2))
			grid.wet.erase(c)
			st._emit({ "t": "tiles", "kind": "steam", "cells": [c] })
			_say(st, "board.steam")
		"terrain":
			var to := str(op.get("to", "floor"))
			grid.wet.erase(c)
			grid.set_terrain(c, to)
			st._emit({ "t": "tiles", "kind": to, "cells": [c] })
		"wet":
			grid.wet[c] = int(cfg(st).get("wetTurns", 3))
			st._emit({ "t": "tiles", "kind": "wet", "cells": [c] })
		"arc":
			arc(st, u, c, st.rules.flat(float(op.get("damage", 2))))
		"ignite":
			ignite(st, c)
		"explode":
			var p: Object = st.unit_at(c)
			if p != null and p.is_prop():
				p.hp = 0
				st._on_zero_hp(p, u)
			else:
				grid.gas.erase(c)
				explode(st, u, c, st.rules.flat(float(op.get("damage", cfg(st).get("gasDamage", 2)))))


static func _say(st, key: String, args: Array = []) -> void:
	st._emit({ "t": "log", "text": Str.t(st.db, key) % args if not args.is_empty() else Str.t(st.db, key) })


## Fire runs through connected oil.
static func ignite(st, c: Vector2i) -> void:
	var grid: GridScript = st.grid
	var frontier: Array = [c]
	var lit: Array = []
	while not frontier.is_empty():
		var at: Vector2i = frontier.pop_back()
		if not grid.oil.has(at):
			continue
		grid.oil.erase(at)
		grid.burning[at] = int(cfg(st).get("burnTurns", 2))
		lit.append(at)
		for d in GridScript.DIRS:
			frontier.append(at + d)
	if not lit.is_empty():
		st._emit({ "t": "tiles", "kind": "burning", "cells": lit })
		_say(st, "board.oil")


## Lightning runs through connected water and wet tiles.
static func arc(st, u: Object, c: Vector2i, damage: int) -> void:
	var grid: GridScript = st.grid
	var seen := {}
	var frontier: Array = [c]
	var hit: Array = []
	while not frontier.is_empty():
		var at: Vector2i = frontier.pop_back()
		if seen.has(at):
			continue
		seen[at] = true
		if grid.get_terrain(at) != GridScript.WATER and not grid.wet.has(at):
			continue
		var t: Object = st.unit_at(at)
		if t != null and t.alive() and t != u:
			hit.append(t)
		for d in GridScript.DIRS:
			frontier.append(at + d)
	if not hit.is_empty():
		_say(st, "board.arc")
	for t in hit:
		st._damage(t, damage, u, "lightning", "explosion")


## An explosion in a plus shape: everyone there takes it, and other barrels go too.
static func explode(st, u: Object, c: Vector2i, damage: int) -> void:
	var grid: GridScript = st.grid
	var cells: Array = []
	for d in PLUS:
		if grid.in_bounds(c + d) and grid.get_terrain(c + d) != GridScript.WALL:
			cells.append(c + d)
	st._emit({ "t": "area", "cells": cells, "vectors": { "heat": 1.0 } })
	_say(st, "board.explodes")
	for at in cells:
		var t: Object = st.unit_at(at)
		if t != null and t.alive():
			st._damage(t, damage, u, "heat", "explosion")
		if grid.walkable_terrain(at) and grid.get_terrain(at) != GridScript.WATER:
			grid.burning[at] = int(cfg(st).get("burnTurns", 2))
		if grid.oil.has(at):
			ignite(st, at)
		if grid.gas.has(at):
			grid.gas.erase(at)
			explode(st, u, at, damage)
	st._emit({ "t": "tiles", "kind": "burning", "cells": cells })


## A prop broke: barrels explode or spill by type.
static func on_prop_destroyed(st, p: Object, source: Object) -> void:
	var rec := prop_rec(st.db, kind_of(p))
	if bool(rec.get("explodes", false)):
		explode(st, source, p.cell, st.rules.flat(float(rec.get("damage", 3))))
	match str(rec.get("spill", "")):
		"oil":
			for d in PLUS:
				if st.grid.walkable_terrain(p.cell + d):
					st.grid.oil[p.cell + d] = 99
			st._emit({ "t": "tiles", "kind": "oil", "cells": [p.cell] })
			_say(st, "board.spill_oil")
		"wet":
			for d in PLUS:
				if st.grid.walkable_terrain(p.cell + d):
					st.grid.wet[p.cell + d] = int(cfg(st).get("wetTurns", 3))
			st._emit({ "t": "tiles", "kind": "wet", "cells": [p.cell] })
			_say(st, "board.spill_water")


## Pushed off a ledge: fall damage, and a landing below it.
static func ledge_fall(st, t: Object, ledge: Vector2i, dir: Vector2i) -> void:
	var from: Vector2i = t.cell
	var below: Vector2i = ledge + dir
	var land: Vector2i = below if st.grid.in_bounds(below) and st.grid.walkable_terrain(below) and st.unit_at(below) == null else st._free_near(ledge)
	t.cell = land
	st._emit({ "t": "push", "unit": t.id, "from": from, "to": land })
	st._emit({ "t": "log", "text": Str.t(st.db, "board.ledge") % t.name })
	st._shift_intent(t, land - from)
	st._damage(t, st.rules.count("fallDamage", 2), null, "", "fall")


## Round end: cracked tiles collapse, bridges fade.
static func on_round_end(st) -> void:
	var grid: GridScript = st.grid
	for c in grid.collapsing.keys():
		grid.collapsing[c] = int(grid.collapsing[c]) - 1
		if int(grid.collapsing[c]) <= 0:
			grid.collapsing.erase(c)
			grid.set_terrain(c, GridScript.PIT)
			st._emit({ "t": "tiles", "kind": "pit", "cells": [c] })
			_say(st, "board.collapse")
			var t: Object = st.unit_at(c)
			if t != null and t.alive():
				st._fall(t)
	for c in grid.bridges.keys():
		grid.bridges[c] = int(grid.bridges[c]) - 1
		if int(grid.bridges[c]) <= 0:
			grid.bridges.erase(c)
			st._emit({ "t": "tiles", "kind": "bridge", "cells": [c] })
			var t: Object = st.unit_at(c)
			if t != null and t.alive():
				if grid.get_terrain(c) == GridScript.PIT:
					st._fall(t)
				else:
					t.cell = st._free_near(c)
	for c in grid.anchors.keys():
		grid.anchors[c] = int(grid.anchors[c]) - 1
		if int(grid.anchors[c]) <= 0:
			grid.anchors.erase(c)


## Plain words for what a set of Vectors would do to tiles, for the preview.
static func preview_lines(st, vectors: Dictionary, cells: Array) -> Array:
	var out: Array = []
	for r in reactions(st, vectors, cells):
		var op: Dictionary = r["op"]
		if str(op.get("op", "")) == "burn":
			continue
		var line := Str.t(st.db, "board.preview_" + str(op.get("op", ""))) % [str(r["axis"]).capitalize(), str(r["type"]).replace("_", " ")]
		if not out.has(line):
			out.append(line)
	return out

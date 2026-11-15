## Combat 2.0 shapes (docs/COMBAT_2.md Part 2): which tiles an Ability can be
## aimed at, and which tiles it hits. Direction shapes (line, cone, dash) are
## aimed at the tile next to the user in that direction. Reads the state's grid
## and units; changes nothing.
extends RefCounted

const GridScript := preload("res://src/core/combat/grid.gd")
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRECTIONAL := ["line", "cone", "dash"]


static func dir_of(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := to - from
	if d == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(d.x) >= absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))


static func range_of(ab: Dictionary) -> int:
	return int(ab.get("range", 1))


## Every tile this Ability can be aimed at from `from` (default: where the user stands).
static func targets(st: Object, u: Object, ab: Dictionary, from: Vector2i = Vector2i(-99, -99)) -> Array:
	var at: Vector2i = u.cell if from.x == -99 else from
	var shape := str(ab.get("shape", "adjacent"))
	var reach := range_of(ab)
	var out: Array = []
	match shape:
		"self", "burst":
			out.append(at)
		"line", "cone", "dash":
			for d in DIRS:
				var c: Vector2i = at + d
				if st.grid.in_bounds(c) and (shape != "dash" or _dash_hit(st, u, at, d, reach) != null):
					out.append(c)
		"adjacent":
			for d in DIRS:
				var c: Vector2i = at + d
				if _wanted(st, u, ab, st.unit_at(c)):
					out.append(c)
		"ally":
			for a in st.units:
				if a.team == u.team and a.alive() and not a.is_prop() and GridScript.manhattan(a.cell, at) <= reach:
					if a != u or ab.has("heal") or ab.has("shield"):
						out.append(a.cell)
		"projectile", "leap":
			for t in st.units:
				if not _wanted(st, u, ab, t) or GridScript.manhattan(t.cell, at) > reach or t.cell == at:
					continue
				if shape == "projectile" and not st.grid.has_los(at, t.cell, _blockers(st, t, u)):
					continue
				if shape == "leap" and landing(st, u, t.cell, at) == Vector2i(-1, -1):
					continue
				out.append(t.cell)
		"area", "plus", "plus_wide":
			for c in st.grid.all_cells():
				if GridScript.manhattan(c, at) <= reach:
					out.append(c)
	return out


## The tiles the Ability hits when aimed at `target`.
static func cells(st: Object, u: Object, ab: Dictionary, target: Vector2i, from: Vector2i = Vector2i(-99, -99)) -> Array:
	var at: Vector2i = u.cell if from.x == -99 else from
	var shape := str(ab.get("shape", "adjacent"))
	var reach := range_of(ab)
	var out: Array = []
	match shape:
		"self":
			out.append(at)
		"burst":
			for c in st.grid.all_cells():
				var d := GridScript.manhattan(c, at)
				if d >= 1 and d <= reach:
					out.append(c)
		"line":
			var d := dir_of(at, target)
			for i in range(1, reach + 1):
				var c: Vector2i = at + d * i
				if not st.grid.in_bounds(c) or st.grid.get_terrain(c) == GridScript.WALL:
					break
				out.append(c)
		"cone":
			var d := dir_of(at, target)
			var side := Vector2i(d.y, d.x)
			for i in range(1, reach + 1):
				for w in range(-(i - 1), i):
					var c: Vector2i = at + d * i + side * w
					if st.grid.in_bounds(c):
						out.append(c)
		"dash":
			var hit: Object = _dash_hit(st, u, at, dir_of(at, target), reach)
			if hit != null:
				out.append(hit.cell)
		"area", "plus":
			var radius := int(ab.get("radius", 1))
			for c in st.grid.all_cells():
				if GridScript.manhattan(c, target) <= radius:
					out.append(c)
		"plus_wide":
			for c in st.grid.all_cells():
				if (c.x == target.x or c.y == target.y) and GridScript.manhattan(c, target) <= reach:
					out.append(c)
		_:
			out.append(target)
	return out


## Every tile this Ability could hit from `from`, whether or not anyone stands
## there now: the threat shown when hovering an enemy.
static func reach_cells(st: Object, u: Object, ab: Dictionary, from: Vector2i) -> Array:
	var shape := str(ab.get("shape", "adjacent"))
	var reach := range_of(ab)
	var out := {}
	match shape:
		"adjacent":
			for d in DIRS:
				if st.grid.in_bounds(from + d):
					out[from + d] = true
		"projectile", "leap":
			for c in st.grid.all_cells():
				var dist := GridScript.manhattan(c, from)
				if dist >= 1 and dist <= reach and (shape == "leap" or st.grid.has_los(from, c, {})):
					out[c] = true
		"ally", "self":
			pass
		_:
			for t in targets(st, u, ab, from):
				for c in cells(st, u, ab, t, from):
					out[c] = true
			if shape == "dash":
				for d in DIRS:
					for i in range(1, reach + 1):
						if st.grid.in_bounds(from + d * i):
							out[from + d * i] = true
	return out.keys()


## Where a leap lands: the far side of the target from the user, or the nearest
## free tile around it. (-1, -1) when there is none.
static func landing(st: Object, u: Object, target: Vector2i, from: Vector2i) -> Vector2i:
	var d := dir_of(from, target)
	var occ: Dictionary = st.occupied(u)
	var want: Vector2i = target + d
	if _free(st, want, occ):
		return want
	var best := Vector2i(-1, -1)
	var best_d := 99
	for dd in DIRS:
		var c: Vector2i = target + dd
		if _free(st, c, occ) and GridScript.manhattan(c, want) < best_d:
			best = c
			best_d = GridScript.manhattan(c, want)
	return best


## A dash: the first unit in that direction within reach, with a free tile before it.
static func _dash_hit(st: Object, u: Object, at: Vector2i, d: Vector2i, reach: int) -> Object:
	if d == Vector2i.ZERO:
		return null
	for i in range(1, reach + 1):
		var c: Vector2i = at + d * i
		if not st.grid.in_bounds(c) or st.grid.get_terrain(c) == GridScript.WALL:
			return null
		var o: Object = st.unit_at(c)
		if o != null and o != u:
			return o if o.alive() and st.is_hostile(u, o) else null
	return null


## Where a dash leaves the user: the tile before the unit it hits.
static func dash_stop(st: Object, u: Object, at: Vector2i, target: Vector2i, reach: int) -> Vector2i:
	var d := dir_of(at, target)
	var hit: Object = _dash_hit(st, u, at, d, reach)
	return at if hit == null else hit.cell - d


static func _free(st: Object, c: Vector2i, occ: Dictionary) -> bool:
	return st.grid.in_bounds(c) and st.grid.walkable_terrain(c) and not occ.has(c)


static func _wanted(st: Object, u: Object, ab: Dictionary, t: Object) -> bool:
	if t == null or t == u or not t.alive():
		return false
	if str(ab.get("target", "enemy")) == "ally":
		return t.team == u.team and not t.is_prop()
	return st.is_hostile(u, t) or (t.is_prop() and str(ab.get("shape", "")) != "leap")


static func _blockers(st: Object, t: Object, u: Object) -> Dictionary:
	var out: Dictionary = st.sight_blockers()
	out.erase(t.cell)
	out.erase(u.cell)
	return out

## Form footprints on the grid (DESIGN.md Section 9, "Forms on the grid").
## Pure functions over a CombatGrid. `occupied` maps cells to something truthy
## (units and props); `sight_blockers` are cells that block line of sight
## besides walls and steam (props such as constructs).
class_name CombatForms
extends RefCounted

const GridScript := preload("res://src/core/combat/grid.gd")


## Cells a caster may aim the Form at.
static func valid_targets(grid: GridScript, form: Dictionary, caster: Vector2i, occupied: Dictionary, sight_blockers: Dictionary = {}) -> Array:
	var out: Array = []
	var kind := str(form.get("target", "any"))
	var rng := int(form.get("range", 1))
	match kind:
		"self":
			out.append(caster)
		"direction":
			for dir in GridScript.DIRS:
				for step in range(1, rng + 1):
					var c: Vector2i = caster + dir * step
					if not grid.in_bounds(c) or grid.get_terrain(c) == GridScript.WALL:
						break
					out.append(c)
		"ally":
			for c in grid.all_cells():
				if GridScript.manhattan(c, caster) <= rng:
					out.append(c)
		"empty":
			for c in grid.all_cells():
				if c != caster and GridScript.manhattan(c, caster) <= rng and grid.walkable_terrain(c) and not occupied.has(c):
					if grid.has_los(caster, c, sight_blockers):
						out.append(c)
		_:
			var needs_los := str(form.get("footprint", "")) == "single_los"
			for c in grid.all_cells():
				var d := GridScript.manhattan(c, caster)
				if d < 1 or d > rng or grid.get_terrain(c) == GridScript.WALL:
					continue
				if needs_los and not grid.has_los(caster, c, sight_blockers):
					continue
				out.append(c)
	return out


## Cells the Form affects when aimed at `target`.
static func footprint(grid: GridScript, form: Dictionary, caster: Vector2i, target: Vector2i, occupied: Dictionary) -> Array:
	var out: Array = []
	match str(form.get("footprint", "")):
		"adjacent", "single_los", "ally_absorb_2_turns", "place_object_3_turns", "trap_tile":
			out.append(target)
		"self_next_2_strikes":
			out.append(caster)
		"first_in_line":
			var dir := direction_to(caster, target)
			for step in range(1, int(form.get("range", 7)) + 1):
				var c: Vector2i = caster + dir * step
				if not grid.in_bounds(c) or grid.blocks_sight(c):
					break
				if occupied.has(c):
					out.append(c)
					break
		"cone":
			# PT Part 7: widening 1-3-5 tiles over 3 rows from the caster.
			var cdir := direction_to(caster, target)
			var side := Vector2i(cdir.y, cdir.x)
			for depth in range(1, 4):
				for w in range(-(depth - 1), depth):
					var c: Vector2i = caster + cdir * depth + side * w
					if grid.in_bounds(c) and grid.get_terrain(c) != GridScript.WALL:
						out.append(c)
		"cleave":
			var kdir := direction_to(caster, target)
			var kside := Vector2i(kdir.y, kdir.x)
			for w in [-1, 0, 1]:
				var c: Vector2i = caster + kdir + kside * w
				if grid.in_bounds(c):
					out.append(c)
		"line":
			var dir := direction_to(caster, target)
			for step in range(1, int(form.get("range", 4)) + 1):
				var c: Vector2i = caster + dir * step
				if not grid.in_bounds(c) or grid.get_terrain(c) == GridScript.WALL:
					break
				out.append(c)
		"square_3x3":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c := target + Vector2i(dx, dy)
					if grid.in_bounds(c):
						out.append(c)
		"plus":
			for d in [Vector2i.ZERO] + GridScript.DIRS:
				var c: Vector2i = target + d
				if grid.in_bounds(c):
					out.append(c)
		"plus_self":
			for d in [Vector2i.ZERO] + GridScript.DIRS:
				var c: Vector2i = caster + d
				if grid.in_bounds(c):
					out.append(c)
		"diamond_r1_self":
			for d in GridScript.DIRS:
				var c: Vector2i = caster + d
				if grid.in_bounds(c):
					out.append(c)
		"ring_self":
			for c in grid.all_cells():
				if GridScript.manhattan(c, caster) == 2:
					out.append(c)
		"row":
			for x in grid.cols:
				out.append(Vector2i(x, target.y))
		"diamond_r2_self":
			for c in grid.all_cells():
				var d := GridScript.manhattan(c, caster)
				if d >= 1 and d <= 2:
					out.append(c)
		"zone_r1_self_3_turns":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c := caster + Vector2i(dx, dy)
					if grid.in_bounds(c):
						out.append(c)
		_:
			out.append(target)
	return out


## The Form as cast at a Magnitude: "footprintByMagnitude" in data/forms.json
## picks the area (Burst is a plus shape below Major, the full 3x3 from Major).
static func at_magnitude(form: Dictionary, magnitude: String) -> Dictionary:
	var by: Dictionary = form.get("footprintByMagnitude", {})
	if by.is_empty():
		return form
	var out := form.duplicate()
	out["footprint"] = str(by.get(magnitude if magnitude != "" else "standard", form.get("footprint", "")))
	return out


## The straight-line direction from a toward b (the larger axis wins; ties go horizontal).
static func direction_to(a: Vector2i, b: Vector2i) -> Vector2i:
	var d := b - a
	if d == Vector2i.ZERO:
		return Vector2i(1, 0)
	if absi(d.x) >= absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))

## The decorator (ROADMAP M12b): scatters small decorations (sprouts, shrubs,
## flowers) on ground tiles by the rules in data/world/decor_rules.json, never
## on blocked tiles or next to doors, spots and exits. Seeded, so re-running it
## gives the same result; the migration tool bakes the result into the zone
## scene's Decor layer, where it can be edited by hand.
extends RefCounted


## grounds: cell -> ground name; blocked and clear: cell -> true.
## Returns [{ "cell", "pack", "tile" }].
static func scatter(rules: Dictionary, grounds: Dictionary, blocked: Dictionary, clear: Dictionary, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var cells: Array = grounds.keys()
	cells.sort()
	var keep := int(rules.get("keepClear", 1))
	for c in cells:
		var cell: Vector2i = c
		if blocked.has(cell) or _near(cell, clear, keep):
			continue
		for r in rules.get("rules", {}).get(str(grounds[cell]), []):
			if rng.randf() < float(r.get("chance", 0.0)):
				out.append({ "cell": cell, "pack": str(r.get("pack", "town")), "tile": int(r.get("tile", 0)) })
				break
	return out


static func _near(cell: Vector2i, clear: Dictionary, keep: int) -> bool:
	for dy in range(-keep, keep + 1):
		for dx in range(-keep, keep + 1):
			if clear.has(cell + Vector2i(dx, dy)):
				return true
	return false

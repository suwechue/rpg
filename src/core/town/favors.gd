## The favor board (docs/TOWN_LIFE.md Part 3, data/town/favors.json): perWeek
## small jobs posted each week (seeded), each with hours, an AP cost, effects
## and the person it helps. Doing one takes it off the board.
extends RefCounted

const Locs := preload("res://src/core/town/locations.gd")


static func all(db: Dictionary) -> Array:
	return db.get("town/favors", {}).get("favors", [])


static func find(db: Dictionary, id: String) -> Dictionary:
	for f in all(db):
		if str(f.get("id", "")) == id:
			return f
	return {}


## This week's board (posted once per week).
static func board(db: Dictionary, run: Dictionary, week: int, rng: RandomNumberGenerator) -> Array:
	var b: Dictionary = run.get("favorBoard", {})
	if int(b.get("week", -1)) != week:
		var pool: Array = all(db).map(func(f: Dictionary) -> String: return str(f["id"]))
		var picks: Array = []
		while picks.size() < int(db.get("town/favors", {}).get("perWeek", 6)) and not pool.is_empty():
			picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		b = { "week": week, "ids": picks, "done": [] }
		run["favorBoard"] = b
	return b["ids"].filter(func(id: String) -> bool: return not b["done"].has(id))


## Favors on the board you can do in this part.
static func open_now(db: Dictionary, run: Dictionary, week: int, part: String, rng: RandomNumberGenerator) -> Array:
	return board(db, run, week, rng).filter(func(id: String) -> bool:
		return Locs.expand_hours(db, find(db, id).get("hours", [])).has(part))


static func complete(run: Dictionary, id: String) -> void:
	var b: Dictionary = run.get("favorBoard", {})
	var done: Array = b.get("done", [])
	if not done.has(id):
		done.append(id)
	b["done"] = done
	run["favorBoard"] = b

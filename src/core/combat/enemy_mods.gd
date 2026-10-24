## Elite affixes (docs/ARENA.md Part 4, data/enemy_affixes.json): a stronger
## base enemy plus 1 or 2 affixes. Pure: returns a changed copy of the record,
## which CombatUnit.from_enemy and CombatState read.
extends RefCounted


static func affix_table(db: Dictionary) -> Dictionary:
	return db.get("enemy_affixes", {}).get("affixes", {})


## The record with every affix in rec["affixes"] applied.
static func apply(db: Dictionary, rec: Dictionary) -> Dictionary:
	var out := rec.duplicate(true)
	for id in rec.get("affixes", []):
		var a: Dictionary = affix_table(db).get(str(id), {})
		for k in a.get("add", {}):
			out[k] = float(out.get(k, 0)) + float(a["add"][k])
		for k in a.get("set", {}):
			out[k] = a["set"][k]
		if a.has("actionVector"):
			for act in out.get("actions", []):
				var v: Dictionary = act.get("vectors", {})
				v[str(a["actionVector"])] = float(v.get(str(a["actionVector"]), 0.0)) + 0.5
				act["vectors"] = v
	return out


## Pick n distinct affixes for an elite with the run's rng (data order breaks ties).
static func roll(db: Dictionary, n: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = affix_table(db).keys()
	var out: Array = []
	for i in mini(n, pool.size()):
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out

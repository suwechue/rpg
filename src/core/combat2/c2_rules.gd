## Combat 2.0 levers (docs/COMBAT_2.md Part 5): every open question is a lever
## in data/combat2/rules.json, read through this view. Defaults first, then any
## changes for this fight. Pure data: no nodes, no autoloads.
extends RefCounted

var levers: Dictionary = {}
var changed: Dictionary = {}


static func table(db: Dictionary) -> Dictionary:
	return db.get("combat2/rules", {})


static func specs(db: Dictionary) -> Array:
	return table(db).get("levers", [])


static func defaults(db: Dictionary) -> Dictionary:
	var out := {}
	for s in specs(db):
		out[str(s["id"])] = s["default"]
	return out


static func build(db: Dictionary, overrides: Dictionary = {}) -> RefCounted:
	var r: RefCounted = (load("res://src/core/combat2/c2_rules.gd") as GDScript).new()
	r.levers = defaults(db)
	for k in overrides:
		if r.levers.has(k):
			r.levers[k] = overrides[k]
			r.changed[k] = overrides[k]
	return r


## The Combat Lab levers the slice runs on (the grid, board and props come from CL).
static func lab_levers(db: Dictionary) -> Dictionary:
	return (table(db).get("labLevers", {}) as Dictionary).duplicate()


static func base_preset(db: Dictionary) -> String:
	return str(table(db).get("basePreset", "cl_base"))


func flag(key: String, fallback: bool = false) -> bool:
	return bool(levers.get(key, fallback))


func num(key: String, fallback: float = 0.0) -> float:
	return float(levers.get(key, fallback))


func count(key: String, fallback: int = 0) -> int:
	return int(levers.get(key, fallback))


func text(key: String, fallback: String = "") -> String:
	return str(levers.get(key, fallback))


## "4@1,5@4,6@8" -> the value for this level (the last entry at or under it).
static func by_level(spec: String, level: int) -> int:
	var best := 0
	var best_at := -1
	for part in spec.split(",", false):
		var bits := part.strip_edges().split("@")
		if bits.size() != 2:
			continue
		var at := int(bits[1])
		if at <= level and at > best_at:
			best_at = at
			best = int(bits[0])
	return best


## "7,13" -> how many of these levels this level has reached.
static func reached(spec: String, level: int) -> int:
	var n := 0
	for part in spec.split(",", false):
		if int(part.strip_edges()) <= level:
			n += 1
	return n

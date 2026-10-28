## Vector combos (docs/VECTORS_DEMO.md Part 2): every pair of the six base
## Vectors, plus three-Vector combos, is a named spell in data/combos.json.
## A spell whose top Vectors match a combo runs its effects on top of its
## damage. Discoveries live in run["combos"] and the Journal.
extends RefCounted


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("combos", {})


static func all(db: Dictionary) -> Array:
	return cfg(db).get("combos", [])


static func find(db: Dictionary, id: String) -> Dictionary:
	for c in all(db):
		if str(c.get("id", "")) == id:
			return c
	return {}


## A stable key for a set of Vectors ("cold+heat").
static func key(axes: Array) -> String:
	var a: Array = axes.map(func(x: Variant) -> String: return str(x))
	a.sort()
	return "+".join(PackedStringArray(a))


## The Vectors that count toward a combo: weights of at least minShare of the
## strongest, strongest first (ties by the axis order in spaces.json).
static func active_axes(db: Dictionary, vectors: Dictionary) -> Array:
	var order: Array = db.get("spaces", {}).get("arcane", {}).get("axes", [])
	var top := 0.0
	for v in vectors.values():
		top = maxf(top, absf(float(v)))
	if top <= 0.0:
		return []
	var out: Array = []
	for axis in order:
		if absf(float(vectors.get(axis, 0.0))) >= top * float(cfg(db).get("minShare", 0.2)):
			out.append(axis)
	out.sort_custom(func(a: String, b: String) -> bool:
		var fa := absf(float(vectors[a]))
		var fb := absf(float(vectors[b]))
		return fa > fb or (fa == fb and order.find(a) < order.find(b)))
	return out


## The combo a spell's Vectors make: a three-Vector combo for the top three if
## one exists, else the pair of the top two. {} when there is none.
static func for_vectors(db: Dictionary, vectors: Dictionary) -> Dictionary:
	var axes := active_axes(db, vectors)
	if axes.size() < 2:
		return {}
	var tries: Array = []
	if axes.size() >= 3:
		tries.append(key(axes.slice(0, 3)))
	tries.append(key(axes.slice(0, 2)))
	for k in tries:
		for c in all(db):
			if key(c.get("vectors", [])) == k:
				return c
	return {}


## The combo for a pair of axes (the Compendium grid), or {}.
static func for_pair(db: Dictionary, a: String, b: String) -> Dictionary:
	var k := key([a, b])
	for c in all(db):
		if key(c.get("vectors", [])) == k:
			return c
	return {}


## Record a discovery in the run and the Journal's data. Returns true the
## first time this run.
static func discover(run: Dictionary, journal: Dictionary, id: String) -> bool:
	if id == "":
		return false
	var seen: Array = run.get("combos", [])
	var fresh := not seen.has(id)
	if fresh:
		seen.append(id)
		run["combos"] = seen
	var j: Array = journal.get("combos", [])
	if not j.has(id):
		j.append(id)
		journal["combos"] = j
	return fresh


static func discovered(run: Dictionary, journal: Dictionary, id: String) -> bool:
	return run.get("combos", []).has(id) or journal.get("combos", []).has(id)


## Problems in the combo table (DataDB and tests).
static func problems(db: Dictionary, ops: Array) -> Array:
	var out: Array = []
	var axes: Array = db.get("spaces", {}).get("arcane", {}).get("axes", [])
	var keys := {}
	for c in all(db):
		var id := str(c.get("id", "?"))
		var vs: Array = c.get("vectors", [])
		if vs.size() < 2 or vs.size() > 3:
			out.append("combo %s: needs 2 or 3 Vectors" % id)
		for v in vs:
			if not axes.has(v):
				out.append("combo %s: unknown Vector '%s'" % [id, v])
		var k := key(vs)
		if keys.has(k):
			out.append("combo %s: same Vectors as %s" % [id, keys[k]])
		keys[k] = id
		for e in c.get("effects", []):
			if not ops.has(str(e.get("op", ""))):
				out.append("combo %s: unknown op '%s'" % [id, e.get("op", "")])
	return out

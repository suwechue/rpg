## Search snapshots for the Lab players (docs/LAB_TUNER.md Part 2): save a whole
## fight, try a step, put it back. A search starts from a masked copy: every draw
## pile is sorted and the dice are reseeded from what's on the board, so a player
## can't learn the deck order or the next roll by trying things.
extends RefCounted

const SKIP_STATE := ["rules", "lab_log", "db", "rng", "forms", "events", "_ai", "_fx", "_undo", "undo_lock", "ai_overrides", "library", "_rubble_marker"]
# Fixed for a whole fight: copying them every step would only cost time.
const SKIP_UNIT := ["deck", "source", "actions", "phases", "known_vectors", "known_forms", "affinity", "disposition", "signature", "resist", "sprite"]

static var _names: Dictionary = {}


static func _props(o: Object, skip: Array) -> Array:
	var key: Variant = o.get_script()
	if _names.has(key):
		return _names[key]
	var out: Array = []
	for p in o.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and not skip.has(str(p["name"])):
			out.append(str(p["name"]))
	_names[key] = out
	return out


static func _copy(o: Object, skip: Array) -> Dictionary:
	var out := {}
	for n in _props(o, skip):
		var v: Variant = o.get(n)
		out[n] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return out


## Put values back, copying only what changed since (most of a fight doesn't).
static func _put(o: Object, data: Dictionary) -> void:
	for n in data:
		var v: Variant = data[n]
		if v is Dictionary or v is Array:
			var now: Variant = o.get(n)
			if typeof(now) != typeof(v) or now != v:
				o.set(n, v.duplicate(true))
		elif o.get(n) != v:
			o.set(n, v)


## The whole fight as data.
static func save(st: Object) -> Dictionary:
	var snap := { "state": _copy(st, SKIP_STATE), "grid": _copy(st.grid, []), "units": {}, "decks": {}, "rng": st.rng.state, "seed": st.rng.seed }
	for x in st.units:
		snap["units"][x] = _copy(x, SKIP_UNIT)
		if x.deck != null:
			snap["decks"][x] = _copy(x.deck, [])
	return snap


static func restore(st: Object, snap: Dictionary) -> void:
	_put(st, snap["state"])
	_put(st.grid, snap["grid"])
	for x in snap["units"]:
		_put(x, snap["units"][x])
	for x in snap["decks"]:
		_put(x.deck, snap["decks"][x])
	st.rng.seed = int(snap["seed"])
	st.rng.state = int(snap["rng"])
	st.events = []


## A number from what anyone can see: the round, whose turn, where everyone is.
static func visible_hash(st: Object) -> int:
	var parts: Array = [st.round_num, st.turn_index, st.current.id if st.current != null else ""]
	for x in st.units:
		parts.append([x.id, x.cell, x.hp, x.alive()])
	return hash(str(parts))


## Enter a search. Returns the real fight (to put back with finish) and the
## masked start every try begins from.
static func begin(st: Object) -> Dictionary:
	var real := save(st)
	var ctx := { "real": real, "log": st.lab_log, "events": st.events.duplicate() }
	st.lab_log = null
	for x in st.units:
		if x.deck != null:
			x.deck.draw_pile.sort()
	st.rng.seed = visible_hash(st)
	ctx["root"] = save(st)
	return ctx


static func finish(st: Object, ctx: Dictionary) -> void:
	restore(st, ctx["real"])
	st.lab_log = ctx["log"]
	st.events = ctx["events"]

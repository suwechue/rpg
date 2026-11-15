## Combat 2.0 slice fights (docs/COMBAT_2.md Part 5): a fight from
## data/combat2/fights.json at level 1 or 6, with each character's loadout, as
## the setup C2State takes. Pure data: no nodes, no autoloads.
extends RefCounted

const Kits := preload("res://src/core/combat2/kits.gd")
const C2Rules := preload("res://src/core/combat2/c2_rules.gd")


static func fights(db: Dictionary) -> Array:
	return db.get("combat2/fights", {}).get("fights", [])


static func fight(db: Dictionary, id: String) -> Dictionary:
	for f in fights(db):
		if str(f.get("id", "")) == id:
			return f
	return {}


static func nights(db: Dictionary) -> Array:
	return db.get("combat2/fights", {}).get("nights", [])


static func night(db: Dictionary, id: String) -> Dictionary:
	for n in nights(db):
		if str(n.get("id", "")) == id:
			return n
	return {}


## A character's stored loadout for this level: the highest stored level at or under it.
static func default_loadout(db: Dictionary, char_id: String, level: int) -> Dictionary:
	var stored: Dictionary = Kits.character(db, char_id).get("loadouts", {})
	var best := -1
	for k in stored:
		if int(k) <= level and int(k) > best:
			best = int(k)
	if best < 0 and not stored.is_empty():
		best = int(stored.keys()[0])
	return (stored.get(str(best), {}) as Dictionary).duplicate(true)


## opts: { level, loadouts: { char id: loadout }, c2Levers, labLevers, seed, carry, known, items, bondTier }.
static func build(db: Dictionary, fight_id: String, opts: Dictionary = {}) -> Dictionary:
	var f := fight(db, fight_id)
	var level := int(opts.get("level", f.get("level", 1)))
	var rules: C2Rules = C2Rules.build(db, opts.get("c2Levers", {})) as C2Rules
	var party: Array = []
	var chosen: Dictionary = opts.get("loadouts", {})
	for cid in f.get("party", []):
		var lo: Dictionary = chosen.get(str(cid), default_loadout(db, str(cid), level))
		party.append(Kits.build(db, rules, str(cid), level, lo))
	var setup := {
		"layout": { "map": f.get("map", []), "theme": str(f.get("theme", "school")), "props": f.get("props", []) },
		"party": party,
		"enemies": (f.get("enemies", []) as Array).duplicate(),
		"level": level,
		"seed": int(opts.get("seed", f.get("seed", 1))),
		"boss": bool(f.get("boss", false)),
		"fleeAllowed": false,
		"c2Levers": opts.get("c2Levers", {}),
		"labLevers": opts.get("labLevers", {}),
		"carry": opts.get("carry", {}),
		"known": opts.get("known", {}),
		"items": opts.get("items", ["it_focus_snack", "it_soda", "it_smelling_salts"]),
		"c2": { "fight": fight_id, "level": level },
		"context": "lab",
	}
	if opts.has("bondTier"):
		setup["bondTier"] = str(opts["bondTier"])
	return setup


## A fresh fight state for this setup (the dice are seeded from the setup's seed).
static func state(db: Dictionary, setup: Dictionary) -> Object:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(setup.get("seed", 1))
	var S: GDScript = load("res://src/core/combat2/c2_state.gd")
	return S.new(db, rng, setup)

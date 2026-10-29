## The living town (ROADMAP M17, data/town/crowd.json): generated students
## and townsfolk by zone and day part, each with a name, a tinted base sprite,
## a rolled disposition and trait, a rumor about the week's Upside-Down
## signature and sometimes a small favor; barks; party banter
## (data/town/party_banter.json); and the visible town changes
## (data/town/changes.json).
extends RefCounted

const Sig := preload("res://src/core/dungeon/signature.gd")
const Fx := preload("res://src/core/run/effects.gd")
const RM := preload("res://src/core/run/run_model.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("town/crowd", {})


static func _pick(list: Array, rng: RandomNumberGenerator) -> Variant:
	return null if list.is_empty() else list[rng.randi_range(0, list.size() - 1)]


## How many of each kind spawn in a zone during a day part.
static func counts(db: Dictionary, zone: String, part: String) -> Dictionary:
	return cfg(db).get("spawn", {}).get(zone, {}).get(part, {})


## The generated people for a zone and part (seeded by the caller's rng).
static func generate(db: Dictionary, run: Dictionary, zone: String, part: String, week: int, rng: RandomNumberGenerator) -> Array:
	var c := cfg(db)
	var out: Array = []
	var axes: Array = db.get("spaces", {}).get("disposition", {}).get("axes", [])
	var n := 0
	for kind in ["student", "adult"]:
		for i in int(counts(db, zone, part).get(kind, 0)):
			var disp := {}
			for a in axes:
				disp[str(a)] = rng.randi_range(0, 10)
			var favor := -1
			if rng.randf() < float(c.get("favorChance", 0.25)) and not c.get("favors", []).is_empty():
				favor = rng.randi_range(0, c["favors"].size() - 1)
			out.append({
				"id": "crowd_%d" % n, "kind": kind,
				"name": "%s %s" % [str(_pick(c.get("first", ["Alex"]), rng)), str(_pick(c.get("last", ["Smith"]), rng))],
				"sprite": str(_pick(c.get("sprites", {}).get(kind, []), rng)),
				"tint": str(_pick(c.get("tints", ["#ffffff"]), rng)),
				"trait": _pick(c.get("traits", [{}]), rng),
				"disposition": disp,
				"rumor": rumor(db, run, week, rng),
				"favor": favor,
			})
			n += 1
	return out


## A rumor that hints at the week's dominant Upside-Down Vector.
static func rumor(db: Dictionary, run: Dictionary, week: int, rng: RandomNumberGenerator) -> String:
	var r: Dictionary = cfg(db).get("rumors", {})
	var lines: Array = r.get(Sig.dominant(db, run, week), r.get("default", []))
	return str(_pick(lines if not lines.is_empty() else r.get("default", [""]), rng))


static func bark(db: Dictionary, kind: String, rng: RandomNumberGenerator) -> String:
	return str(_pick(cfg(db).get("barks", {}).get(kind, cfg(db).get("barks", {}).get("named", [""])), rng))


## A party member's comment on arriving in a zone ("" if none).
static func zone_comment(db: Dictionary, member: String, zone: String) -> String:
	var z: Dictionary = db.get("town/party_banter", {}).get("zones", {})
	return str(z.get(member, {}).get(zone, z.get("default", {}).get(zone, "")))


## A pair banter line between two party members, when both have at least the
## pair's minBond with the player ("" if no pair is unlocked).
static func pair_line(db: Dictionary, run: Dictionary, members: Array, rng: RandomNumberGenerator) -> String:
	var ok: Array = []
	for p in db.get("town/party_banter", {}).get("pairs", []):
		if members.has(str(p["a"])) and members.has(str(p["b"])) \
				and RM.bond(run, str(p["a"])) >= float(p.get("minBond", 0)) and RM.bond(run, str(p["b"])) >= float(p.get("minBond", 0)):
			ok.append_array(p.get("lines", []))
	return str(_pick(ok, rng)) if not ok.is_empty() else ""


## Town changes visible now in a zone.
static func changes(db: Dictionary, run: Dictionary, ctx: Dictionary, zone: String) -> Array:
	return db.get("town/changes", {}).get("changes", []).filter(func(c: Dictionary) -> bool:
		return str(c.get("zone", "")) == zone and Fx.conditions_met(db, run, c.get("cond", {}), ctx))

## The week's Vector signature (DESIGN.md Section 10): an authored base from
## data/weeks.json plus the Shifts town events and choices add during the week
## (run["signature"], keyed by week). Enemies are weighted by Match with it.
class_name DungeonSignature
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const VO := preload("res://src/core/vector_ops.gd")
const DT := preload("res://src/core/data_tables.gd")


static func week_rec(db: Dictionary, week: int) -> Dictionary:
	for w in db.get("weeks", {}).get("weeks", []):
		if int(w.get("week", 0)) == week:
			return w
	return {}


## Base + this week's shifts (raw weights).
static func current(db: Dictionary, run: Dictionary, week: int) -> Dictionary:
	var base: Dictionary = week_rec(db, week).get("baseSignature", {})
	var shifts: Dictionary = run.get("signature", {})
	return VO.blend([base, shifts])


static func dominant(db: Dictionary, run: Dictionary, week: int) -> String:
	return VO.dominant_axis(current(db, run, week), db.get("spaces", {}).get("arcane", {}).get("axes", []))


## The hint line for the week's dominant axis (shown, never the numbers).
static func hint(db: Dictionary, run: Dictionary, week: int) -> String:
	return str(week_rec(db, week).get("hints", {}).get(dominant(db, run, week), Str.t(db, "signature.the_air_feels_strange_tonight")))


## Enemies that can appear this week at this tier, weighted by
## max(0.05, Match(signature, enemy signature)).
static func enemy_weights(db: Dictionary, run: Dictionary, week: int, tier: String) -> Dictionary:
	var sig := current(db, run, week)
	var out := {}
	for e in DT.records_under(db, "enemies/", "enemies"):
		if str(e.get("tier", "normal")) != tier:
			continue
		var weeks: Array = e.get("weeks", [])
		var ok := weeks.is_empty()
		for w in weeks:
			ok = ok or int(w) == week
		if not ok:
			continue
		out[str(e["id"])] = maxf(0.05, VO.similarity(sig, e.get("signature", {}))) * float(e.get("weight", 1.0))
	return out


## Sample n enemy ids (with repeats) for a fight.
static func pick_enemies(db: Dictionary, run: Dictionary, week: int, tier: String, n: int, rng: RandomNumberGenerator) -> Array:
	var w := enemy_weights(db, run, week, tier)
	var order: Array = w.keys()
	order.sort()
	var out: Array = []
	for i in n:
		var id := VO.sample(w, rng, order)
		if id != "":
			out.append(id)
	return out


## Weekly reset of the town-driven shifts.
static func new_week(run: Dictionary) -> void:
	run["signature"] = {}

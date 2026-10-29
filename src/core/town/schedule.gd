## Where every named NPC is right now (DESIGN.md Section 3, "NPC schedules").
## Schedules live in data/npcs/<id>.json:
##   "schedule": { "weekday": { part: loc }, "weekend": { part: loc },
##     "days": { "tue": { part: loc } }, "flags": [{ "flag", "weekday", "weekend" }],
##     "weekendDays": ["sat"] }
## A value can be a location id, "home", "@nap" (a rotating nap spot), "@missing",
## or a list (rotates by day). Anything unscheduled means home; night is home.
class_name TownSchedule
extends RefCounted

const RM := preload("res://src/core/run/run_model.gd")

const WEEKEND_DAYS := ["sat", "sun"]


## Nap spots come from data/town/locations.json "napSpots" (M13).
static func nap_spots(db: Dictionary) -> Array:
	return db.get("town/locations", {}).get("napSpots", ["hallways"])


static func npc_ids(db: Dictionary) -> Array:
	var out: Array = []
	for key in db:
		if str(key).begins_with("npcs/"):
			out.append(str(db[key].get("id", str(key).get_file())))
	out.sort()
	return out


static func npc(db: Dictionary, id: String) -> Dictionary:
	return db.get("npcs/" + id, {})


## A deterministic per-day RNG for one NPC (rotations, nap spots, Todd).
static func day_rng(run: Dictionary, id: String, day_count: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%s" % [int(run.get("seed", 0)), day_count, id])
	return rng


## Location id where `id` is during this part, or "" if nowhere to be found.
## "home" is resolved to the NPC's home location id.
static func location_of(db: Dictionary, run: Dictionary, id: String, day: String, part: String, day_count: int) -> String:
	var rec := npc(db, id)
	if rec.is_empty() or bool(rec.get("hidden", false)):
		return ""
	var home := str(rec.get("home", ""))
	var member := RM.character(run, id)
	if not member.is_empty() and int(member.get("injured", 0)) > 0:
		return "hospital"
	if part == "night" or part == "evening":
		return home
	if rec.has("missingChance") and day_rng(run, id, day_count).randf() < float(rec["missingChance"]):
		return ""
	var sched: Dictionary = rec.get("schedule", {})
	var weekend := WEEKEND_DAYS.has(day)
	var table: Dictionary = sched.get("weekend" if weekend else "weekday", {})
	if weekend and sched.has("weekendDays") and not Array(sched["weekendDays"]).has(day):
		table = {}
	var loc: Variant = table.get(part, "")
	for f in sched.get("flags", []):
		if RM.flag(run, str(f.get("flag", ""))):
			var ft: Dictionary = f.get("weekend" if weekend else "weekday", {})
			if ft.has(part):
				loc = ft[part]
	var day_table: Dictionary = sched.get("days", {}).get(day, {})
	if day_table.has(part):
		loc = day_table[part]
	if typeof(loc) == TYPE_ARRAY:
		var arr: Array = loc
		loc = arr[day_count % arr.size()] if not arr.is_empty() else ""
	var s := str(loc)
	if s == "" or s == "home":
		return "" if bool(rec.get("awayOtherwise", false)) and s == "" else home
	if s == "@missing":
		return ""
	if s == "@nap":
		var naps := nap_spots(db)
		return str(naps[day_rng(run, id + ":nap", day_count).randi_range(0, naps.size() - 1)])
	return s


## Every NPC at a location during this part, sorted by id.
static func people_at(db: Dictionary, run: Dictionary, loc: String, day: String, part: String, day_count: int) -> Array:
	var out: Array = []
	for id in npc_ids(db):
		if location_of(db, run, str(id), day, part, day_count) == loc:
			out.append(id)
	return out


static func is_home(db: Dictionary, run: Dictionary, id: String, day: String, part: String, day_count: int) -> bool:
	var rec := npc(db, id)
	return not rec.is_empty() and location_of(db, run, id, day, part, day_count) == str(rec.get("home", ""))

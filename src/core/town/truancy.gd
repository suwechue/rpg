## Getting caught skipping (docs/TOWN_LIFE.md Part 2, data/truancy.json):
## the Spotted chance for school-hours actions, the three ways out, parent
## trust and its curfew and allowance, patrol vision cones for sneaking in the
## school, and the perfect-attendance bonus.
extends RefCounted

const Locs := preload("res://src/core/town/locations.gd")
const School := preload("res://src/core/run/school.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("truancy", {})


static func is_school_hours(db: Dictionary, part: String) -> bool:
	return db.get("calendar", {}).get("schoolHours", []).has(part)


## The chance of being spotted at a place: the place (or its zone), watchers
## near you (ids within reach), and this week's skips.
static func risk(db: Dictionary, run: Dictionary, loc: String, watchers_near: Array) -> float:
	var c := cfg(db)
	var r := float(c.get("places", {}).get(loc, c.get("zoneRisk", {}).get(str(Locs.rec(db, loc).get("zone", "")), 0.15)))
	for w in watchers_near:
		r += float(c.get("watchers", {}).get(str(w), 0.0))
	r += float(c.get("perSkip", 0.05)) * float(run.get("skips_week", 0))
	return clampf(r, 0.0, float(c.get("maxRisk", 0.85)))


static func label(db: Dictionary, r: float) -> String:
	for l in cfg(db).get("labels", []):
		if r <= float(l[0]):
			return str(l[1])
	return "high"


## How a Spotted scene ends: "talk" (a CHA check), "run" (the chase score) or
## "take". Returns { "free": bool, "key": result string id }. Getting caught
## sets detention and costs parent trust (unless a sub covers for you once).
static func resolve(db: Dictionary, run: Dictionary, choice: String, cha: int, chase: float, rng: RandomNumberGenerator) -> Dictionary:
	var c := cfg(db)
	var free := false
	var key := "truancy.caught"
	match choice:
		"talk":
			free = rng.randf() < clampf(float(c.get("talkBase", 0.35)) + float(c.get("talkPerCha", 0.06)) * float(cha - 5), 0.05, 0.95)
			key = "truancy.talked" if free else "truancy.talk_fail"
		"run":
			free = chase >= float(c.get("runNeed", 0.5))
			key = "truancy.ran" if free else "truancy.caught"
	if not free:
		var cover := str(c.get("caught", {}).get("ellisCovers", ""))
		if cover != "" and bool(run.get("flags", {}).get(cover, false)) and not bool(run.get("flags", {}).get(cover + "_used", false)):
			run["flags"][cover + "_used"] = true
			return { "free": true, "key": "truancy.covered" }
		caught(db, run)
	return { "free": free, "key": key }


static func caught(db: Dictionary, run: Dictionary) -> void:
	var cc: Dictionary = cfg(db).get("caught", {})
	if bool(cc.get("detention", true)):
		run["detention_pending"] = true
	change_trust(db, run, int(cc.get("trust", -10)))


static func trust(db: Dictionary, run: Dictionary) -> int:
	return int(run.get("parentTrust", cfg(db).get("trustStart", 50)))


static func tier(db: Dictionary, run: Dictionary) -> String:
	var t := trust(db, run)
	if t < int(cfg(db).get("lowTrust", 30)):
		return "low"
	if t > int(cfg(db).get("highTrust", 70)):
		return "high"
	return "mid"


## Change parent trust; crossing into low or high gets a text from your parent.
static func change_trust(db: Dictionary, run: Dictionary, delta: int) -> void:
	var before := tier(db, run)
	run["parentTrust"] = clampi(trust(db, run) + delta, 0, 100)
	var after := tier(db, run)
	if after != before and after != "mid":
		var texts: Array = run.get("texts", [])
		texts.append({ "from": "parent", "text": str(cfg(db).get("trustTexts", {}).get(after, "")), "day": int(run.get("day_count", 0)), "invite": false })
		run["texts"] = texts


## Night AP change from a curfew (low trust).
static func night_ap_delta(db: Dictionary, run: Dictionary) -> int:
	return int(cfg(db).get("curfewApDelta", -1)) if tier(db, run) == "low" else 0


static func allowance(db: Dictionary, run: Dictionary) -> int:
	return int(cfg(db).get("allowance", 15)) if tier(db, run) == "high" else 0


## Cells a patrol sees: straight ahead up to coneLength, widening by one on
## each side from the second tile; walls (blocked) stop it.
static func cone(db: Dictionary, origin: Vector2i, facing: Vector2i, blocked: Dictionary) -> Array:
	var out: Array = []
	var side := Vector2i(facing.y, facing.x)
	for d in range(1, int(cfg(db).get("sneak", {}).get("coneLength", 3)) + 1):
		var mid := origin + facing * d
		if blocked.has(mid):
			break
		out.append(mid)
		if d >= 2:
			for s in [side, -side]:
				if not blocked.has(mid + s):
					out.append(mid + s)
	return out


## End of a school week: perfect attendance (no skips, at least one class)
## raises the most-attended class's first stat. Returns the stat raised or "".
static func week_end(db: Dictionary, run: Dictionary) -> String:
	if int(run.get("skips_week", 0)) > 0 or run.get("attendance_week", {}).is_empty():
		return ""
	var best := ""
	for cid in run["attendance_week"]:
		if best == "" or int(run["attendance_week"][cid]) > int(run["attendance_week"][best]):
			best = str(cid)
	var stats: Array = School.class_rec(db, best).get("statGains", [])
	if stats.is_empty():
		return ""
	var st := str(stats[0])
	run["player"]["stats"][st] = int(run["player"]["stats"].get(st, 5)) + int(cfg(db).get("streakReward", 1))
	return st

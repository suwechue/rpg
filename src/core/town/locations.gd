## Town locations (docs/TOWN.md, data/town/locations.json): status, hours, stat
## gates and what happens at a door. OPEN places can be entered during their
## hours; EXTERIOR homes bring a resident to the door; CLOSED and locked STORY
## places give their door line.
class_name TownLocations
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const DT := preload("res://src/core/data_tables.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Sched := preload("res://src/core/town/schedule.gd")
const Char := preload("res://src/core/character.gd")


static func rec(db: Dictionary, id: String) -> Dictionary:
	return DT.record(db, "town/locations", id)


static func all(db: Dictionary) -> Array:
	return db.get("town/locations", {}).get("locations", [])


## STORY places open on their flag; everything else keeps its data status.
static func status(db: Dictionary, run: Dictionary, id: String) -> String:
	var r := rec(db, id)
	var s := str(r.get("status", "CLOSED"))
	if s == "STORY" and RM.flag(run, str(r.get("storyFlag", ""))):
		return "OPEN"
	return s


static func in_hours(r: Dictionary, part: String, db: Dictionary = {}) -> bool:
	var hours: Variant = r.get("hours", [])
	if typeof(hours) == TYPE_STRING:
		return str(hours) == "*"
	return expand_hours(db, Array(hours)).has(part)


## Hours with aliases expanded ("@schoolHours" -> data/calendar.json schoolHours).
static func expand_hours(db: Dictionary, hours: Array) -> Array:
	var out: Array = []
	for h in hours:
		var s := str(h)
		if s.begins_with("@"):
			out.append_array(db.get("calendar", {}).get(s.substr(1), []))
		else:
			out.append(s)
	return out


## Can the player use this place now? Returns "" or the reason it's shut.
static func closed_reason(db: Dictionary, run: Dictionary, id: String, week: int, part: String) -> String:
	var r := rec(db, id)
	if r.is_empty():
		return Str.t(db, "locations.nothing_here")
	var st := status(db, run, id)
	if st == "CLOSED" or st == "STORY":
		return str(r.get("doorLine", Str.t(db, "locations.it_s_shut")))
	if week < int(r.get("openFromWeek", 0)):
		return str(r.get("lockedLine", Str.t(db, "locations.not_yet")))
	if r.has("gate") and not Fx.conditions_met(db, run, { "minStat": r["gate"] }, {}):
		return str(r.get("lockedLine", Str.t(db, "locations.you_can_t_get_in")))
	if st == "EXTERIOR" and not bool(r.get("walkUp", false)):
		return str(r.get("doorLine", Str.t(db, "locations.nobody_answers")))
	if not in_hours(r, part, db):
		return str(r.get("doorLine", Str.t(db, "locations.is_closed_right_now") % r.get("name", "It")))
	return ""


## What a door does right now:
## { "kind": "enter" | "walkup" | "doorstep" | "line", "npcs": [...], "text": "..." }
static func door(db: Dictionary, run: Dictionary, id: String, week: int, day: String, part: String, day_count: int) -> Dictionary:
	var r := rec(db, id)
	var st := status(db, run, id)
	var reason := closed_reason(db, run, id, week, part)
	if reason == "":
		return { "kind": "walkup" if st == "EXTERIOR" else "enter", "npcs": [], "text": "" }
	if st == "EXTERIOR" and part != "night" and part != "evening":
		var home_now: Array = []
		for npc in r.get("residents", []):
			if Sched.location_of(db, run, str(npc), day, part, day_count) == id:
				home_now.append(str(npc))
		if not home_now.is_empty():
			return { "kind": "doorstep", "npcs": home_now, "text": str(r.get("doorLine", "")) }
	return { "kind": "line", "npcs": [], "text": reason }


## Residents who are home right now (lit windows).
static func residents_home(db: Dictionary, run: Dictionary, id: String, day: String, part: String, day_count: int) -> Array:
	var out: Array = []
	for npc in rec(db, id).get("residents", []):
		if Sched.location_of(db, run, str(npc), day, part, day_count) == id:
			out.append(str(npc))
	return out


## Activities available here now (by part and condition).
static func activities(db: Dictionary, run: Dictionary, id: String, part: String, ctx: Dictionary) -> Array:
	var out: Array = []
	for a in rec(db, id).get("activities", []):
		var parts: Array = a.get("parts", [])
		if not parts.is_empty() and not parts.has(part):
			continue
		if not Fx.conditions_met(db, run, a.get("cond", {}), ctx):
			continue
		out.append(a)
	return out


## Interiors for a location, from data/town/interiors.json.
static func interior(db: Dictionary, interior_id: String) -> Dictionary:
	return DT.record(db, "town/interiors", interior_id)

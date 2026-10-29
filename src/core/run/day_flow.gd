## What each day part means for the run (DESIGN.md Section 2): which screen a
## part opens with, what happens when the day ends (sleep) and when a week ends.
class_name DayFlow
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const RM := preload("res://src/core/run/run_model.gd")
const School := preload("res://src/core/run/school.gd")
const Char := preload("res://src/core/character.gd")
const VO := preload("res://src/core/vector_ops.gd")


## "class", "dungeon", "night", or "free" (walk around, spend AP).
static func part_kind(part: Dictionary) -> String:
	if bool(part.get("wholePart", false)):
		return "class"
	if bool(part.get("dungeon", false)):
		return "dungeon"
	if str(part.get("id", "")) == "night":
		return "night"
	return "free"


## Screens to show when a part starts, in order: "schedule" (first school
## morning of a week without a schedule), "detention" (pending, After School),
## "class", "dungeon", "night".
static func on_enter(run: Dictionary, week: int, day: String, part: Dictionary, weekend: bool) -> Array:
	var out: Array = []
	var pid := str(part.get("id", ""))
	if not weekend and pid == "before_school" and int(run.get("schedule_week", 0)) != week:
		out.append("schedule")
	if pid == "after_school" and bool(run.get("detention_pending", false)):
		out.append("detention")
	var kind := part_kind(part)
	if kind != "free":
		out.append(kind)
	return out


## Sleep: HP and MP refill, injuries count down, the daily school state resets.
static func end_day(db: Dictionary, run: Dictionary) -> Array:
	var lines: Array = []
	Char.full_restore(db, run["player"])
	for m in run.get("roster", []):
		if m.has("pendingClassChange"):
			var cls := preload("res://src/core/progression/class_change.gd").auto_advance(db, run, m)
			if cls != "":
				var cname := str(db.get("classes", {}).get("classes", []).filter(func(c: Variant) -> bool: return str(c["id"]) == cls)[0].get("name", cls))
				lines.append(Str.t(db, "day_flow.grew_into") % [m.get("name", "?"), "an" if "AEIOU".contains(cname.left(1)) else "a", cname])
		Char.full_restore(db, m)
		if int(m.get("injured", 0)) > 0:
			m["injured"] = int(m["injured"]) - 1
			if int(m["injured"]) == 0:
				lines.append(Str.t(db, "day_flow.is_out_of_the_hospital") % m.get("name", "?"))
	School.new_day(run)
	run["day_count"] = int(run.get("day_count", 0)) + 1
	return lines


## A new week: school counters reset, Bonds decay 5% toward 0 (except
## Unbreakable), dispositions drift back toward rest.
static func new_week(db: Dictionary, run: Dictionary) -> Array:
	# TL Part 2: perfect attendance last week raises a class stat.
	run["lastStreak"] = preload("res://src/core/town/truancy.gd").week_end(db, run)
	School.new_week(run)
	run["signature"] = {}
	var bond_space: Dictionary = db.get("spaces", {}).get("bond", {})
	var rate := float(bond_space.get("weeklyDecay", 0.05))
	var floor_value := float(bond_space.get("noDecayAt", 86))
	for npc in run["bonds"]:
		var b := float(run["bonds"][npc])
		if b < floor_value:
			run["bonds"][npc] = VO.decay({ "bond": b }, rate)["bond"]
	for npc in run.get("npcs", {}):
		var rec: Dictionary = db.get("npcs/" + str(npc), {})
		var st: Dictionary = run["npcs"][npc]
		if rec.has("disposition"):
			st["disposition"] = VO.decay(st.get("disposition", {}), float(db.get("social", {}).get("dispositionDecay", 0.25)), rec["disposition"])
	return []


## Members who can fight tonight (not injured).
static func available_party(run: Dictionary) -> Array:
	var out: Array = []
	for id in run.get("party_ids", []):
		var m := RM.character(run, str(id))
		if not m.is_empty() and int(m.get("injured", 0)) <= 0:
			out.append(str(id))
	return out

## Fight goals besides kill-everything (docs/COMBAT_LAB.md Part 2). A goal is data
## on the fight: { "type": kill | survive | protect | reach_exit | break |
## stop_ritual | capture, "rounds": n, "unit": id, "cell": [x, y] }. Killing every
## enemy always wins. `st` is the CombatState (untyped: it loads this script).
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const TYPES := ["kill", "survive", "protect", "reach_exit", "break", "stop_ritual", "capture"]


static func start(st, goal: Dictionary) -> void:
	var over: String = st.rules.text("goal")
	st.goal = goal.duplicate() if goal != null else {}
	if over != "":
		st.goal["type"] = over
	if str(st.goal.get("type", "kill")) == "survive" and not st.goal.has("rounds"):
		st.goal["rounds"] = 4
	st.goal_left = int(st.goal.get("rounds", 0))


static func _unit(st) -> Object:
	var id := str(st.goal.get("unit", ""))
	for u in st.units:
		if str(u.id) == id or str(u.source.get("id", "")) == id:
			return u
	return null


static func _cell(st) -> Vector2i:
	var c: Array = st.goal.get("cell", [0, 0])
	return Vector2i(int(c[0]), int(c[1]))


## Rounds tick down at the end of each round.
static func on_round_end(st) -> void:
	match str(st.goal.get("type", "kill")):
		"survive", "protect", "stop_ritual":
			if int(st.goal_left) > 0:
				st.goal_left -= 1
		"capture":
			var u: Object = st.unit_at(_cell(st))
			if u != null and u.team == "party" and u.alive():
				st.goal_left -= 1


## A pushed ritualist loses its footing: the spell takes a round longer.
static func on_pushed(st, t: Object) -> void:
	if str(st.goal.get("type", "")) == "stop_ritual" and _unit(st) == t:
		st.goal_left += 1
		st._emit({ "t": "log", "text": Str.t(st.db, "goal.ritual_delayed") % t.name })


## "win", "lose" or "" (keep fighting).
static func check(st) -> String:
	match str(st.goal.get("type", "kill")):
		"survive":
			return "win" if int(st.goal_left) <= 0 else ""
		"protect":
			var o: Object = _unit(st)
			if o == null or o.dead or o.downed:
				return "lose"
			return "win" if st.goal.has("rounds") and int(st.goal_left) <= 0 else ""
		"reach_exit":
			var any := false
			for u in st.units:
				if u.team == "party" and u.alive() and not bool(u.source.get("object", false)):
					any = true
					if not st.grid.exits.has(u.cell):
						return ""
			return "win" if any else ""
		"break":
			var o: Object = _unit(st)
			return "win" if o == null or o.dead else ""
		"stop_ritual":
			var o: Object = _unit(st)
			if o == null or not o.alive():
				return "win"
			return "lose" if int(st.goal_left) <= 0 else ""
		"capture":
			return "win" if int(st.goal_left) <= 0 else ""
	return ""


## The goal in plain words, for the HUD ("" for a plain kill-everything fight).
static func line(st) -> String:
	var type := str(st.goal.get("type", "kill"))
	if type == "kill":
		return ""
	var o: Object = _unit(st)
	var who: String = o.name if o != null else ""
	match type:
		"survive", "capture":
			return Str.t(st.db, "goal." + type) % int(st.goal_left)
		"protect":
			return Str.t(st.db, "goal.protect") % [who, int(st.goal_left)]
		"reach_exit":
			return Str.t(st.db, "goal.reach_exit")
		"break":
			return Str.t(st.db, "goal.break") % who
		"stop_ritual":
			return Str.t(st.db, "goal.stop_ritual") % [who, int(st.goal_left)]
	return ""

## The mystery board (ROADMAP M18, data/mystery.json): clues collected from
## events, the library and the Upside-Down (run["clues"]); linking the two
## clues of a deduction unlocks it (run["deductions"] and flag deduction_<id>),
## which opens extra story choices and dialogue.
extends RefCounted


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("mystery", {})


static func clue(db: Dictionary, id: String) -> Dictionary:
	for c in cfg(db).get("clues", []):
		if str(c.get("id", "")) == id:
			return c
	return {}


## Add a clue to the run. True if it's new.
static func add_clue(run: Dictionary, id: String) -> bool:
	if id == "":
		return false
	var have: Array = run.get("clues", [])
	if have.has(id):
		return false
	have.append(id)
	run["clues"] = have
	return true


## Link two clues: the deduction they make ({} if none). Unlocks it the first time.
static func connect_clues(db: Dictionary, run: Dictionary, a: String, b: String) -> Dictionary:
	var have: Array = run.get("clues", [])
	if not have.has(a) or not have.has(b) or a == b:
		return {}
	for d in cfg(db).get("deductions", []):
		var pair: Array = d.get("clues", [])
		if pair.has(a) and pair.has(b):
			var done: Array = run.get("deductions", [])
			if not done.has(str(d["id"])):
				done.append(str(d["id"]))
				run["deductions"] = done
				var flags: Dictionary = run.get("flags", {})
				flags[str(d.get("flag", "deduction_" + str(d["id"])))] = true
				run["flags"] = flags
			return d
	return {}

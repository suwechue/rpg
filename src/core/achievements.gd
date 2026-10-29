## Narrator's Journal achievements (ROADMAP M22, data/achievements.json),
## checked against the Journal's data across runs. Some unlock small extras.
extends RefCounted


static func all(db: Dictionary) -> Array:
	return db.get("achievements", {}).get("achievements", [])


## How far a stat has got: list sizes, numbers, "endings:<id>" (0 or 1) and
## "arena.bestWave".
static func progress(journal: Dictionary, stat: String) -> int:
	if stat.begins_with("endings:"):
		return 1 if journal.get("endings", {}).has(stat.substr(8)) else 0
	if stat == "arena.bestWave":
		return int(journal.get("arena", {}).get("bestWave", 0))
	var v: Variant = journal.get(stat, 0)
	if v is Array:
		return (v as Array).size()
	if v is Dictionary:
		return (v as Dictionary).size()
	return int(v)


static func done(journal: Dictionary, a: Dictionary) -> bool:
	return progress(journal, str(a.get("stat", ""))) >= int(a.get("min", 1))


## Newly earned achievements: marks them in the Journal (and their unlocks).
static func check(db: Dictionary, journal: Dictionary) -> Array:
	var earned: Array = journal.get("achievements", [])
	var fresh: Array = []
	for a in all(db):
		if not earned.has(str(a["id"])) and done(journal, a):
			earned.append(str(a["id"]))
			fresh.append(a)
			if a.has("unlock"):
				journal[str(a["unlock"])] = true
	journal["achievements"] = earned
	return fresh

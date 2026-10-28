## Demo mode and feedback (docs/VECTORS_DEMO.md Parts 5 and 6), the pure
## part: when the demo ends, what the thanks screen says, the survey, and the
## gameplay summary that goes into a feedback zip. data/demo.json.
extends RefCounted

const Log := preload("res://src/core/run/play_log.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("demo", {})


## On when data/demo.json says so or the build has the "demo" feature tag.
static func is_on(db: Dictionary, has_demo_feature: bool) -> bool:
	return bool(cfg(db).get("enabled", false)) or has_demo_feature


## The run ends after this week's boss.
static func ends_after(db: Dictionary, week: int) -> bool:
	return week >= int(cfg(db).get("endAfterWeek", 1))


static func version(db: Dictionary) -> String:
	return str(cfg(db).get("version", "dev"))


## What the thanks screen shows: combos found, characters met, what's coming.
static func thanks(db: Dictionary, run: Dictionary, journal: Dictionary) -> Dictionary:
	var met: Array = []
	var npcs: Dictionary = run.get("npcs", {})
	for id in npcs:
		if bool(npcs[id].get("met", false)):
			met.append(str(db.get("npcs/" + str(id), {}).get("name", str(id).capitalize())))
	met.sort()
	var combos: Array = []
	for id in journal.get("combos", []):
		for c in db.get("combos", {}).get("combos", []):
			if str(c.get("id", "")) == str(id):
				combos.append(str(c.get("name", id)))
	return { "met": met, "combos": combos, "comboTotal": db.get("combos", {}).get("combos", []).size(), "coming": cfg(db).get("comingSoon", []) }


static func survey(db: Dictionary) -> Array:
	return cfg(db).get("survey", [])


## The gameplay summary for a feedback zip: totals from the gameplay log, plus
## combos discovered and where the player was (the quit point).
static func log_summary(records: Array, run: Dictionary, where: Dictionary) -> Dictionary:
	var out := Log.summarize(records)
	var rounds := 0
	var fights := 0
	for r in records:
		rounds += int(r.get("rounds", 0))
		fights += int(r.get("won", 0)) + int(r.get("lost", 0)) + int(r.get("fled", 0))
	out["avgRoundsPerFight"] = float(rounds) / float(maxi(fights, 1))
	out["cardsPlayed"] = 0
	for r in records:
		out["cardsPlayed"] = int(out["cardsPlayed"]) + int(r.get("cards", 0))
	out["combos"] = run.get("combos", []).duplicate()
	out["where"] = where
	return out

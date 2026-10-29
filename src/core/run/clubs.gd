## Clubs (ROADMAP M16, data/clubs.json): joined at the week 3 club fair (up
## to maxJoin). On a club's days its meeting takes the After School part and
## gives stat XP, Bond with its members and a short scene.
extends RefCounted


static func all(db: Dictionary) -> Array:
	return db.get("clubs", {}).get("clubs", [])


static func find(db: Dictionary, id: String) -> Dictionary:
	for c in all(db):
		if str(c.get("id", "")) == id:
			return c
	return {}


static func joined(run: Dictionary) -> Array:
	return run.get("clubs", [])


## Join a club. Returns "" or why not ("full", "joined", "unknown").
static func join(db: Dictionary, run: Dictionary, id: String) -> String:
	if find(db, id).is_empty():
		return "unknown"
	var j: Array = run.get("clubs", [])
	if j.has(id):
		return "joined"
	if j.size() >= int(db.get("clubs", {}).get("maxJoin", 2)):
		return "full"
	j.append(id)
	run["clubs"] = j
	return ""


## The club meeting today (the first joined club that meets this day), or "".
static func meeting_today(db: Dictionary, run: Dictionary, day: String) -> String:
	for id in joined(run):
		if find(db, str(id)).get("days", []).has(day):
			return str(id)
	return ""


## The meeting as an event for the event screen: a scene line and the effects.
static func meeting_event(db: Dictionary, run: Dictionary, id: String, rng: RandomNumberGenerator) -> Dictionary:
	var c := find(db, id)
	var lines: Array = c.get("lines", [])
	var seen := int(run.get("clubMeetings", {}).get(id, 0))
	var text := str(c.get("blurb", "")) if seen == 0 else (str(lines[rng.randi_range(0, lines.size() - 1)]) if not lines.is_empty() else "")
	var counts: Dictionary = run.get("clubMeetings", {})
	counts[id] = seen + 1
	run["clubMeetings"] = counts
	return { "title": str(c.get("name", id)), "text": text, "effects": c.get("effects", {}) }

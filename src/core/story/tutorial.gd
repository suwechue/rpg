## The combat tutorial floor (docs/COMBAT_TUNING.md Part 7) and the reusable
## lesson steps that drive it (also meant for the day-one town tutorial and a
## later Combat Practice menu). Rooms live in data/story/tutorial_floor.json.
extends RefCounted

const DT := preload("res://src/core/data_tables.gd")
const CardRules := preload("res://src/core/card.gd")

## Things a lesson step can wait for (events the combat scene reports).
const WAITS := ["next", "moved", "dodged", "struck", "guarded", "hovered_card", "played_card", "held", "improvised", "cantrip"]
## UI elements a step can point at.
const HIGHLIGHTS := ["timeline", "pips", "strike", "guard", "telegraph", "hand", "mp", "hold", "cover", "wheel", "threat", "cantrip"]


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("story/tutorial_floor", {})


static func rooms(db: Dictionary) -> Array:
	return cfg(db).get("rooms", [])


static func room(db: Dictionary, id: int) -> Dictionary:
	for r in rooms(db):
		if int(r.get("id", -1)) == id:
			return r
	return {}


## Rooms played in order, given the run's flags (the shortcut skips room 7).
static func route(db: Dictionary, flags: Dictionary) -> Array:
	var out: Array = []
	for r in rooms(db):
		var skip := str(r.get("skipIfFlag", ""))
		if skip != "" and bool(flags.get(skip, false)):
			continue
		out.append(int(r["id"]))
	return out


## Which UI elements are open in a room ("hand", "wheel", "threat").
static func ui_open(db: Dictionary, id: int) -> Dictionary:
	return room(db, id).get("ui", { "hand": true, "wheel": true, "threat": true })


## Combat setup options for a room. `player` is the player character (its first
## Vectors decide the practice deck and which enemy is weak or strong).
static func setup_opts(db: Dictionary, id: int, player: Dictionary, flags: Dictionary, lessons: bool = true) -> Dictionary:
	var r := room(db, id)
	var known: Array = player.get("knownVectors", [])
	var v0 := str(known[0]) if not known.is_empty() else "force"
	var v1 := str(known[1]) if known.size() > 1 else "force"
	var index := DT.index_under(db, "enemies/", "enemies")
	var enemies: Array = []
	for eid in r.get("enemies", []):
		var rec: Dictionary = index.get(str(eid), {}).duplicate(true)
		if rec.is_empty():
			continue
		if bool(rec.get("weakToPlayer", false)):
			rec["weakTo"] = [v0]
		if bool(rec.get("strongToPlayer", false)):
			rec["strongAgainst"] = [v0]
		if bool(rec.get("strongToHand", false)):
			rec["strongAgainst"] = known.duplicate() if v0 != v1 else [v0]
			rec["weakTo"] = [v1] if v1 != v0 else []
		enemies.append(rec)
	var deck: Array = []
	for c in r.get("playerDeck", []):
		var s := str(c)
		# "spell:<form>:<magnitude>" means that spell in the player's first Vector.
		if s.begins_with("spell:"):
			var parts := s.split(":")
			deck.append(CardRules.spell_id(db, { v0: 1.0 }, parts[1], parts[2]))
		else:
			deck.append(s)
	var steps: Array = []
	if lessons:
		for st in r.get("lesson", []):
			var cond := str(st.get("ifFlag", ""))
			if cond == "" or bool(flags.get(cond, false)):
				steps.append(st)
	return { "tutorial": id, "layout": str(r.get("layout", "open_field")), "enemies": enemies, "playerDeck": deck,
		"addCards": r.get("addCards", []), "ui": ui_open(db, id), "fair": bool(r.get("fair", false)), "hpFloor": bool(r.get("hpFloor", true)),
		"guaranteeImprovise": bool(r.get("guaranteeImprovise", false)), "lesson": steps, "stayedInRed": str(r.get("stayedInRed", "")),
		"intro": str(r.get("name", "")) }


## A lesson in progress: a list of steps, each waiting for an event.
class Lesson:
	extends RefCounted
	var steps: Array = []
	var index := 0
	var stuck := 0.0

	func _init(p_steps: Array = []) -> void:
		steps = p_steps

	func done() -> bool:
		return index >= steps.size()

	func current() -> Dictionary:
		return {} if done() else steps[index]

	## Report an event; true if the lesson moved on.
	func notify(event: String) -> bool:
		if done():
			return false
		var want := str(current().get("wait", "next"))
		if want == event or (want == "moved" and event == "dodged"):
			index += 1
			stuck = 0.0
			return true
		return false

	## Time passing on the current step; true once the hint should show.
	func tick(delta: float, hint_after: float) -> bool:
		if done():
			return false
		stuck += delta
		return stuck >= hint_after and str(current().get("hint", "")) != ""

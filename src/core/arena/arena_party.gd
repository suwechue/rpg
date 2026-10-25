## Arena parties (docs/ARENA.md Part 5): a preset party (your class plus one of
## each other base class, up to 4) or the party from your current save.
extends RefCounted

const RM := preload("res://src/core/run/run_model.gd")
const Char := preload("res://src/core/character.gd")
const Lv := preload("res://src/core/progression/leveling.gd")

const NAMES := { "mage": "Ash", "fighter": "Brick", "rogue": "Quill", "healer": "Sage", "bard": "Lyric" }


## A fresh run for the arena: the player's class first, then the others in
## data order, all at `level`, full HP and MP.
static func preset_run(db: Dictionary, seed_value: int, player_class: String, size: int, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var run := RM.new_run(db, seed_value, player_class, rng)
	run["mode"] = "arena"
	var others: Array = []
	for c in db.get("classes", {}).get("classes", []):
		if int(c.get("tier", 1)) == 1 and str(c["id"]) != player_class:
			others.append(str(c["id"]))
	# Everyone else waits on the roster, so a checkpoint can swap teammates.
	for i in others.size():
		var cls := str(others[i])
		var ch := Char.create(db, cls, rng, { "id": "arena_" + cls, "name": str(NAMES.get(cls, cls.capitalize())) })
		ch["sprite"] = str(db.get("assets/roles", {}).get("arena_" + cls, db.get("assets/roles", {}).get("debugAlly", "")))
		run["roster"].append(ch)
		run["bonds"][ch["id"]] = 50.0
		if i < size - 1:
			run["party_ids"].append(ch["id"])
	for p in [run["player"]] + run["roster"]:
		while int(p["level"]) < level:
			Lv.add_xp(db, p, Lv.xp_to_next(db, int(p["level"])), rng)
		Lv.auto_perks(db, p)
		Char.full_restore(db, p)
	return run


## Everyone fighting: the player and tonight's party.
static func party(run: Dictionary) -> Array:
	var out: Array = [run["player"]]
	for pid in run.get("party_ids", []):
		var ch := RM.character(run, str(pid))
		if not ch.is_empty():
			out.append(ch)
	return out

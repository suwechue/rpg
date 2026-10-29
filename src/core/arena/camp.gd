## The Arena Campfire (docs/ARENA_CAMPFIRE.md), the pure part: which stations
## and upgrades a camp has, Deli Tickets per wave, the deli's stock and what
## buying does, stat training, and companion talk lines.
extends RefCounted

const Inv := preload("res://src/core/items/inventory.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("arena/campfire", {})


## Stations in this camp (story-only ones only in the Rift).
static func stations(db: Dictionary, story: bool) -> Array:
	return cfg(db).get("stations", []).filter(func(s: Dictionary) -> bool: return story or not bool(s.get("storyOnly", false)))


## Upgrades reached by this wave.
static func upgrades(db: Dictionary, wave: int) -> Array:
	return cfg(db).get("upgrades", []).filter(func(u: Dictionary) -> bool: return wave >= int(u.get("minWave", 0)))


## The camp's zone, with this depth's upgrade props added.
static func zone(db: Dictionary, wave: int) -> Dictionary:
	var z: Dictionary = cfg(db).get("zone", {}).duplicate(true)
	var props: Array = z.get("props", [])
	for u in upgrades(db, wave):
		props.append_array(u.get("props", []))
	z["props"] = props
	return z


## Deli Tickets for clearing a wave.
static func tickets_for(db: Dictionary, boss: bool, elite: bool, no_damage: bool) -> int:
	var t: Dictionary = db.get("arena/checkpoint", {}).get("tickets", {})
	var n := int(t.get("boss", 5)) if boss else (int(t.get("elite", 3)) if elite else int(t.get("perWave", 2)))
	return n + (int(t.get("noDamage", 2)) if no_damage else 0)


static func item(db: Dictionary, id: String) -> Dictionary:
	for it in db.get("arena/deli_stock", {}).get("items", []):
		if str(it.get("id", "")) == id:
			return it
	return {}


## This camp's stock: stockSize items open at this depth (seeded).
static func stock(db: Dictionary, wave: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for it in db.get("arena/deli_stock", {}).get("items", []):
		if wave >= int(it.get("minWave", 0)):
			pool.append(str(it["id"]))
	var out: Array = []
	while out.size() < int(db.get("arena/deli_stock", {}).get("stockSize", 4)) and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


## Buy from the deli with tickets. Returns "" or why not.
## Snacks go in the backpack; a meal replaces the current one; a pack sets
## arena["dealPack"] for the card pick.
static func buy(db: Dictionary, arena: Dictionary, run: Dictionary, id: String) -> String:
	var it := item(db, id)
	if it.is_empty():
		return "unknown"
	if int(arena.get("tickets", 0)) < int(it.get("price", 0)):
		return "tickets"
	match str(it.get("kind", "")):
		"snack":
			var bp: Array = run.get("backpack", [])
			if bp.size() >= int(Inv.cfg(db).get("backpackSize", 6)):
				return "backpack_full"
			bp.append(str(it.get("card", "")))
			run["backpack"] = bp
		"meal":
			arena["meal"] = { "id": id, "name": str(it.get("name", id)), "effects": it.get("effects", {}) }
		"pack":
			arena["dealPack"] = true
	arena["tickets"] = int(arena.get("tickets", 0)) - int(it.get("price", 0))
	return ""


## The meal as a mutator entry for the next waves' fights (or none).
static func meal_mutators(arena: Dictionary) -> Array:
	return [] if not arena.has("meal") else [arena["meal"]]


## Train a member's stat at this camp. perf is the minigame score (0..1).
## Returns { "ok": bool, "gain": int, "why": "" | "used" | "cap" | "ap" }.
static func train(db: Dictionary, arena: Dictionary, ch: Dictionary, stat: String, perf: float) -> Dictionary:
	var t: Dictionary = db.get("arena/checkpoint", {}).get("training", {})
	var id := str(ch.get("id", "player"))
	var used: Dictionary = arena.get("trainedAt", {})
	if int(used.get(id, -1)) == int(arena.get("wave", 0)):
		return { "ok": false, "gain": 0, "why": "used" }
	var gains: Dictionary = arena.get("trainGains", {})
	if int(gains.get(id, 0)) >= int(t.get("capPerRun", 3)):
		return { "ok": false, "gain": 0, "why": "cap" }
	if int(arena.get("ap", 0)) < int(t.get("cost", 1)):
		return { "ok": false, "gain": 0, "why": "ap" }
	arena["ap"] = int(arena["ap"]) - int(t.get("cost", 1))
	used[id] = int(arena.get("wave", 0))
	arena["trainedAt"] = used
	var gain := 1 if perf >= float(t.get("good", 0.5)) else 0
	if gain > 0:
		ch["stats"][stat] = int(ch["stats"].get(stat, 5)) + gain
		gains[id] = int(gains.get(id, 0)) + gain
		arena["trainGains"] = gains
	return { "ok": true, "gain": gain, "why": "" }


## A campfire line for a member: reaction lines whose conditions hold come
## first, then generic ones; no repeats until they run out. ctx: downed,
## bestHit, mutator, deckVector, depth.
static func talk_line(db: Dictionary, arena: Dictionary, member: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> String:
	var lines: Dictionary = db.get("arena/campfire_talk", {}).get("lines", {})
	var id := str(member.get("id", ""))
	var pool: Array = lines.get(id, []) + lines.get(str(member.get("class", "")), []) + lines.get("default", [])
	var said: Dictionary = arena.get("talkSaid", {})
	var used: Array = said.get(id, [])
	var fits: Array = []
	var generic: Array = []
	for l in pool:
		var t := str(l.get("text", ""))
		if used.has(t):
			continue
		if l.has("when"):
			if _holds(l["when"], ctx):
				fits.append(t)
		else:
			generic.append(t)
	var choice: Array = fits if not fits.is_empty() else generic
	if choice.is_empty():
		used = []
		choice = pool.filter(func(l: Dictionary) -> bool: return not l.has("when")).map(func(l: Dictionary) -> String: return str(l.get("text", "")))
	if choice.is_empty():
		return ""
	var line := str(choice[rng.randi_range(0, choice.size() - 1)])
	used.append(line)
	said[id] = used
	arena["talkSaid"] = said
	return line


static func _holds(when: Dictionary, ctx: Dictionary) -> bool:
	for k in when:
		match str(k):
			"depth":
				if int(ctx.get("depth", 0)) < int(when[k]):
					return false
			"deckVector":
				if str(ctx.get("deckVector", "")) != str(when[k]):
					return false
			_:
				if bool(ctx.get(str(k), false)) != bool(when[k]):
					return false
	return true

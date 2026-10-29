## Seeded daily floors (DESIGN.md Section 10, "Daily floor generation").
## A random walk lays rooms on a small grid (seed = run seed + week + day);
## room types follow data/dungeon.json; the exit is the room farthest from the
## start. Friday is the boss floor: returning encounters from the week's log
## (fled-from first, scaled up), a rest room, then the boss.
class_name FloorGenerator
extends RefCounted

const VO := preload("res://src/core/vector_ops.gd")
const Sig := preload("res://src/core/dungeon/signature.gd")
const Enc := preload("res://src/core/dungeon/encounters.gd")
const DT := preload("res://src/core/data_tables.gd")

const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("dungeon", {})


static func floor_rng(run: Dictionary, week: int, day: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("floor:%d:%d:%s" % [int(run.get("seed", 0)), week, day])
	return rng


## Lay out `count` rooms by a random walk from (0, 0). Returns cells in order.
static func walk(count: int, rng: RandomNumberGenerator) -> Array:
	var cells: Array = [Vector2i.ZERO]
	var guard := 0
	while cells.size() < count and guard < 500:
		guard += 1
		var from: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var d: Vector2i = DIRS[rng.randi_range(0, 3)]
		var n := from + d
		if not cells.has(n):
			cells.append(n)
	return cells


static func _bfs(cells: Array, start: Vector2i) -> Dictionary:
	var dist := { start: 0 }
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in DIRS:
			var n: Vector2i = c + d
			if cells.has(n) and not dist.has(n):
				dist[n] = int(dist[c]) + 1
				q.append(n)
	return dist


## Generate a weekday floor.
static func generate(db: Dictionary, run: Dictionary, week: int, day: String) -> Dictionary:
	var rng := floor_rng(run, week, day)
	var day_cfg: Dictionary = cfg(db).get("days", {}).get(day, {})
	if bool(day_cfg.get("boss", false)):
		return generate_boss(db, run, week, rng)
	var mix: Dictionary = day_cfg.get("mix", { "combat": 4, "rest": 1 })
	var types: Array = []
	for t in ["combat", "elite", "event", "treasure", "merchant", "rest"]:
		for i in int(mix.get(t, 0)):
			types.append(t)
	var cells := walk(types.size() + 2, rng)
	var dist := _bfs(cells, Vector2i.ZERO)
	var exit_cell: Vector2i = cells[0]
	for c in cells:
		if int(dist[c]) > int(dist[exit_cell]):
			exit_cell = c
	var middle: Array = []
	for c in cells:
		if c != Vector2i.ZERO and c != exit_cell:
			middle.append(c)
	for i in range(types.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = types[i]
		types[i] = types[j]
		types[j] = tmp
	var rooms: Array = [_room(0, Vector2i.ZERO, "start")]
	for i in middle.size():
		var r := _room(i + 1, middle[i], str(types[i]))
		_fill_room(db, run, week, day, r, rng)
		rooms.append(r)
	rooms.append(_room(rooms.size(), exit_cell, "exit"))
	return { "week": week, "day": day, "theme": str(Sig.week_rec(db, week).get("theme", "school")), "rooms": rooms, "boss": false }


static func _room(id: int, cell: Vector2i, type: String) -> Dictionary:
	return { "id": id, "cell": [cell.x, cell.y], "type": type, "enemies": [], "cleared": type in ["start", "exit"], "scale": 1.0, "layout": "" }


static func _fill_room(db: Dictionary, run: Dictionary, week: int, day: String, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var scales: Array = cfg(db).get("weekScale", [1.0])
	r["scale"] = float(scales[mini(week, scales.size() - 1)])
	match str(r["type"]):
		"combat", "elite":
			# Built from an encounter template (data/encounters.json).
			var enc := Enc.build(db, run, week, str(r["type"]), rng)
			for k in ["enemies", "roles", "affixes", "formation", "reinforcements", "template"]:
				r[k] = enc[k]
			r["layout"] = pick_layout(db, str(Sig.week_rec(db, week).get("theme", "school")), rng, bool(enc["big"]), str(enc["layoutTag"]))
			# M20: sometimes a mirror of a real place, likelier for places touched this week.
			var mirror := pick_mirror(db, run, week, rng)
			if not mirror.is_empty():
				r["mirror"] = str(mirror["id"])
				r["layout"] = pick_layout(db, str(mirror.get("theme", "school")), rng, bool(enc["big"]), str(enc["layoutTag"]))
		"event":
			var evs: Array = []
			for e in db.get("events/dungeon_events", {}).get("events", []):
				var ws: Array = e.get("weeks", [])
				var ok := ws.is_empty()
				for w in ws:
					ok = ok or int(w) == week
				if ok:
					evs.append(str(e["id"]))
			if not evs.is_empty():
				r["event"] = evs[rng.randi_range(0, evs.size() - 1)]


## A mirror room for a fight room, or {} (data/rooms/mirror_rooms.json):
## mirrorChance, then weighted toward places visited this week and story beats seen.
static func pick_mirror(db: Dictionary, run: Dictionary, week: int, rng: RandomNumberGenerator) -> Dictionary:
	var m: Dictionary = db.get("rooms/mirror_rooms", {})
	if m.get("rooms", []).is_empty() or rng.randf() >= float(m.get("mirrorChance", 0.35)):
		return {}
	var visited: Array = run.get("visited", {}).get(str(week), [])
	var weights := {}
	var order: Array = []
	for r in m["rooms"]:
		var w := 1.0
		if visited.has(str(r.get("of", ""))):
			w *= float(m.get("visitedWeight", 3.0))
		for f in r.get("storyFlags", []):
			if bool(run.get("flags", {}).get(str(f), false)):
				w *= float(m.get("storyWeight", 3.0))
				break
		weights[str(r["id"])] = w
		order.append(str(r["id"]))
	var pick := VO.sample(weights, rng, order)
	for r in m["rooms"]:
		if str(r["id"]) == pick:
			return r
	return {}


## A combat layout for a theme (weighted), falling back to any. `big` asks for
## an 11x6 grid (swarms, ambushes); `tag` for layouts tagged in data ("hazard").
static func pick_layout(db: Dictionary, theme: String, rng: RandomNumberGenerator, big: bool = false, tag: String = "") -> String:
	var w := {}
	var order: Array = []
	for l in db.get("rooms/combat_layouts", {}).get("layouts", []):
		var weight := float(l.get("weight", 1))
		if weight <= 0.0:
			continue
		var cols := str(l.get("map", [""])[0]).length()
		if big != (cols >= 11):
			continue
		if tag != "" and not l.get("tags", []).has(tag):
			continue
		var bonus := 3.0 if str(l.get("theme", "")) == theme else 1.0
		w[str(l["id"])] = weight * bonus
		order.append(str(l["id"]))
	if order.is_empty():
		return pick_layout(db, theme, rng, false, "") if (big or tag != "") else "open_field"
	return VO.sample(w, rng, order)


## Friday: start, returning encounters (fled-from first), rest, boss, exit.
static func generate_boss(db: Dictionary, run: Dictionary, week: int, rng: RandomNumberGenerator) -> Dictionary:
	var c := cfg(db)
	var day_cfg: Dictionary = c.get("days", {}).get("fri", {})
	var returning := returning_encounters(db, run, week, int(day_cfg.get("returning", 3)), rng)
	var wr := Sig.week_rec(db, week)
	var theme := str(wr.get("theme", "school"))
	var rooms: Array = [_room(0, Vector2i.ZERO, "start")]
	var x := 1
	var scales: Array = c.get("weekScale", [1.0])
	for enc in returning:
		var r := _room(rooms.size(), Vector2i(x, 0), "combat")
		r["enemies"] = enc["enemies"]
		r["returning"] = true
		r["fled"] = bool(enc.get("fled", false))
		r["scale"] = float(scales[mini(week, scales.size() - 1)]) * float(c.get("returningScale", 1.25)) * (1.15 if bool(enc.get("fled", false)) else 1.0)
		r["layout"] = pick_layout(db, theme, rng)
		rooms.append(r)
		x += 1
	rooms.append(_room(rooms.size(), Vector2i(x, 0), "rest"))
	x += 1
	var boss := _room(rooms.size(), Vector2i(x, 0), "boss")
	boss["enemies"] = [str(wr.get("boss", ""))]
	boss["layout"] = str(wr.get("bossLayout", "boss_stage"))
	boss["scale"] = 1.0
	var adds: Dictionary = db.get("encounters", {}).get("bossAdds", {}).get(str(week), {})
	if not adds.is_empty():
		boss["reinforcements"] = { "round": int(adds.get("round", 4)), "enemies": adds.get("enemies", []) }
	rooms.append(boss)
	rooms.append(_room(rooms.size(), Vector2i(x + 1, 0), "exit"))
	return { "week": week, "day": "fri", "theme": theme, "rooms": rooms, "boss": true }


## The week's logged encounters to bring back: fled-from first, then the rest
## in log order, then fresh picks if the log is short.
static func returning_encounters(db: Dictionary, run: Dictionary, week: int, count: int, rng: RandomNumberGenerator) -> Array:
	var fled: Array = []
	var fought: Array = []
	for e in run.get("encounter_log", []):
		if int(e.get("week", 0)) != week or e.get("enemies", []).is_empty():
			continue
		if str(e.get("result", "")) == "flee":
			fled.append({ "enemies": e["enemies"], "fled": true })
		else:
			fought.append({ "enemies": e["enemies"], "fled": false })
	var out: Array = fled.slice(0, count)
	var i := fought.size() - 1
	while out.size() < count and i >= 0:
		out.append(fought[i])
		i -= 1
	while out.size() < count:
		out.append({ "enemies": Sig.pick_enemies(db, run, week, "normal", 3, rng), "fled": false })
	return out


## Log a fight for Friday.
static func log_encounter(run: Dictionary, week: int, day: String, room: Dictionary, result: String) -> void:
	run["encounter_log"].append({ "week": week, "day": day, "room": int(room.get("id", 0)), "enemies": room.get("enemies", []), "result": result })


static func room_by_id(floor_dict: Dictionary, id: int) -> Dictionary:
	for r in floor_dict.get("rooms", []):
		if int(r["id"]) == id:
			return r
	return {}


## Rooms adjacent to a room on the floor grid.
static func neighbors(floor_dict: Dictionary, room: Dictionary) -> Array:
	var out: Array = []
	var c := Vector2i(int(room["cell"][0]), int(room["cell"][1]))
	for r in floor_dict.get("rooms", []):
		var rc := Vector2i(int(r["cell"][0]), int(r["cell"][1]))
		if absi(rc.x - c.x) + absi(rc.y - c.y) == 1:
			out.append(r)
	return out

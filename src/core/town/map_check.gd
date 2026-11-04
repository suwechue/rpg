## Map validation (ROADMAP M12): checks zone scenes (as read by
## src/world/zone_reader.gd) against data/town/locations.json and the NPCs.
## Every outdoor location and building has a door or spot in its zone, every
## room has a door in an interior, every NPC home exists, and every exit leads
## to a zone and lands on a walkable tile. Returns readable problems.
extends RefCounted

const DT := preload("res://src/core/data_tables.gd")


## Tiles that block walking in a read zone: objects, collision, water, buildings.
static func blocked(z: Dictionary) -> Dictionary:
	var out := {}
	for key in ["Objects", "Collision", "Water"]:
		for t in z.get(key, []):
			out[t["cell"]] = true
	for d in z.get("doors", []):
		var r: Rect2i = d["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				out[Vector2i(x, y)] = true
		out[d["cell"]] = true
	return out


static func problems(db: Dictionary, zones: Dictionary) -> Array:
	var out: Array = []
	var locs: Array = db.get("town/locations", {}).get("locations", [])
	var ids := {}
	for l in locs:
		ids[str(l["id"])] = l
	var room_doors := {}
	for it in db.get("town/interiors", {}).get("interiors", []):
		for d in it.get("roomDoors", it.get("doors", [])):
			if d is Dictionary and d.has("to"):
				room_doors[str(d["to"])] = true
	for l in locs:
		var id := str(l["id"])
		var zone := str(l.get("zone", ""))
		if str(l.get("kind", "")) == "room":
			if not room_doors.has(id):
				out.append("location %s: a room with no door in any interior" % id)
			continue
		if not zones.has(zone):
			continue
		var z: Dictionary = zones[zone]
		var found: bool = z["doors"].any(func(d: Dictionary) -> bool: return str(d["loc"]) == id) or z["spots"].any(func(s: Dictionary) -> bool: return str(s["id"]) == id)
		if not found:
			out.append("location %s: no door marker or spot in zone %s" % [id, zone])
	for zid in zones:
		var z: Dictionary = zones[zid]
		for d in z["doors"]:
			if not ids.has(str(d["loc"])):
				out.append("zone %s: door marker for unknown location '%s'" % [zid, d["loc"]])
		for e in z["exits"]:
			var to := str(e["to"])
			if not zones.has(to):
				out.append("zone %s: exit to unknown zone '%s'" % [zid, to])
				continue
			var sp: Vector2i = e["spawn"]
			var t: Vector2i = zones[to]["tiles"]
			if sp.x < 0 or sp.y < 0 or sp.x >= t.x or sp.y >= t.y or blocked(zones[to]).has(sp):
				out.append("zone %s: exit to %s lands on a blocked or outside tile %s" % [zid, to, str(sp)])
				continue
			# Clipping checks: never land inside the next zone's exits (an instant
			# bounce back), and always be able to walk back the way you came.
			for e2 in zones[to]["exits"]:
				if (e2["rect"] as Rect2i).has_point(sp):
					out.append("zone %s: exit to %s lands inside that zone's exit to %s at %s" % [zid, to, e2["to"], str(sp)])
			if not _reaches_exit(zones[to], sp, zid):
				out.append("zone %s: from the spawn %s in %s you can't walk back to %s" % [zid, str(sp), to, zid])
	for key in db:
		if str(key).begins_with("npcs/"):
			var home := str(db[key].get("home", ""))
			if home != "" and not ids.has(home):
				out.append("%s: home '%s' is not a location" % [key, home])
	return out


## Can someone standing at `from` in zone `z` walk to an exit leading to `back`?
static func _reaches_exit(z: Dictionary, from: Vector2i, back: String) -> bool:
	var block := blocked(z)
	var t: Vector2i = z["tiles"]
	var goals: Array = []
	for e in z["exits"]:
		if str(e["to"]) == back:
			goals.append(e["rect"])
	if goals.is_empty():
		return true
	var seen := { from: true }
	var queue: Array = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			for g in goals:
				if (g as Rect2i).has_point(n):
					return true
			if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= t.x or n.y >= t.y or block.has(n):
				continue
			seen[n] = true
			queue.append(n)
	return false

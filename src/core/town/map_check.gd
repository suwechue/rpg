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
	for key in db:
		if str(key).begins_with("npcs/"):
			var home := str(db[key].get("home", ""))
			if home != "" and not ids.has(home):
				out.append("%s: home '%s' is not a location" % [key, home])
	return out

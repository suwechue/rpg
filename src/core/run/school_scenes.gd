## Class periods as cutscenes (ROADMAP M13, user decision Oct 28): the bell
## and the walk to class, then the class with the teacher at the board and a
## seating chart of the classmates (data/school_classes.json) around you.
## Builds cutscene steps (src/core/story/cutscenes.gd) from data/school_scenes.json.
extends RefCounted


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("school_scenes", {})


static func _pick(list: Array, rng: RandomNumberGenerator) -> String:
	return "" if list.is_empty() else str(list[rng.randi_range(0, list.size() - 1)])


static func fill(text: String, vars: Dictionary) -> String:
	for k in vars:
		text = text.replace("{%s}" % k, str(vars[k]))
	return text


## Desks in rows: the classmates in a seeded order with you in one seat.
## { "rows": [[names or "" for empty]], "you": Vector2i(col, row), "mates": [ids] }
static func seating(db: Dictionary, cls: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cols := int(cfg(db).get("seatCols", 4))
	var rows := int(cfg(db).get("seatRows", 2))
	var mates: Array = cls.get("classmates", []).duplicate()
	for i in range(mates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = mates[i]
		mates[i] = mates[j]
		mates[j] = t
	mates = mates.slice(0, cols * rows - 1)
	var you := rng.randi_range(0, mini(cols * rows - 1, mates.size()))
	var grid: Array = []
	var k := 0
	for r in rows:
		var row: Array = []
		for c in cols:
			var i := r * cols + c
			if i == you:
				row.append("@you")
			elif k < mates.size():
				row.append(str(mates[k]))
				k += 1
			else:
				row.append("")
		grid.append(row)
	return { "rows": grid, "you": Vector2i(you % cols, you / cols), "mates": mates }


## The two cutscenes for a period: the walk (with the bell) and the class.
static func steps(db: Dictionary, cls: Dictionary, period: int, teacher: String, rng: RandomNumberGenerator) -> Array:
	var room := str(cls.get("room", "class")).capitalize()
	for l in db.get("town/locations", {}).get("locations", []):
		if str(l.get("id", "")) == str(cls.get("room", "")):
			room = str(l.get("name", room))
	var seats := seating(db, cls, rng)
	var mate := ""
	if not seats["mates"].is_empty():
		var mid := str(seats["mates"][0])
		mate = str(db.get("npcs/" + mid, {}).get("name", mid.capitalize()))
	var vars := { "class": str(cls.get("name", "")), "teacher": teacher, "room": room, "period": period, "mate": mate }
	var out: Array = [
		{ "type": "sfx", "event": "bell" },
		{ "type": "image", "id": "art_school_hall" },
		{ "type": "narrator", "text": fill(_pick(cfg(db).get("walkLines", []), rng), vars) },
		{ "type": "image", "id": "art_class_" + str(cls.get("id", "")) },
		{ "type": "title_card", "text": "%d: %s" % [period, str(cls.get("name", ""))], "seconds": 1.0 },
		{ "type": "narrator", "text": fill(_pick(cfg(db).get("classLines", []), rng), vars) },
		{ "type": "seating", "title": str(cls.get("name", "")), "rows": seats["rows"] },
	]
	if mate != "":
		out.append({ "type": "narrator", "text": fill(_pick(cfg(db).get("mateLines", []), rng), vars) })
	out.append({ "type": "image", "id": "" })
	return out

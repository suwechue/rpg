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


## The class as a real scene (user request, Oct 29): the room's interior, the
## teacher's tile at the board, and seats behind the desks filled from the
## seating chart. { "interior", "teacher": [x, y], "seats": [[x, y, who]] }.
static func stage(db: Dictionary, cls: Dictionary, seats: Dictionary) -> Dictionary:
	var sc: Dictionary = cfg(db).get("stage", {})
	var iid := str(sc.get("rooms", {}).get(str(cls.get("room", "")), sc.get("default", "classroom")))
	var rec: Dictionary = {}
	for it in db.get("town/interiors", {}).get("interiors", []):
		if str(it.get("id", "")) == iid:
			rec = it
	if rec.is_empty():
		return {}
	var size: Array = rec.get("size", [1, 1])
	var top := int(rec.get("wallRows", 2))
	var cells: Array = []
	var teacher: Array = []
	var kinds: Array = sc.get("seatKinds", ["desk"])
	for f in rec.get("furniture", []):
		var r: Array = f.get("rect", [0, 0, 1, 1])
		if str(f.get("kind", "")) == "board" and teacher.is_empty():
			teacher = [int(r[0]) + int(r[2]) / 2, int(r[1]) + 1]
		elif kinds.has(str(f.get("kind", ""))):
			for x in range(int(r[0]), int(r[0]) + int(r[2])):
				var y := int(r[1]) + int(r[3])
				if y < int(size[1]):
					cells.append([x, y])
	# No desks (the gym): stand in rows in the open middle of the room.
	if cells.is_empty():
		for y in range(top + 4, int(size[1]) - 1, 2):
			for x in range(3, int(size[0]) - 3, 2):
				cells.append([x, y])
	if teacher.is_empty():
		var spots: Array = rec.get("npcSpots", [[int(size[0]) / 2, top + 1]])
		teacher = [int(spots[0][0]), int(spots[0][1])]
	var who: Array = []
	for row in seats.get("rows", []):
		for s in row:
			who.append(str(s))
	var out: Array = []
	for i in mini(cells.size(), who.size()):
		if who[i] != "":
			out.append([int(cells[i][0]), int(cells[i][1]), who[i]])
	# Everyone needs a seat: if the room has fewer seats than the chart, you take one anyway.
	if not out.any(func(s: Array) -> bool: return str(s[2]) == "@you") and not cells.is_empty():
		if out.is_empty():
			out.append([int(cells[0][0]), int(cells[0][1]), "@you"])
		else:
			out[-1][2] = "@you"
	return { "interior": iid, "teacher": teacher, "teacherId": str(cls.get("professor", "")), "seats": out }


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
		{ "type": "stage", "interior": str(cfg(db).get("stage", {}).get("hall", "school_hall")), "walk": true, "students": seats["mates"].slice(0, int(cfg(db).get("stage", {}).get("hallStudents", 3))) },
		{ "type": "narrator", "text": fill(_pick(cfg(db).get("walkLines", []), rng), vars) },
		{ "type": "image", "id": "art_class_" + str(cls.get("id", "")) },
		{ "type": "title_card", "text": "%d: %s" % [period, str(cls.get("name", ""))], "seconds": 1.0 },
		{ "type": "narrator", "text": fill(_pick(cfg(db).get("classLines", []), rng), vars) },
		{ "type": "seating", "title": str(cls.get("name", "")), "rows": seats["rows"], "stage": stage(db, cls, seats) },
	]
	if mate != "":
		out.append({ "type": "narrator", "text": fill(_pick(cfg(db).get("mateLines", []), rng), vars) })
	out.append({ "type": "image", "id": "" })
	return out

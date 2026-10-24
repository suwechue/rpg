## The walkable town: four zones and the interiors of OPEN places. Walking is
## free; E interacts with whatever you face (a door, a person, furniture) or the
## place you stand in. Flow runs classes, night and other screens on top.
## Position persists in run["town_pos"] = { "map", "interior", "cell" }.
extends Node2D

const MapScript := preload("res://src/scenes/town/town_map.gd")
const Walker := preload("res://src/scenes/common/walker_sprite.gd")
const Modal := preload("res://src/scenes/ui/modal.gd")
const Workbench := preload("res://src/scenes/ui/workbench_screen.gd")
const ShopScreen := preload("res://src/scenes/town/shop_screen.gd")
const Locs := preload("res://src/core/town/locations.gd")
const Sched := preload("res://src/core/town/schedule.gd")
var TILE: int:
	get: return Display.tile
const STEP_TIME := 0.11

var map: MapScript
var map_id := "residential"
var interior := false
var interior_loc := ""        # location id whose interior we're in
var return_cell := Vector2i.ZERO
var return_zone := ""
var cell := Vector2i(5, 38)
var facing := Vector2i.DOWN
var player: Walker
var npcs: Dictionary = {}     # cell -> npc id
var _npc_nodes: Array = []
var _camera: Camera2D
var _moving := false
var _prompt: Label


func _ready() -> void:
	if not GameState.has_run():
		GameState.new_run()
	player = Walker.new(str(GameState.player.get("sprite", Assets.role("player"))))
	player.z_index = 5
	_camera = Camera2D.new()
	_prompt = UiTheme.world_label("", UiTheme.ACCENT)
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	_prompt.position = Vector2(4, Display.base.y - 40)
	ui.add_child(_prompt)
	var pos: Dictionary = GameState.run.get("town_pos", {})
	if pos.is_empty():
		_load_map("residential", false, "", _home_door_cell())
	else:
		var c: Array = pos.get("cell", [5, 5])
		return_zone = str(pos.get("returnZone", ""))
		var rc: Array = pos.get("returnCell", [0, 0])
		return_cell = Vector2i(int(rc[0]), int(rc[1]))
		_load_map(str(pos.get("map", "residential")), bool(pos.get("interior", false)), str(pos.get("loc", "")), Vector2i(int(c[0]), int(c[1])))
	EventBus.part_started.connect(_on_part_started)
	EventBus.screen_closed.connect(func(_s: String) -> void: _refresh_people())
	Flow.set_hud(true)
	_on_part_started()
	Flow.begin()


func _exit_tree() -> void:
	_save_pos()


# --- Maps ------------------------------------------------------------------------

func _load_map(id: String, is_int: bool, loc: String, at: Vector2i) -> void:
	if map != null:
		map.queue_free()
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	map = MapScript.new()
	map.build(DataDB.all(), id, is_int)
	add_child(map)
	map.add_child(player)
	map_id = id
	interior = is_int
	interior_loc = loc
	cell = at
	if not map.walkable(cell):
		cell = _nearest_free(cell)
	player.position = _cell_pos(cell)
	player.face(facing)
	if _camera.get_parent() != null:
		_camera.get_parent().remove_child(_camera)
	player.add_child(_camera)
	_camera.position = Vector2(TILE / 2.0, -TILE / 2.0)
	var w := map.size.x * TILE
	var h := map.size.y * TILE
	var view := Display.base
	if w <= view.x:
		_camera.limit_left = (w - view.x) / 2
		_camera.limit_right = _camera.limit_left + view.x
	else:
		_camera.limit_left = 0
		_camera.limit_right = w
	# Room above the map for the HUD bar, below it for the bottom bar.
	if h <= view.y:
		_camera.limit_top = (h - view.y) / 2 - TILE
		_camera.limit_bottom = _camera.limit_top + view.y
	else:
		_camera.limit_top = -TILE
		_camera.limit_bottom = h + TILE
	_camera.make_current()
	_refresh_people()
	_save_pos()
	if not interior:
		Audio.play_music("weekend" if Calendar.is_weekend() else str(DataDB.table("town/zones/" + id).get("music", "town")))


func _cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE, (c.y + 1) * TILE)


func _nearest_free(c: Vector2i) -> Vector2i:
	for r in range(1, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if map.walkable(n) and not npcs.has(n):
					return n
	return c


func _home_door_cell() -> Vector2i:
	return Vector2i(4, 37)


func _save_pos() -> void:
	if not GameState.has_run():
		return
	GameState.run["town_pos"] = { "map": map_id, "interior": interior, "loc": interior_loc, "cell": [cell.x, cell.y],
		"returnZone": return_zone, "returnCell": [return_cell.x, return_cell.y] }
	GameState.run["resume_scene"] = scene_file_path


## Each part may start somewhere specific (calendar.json "start": home or school).
func _on_part_started() -> void:
	var part: Dictionary = Calendar.current_part()
	var start := str(part.get("start", ""))
	if bool(part.get("wholePart", false)):
		start = "school"
	if start == "home":
		_enter_interior("player_home", "residential", _home_door_cell())
	elif start == "school":
		_load_map("school", false, "", Vector2i(29, 14))
	else:
		_refresh_people()


func _enter_interior(loc: String, zone: String, back_cell: Vector2i) -> void:
	var r := Locs.rec(DataDB.all(), loc)
	return_zone = zone
	return_cell = back_cell
	var tmpl := str(r.get("interior", ""))
	var t := Locs.interior(DataDB.all(), tmpl)
	var sz: Array = t.get("size", [12, 10])
	facing = Vector2i.UP
	_load_map(tmpl, true, loc, Vector2i(int(sz[0]) / 2, int(sz[1]) - 2))
	Audio.play_sfx("door")
	Narrator.say(_enter_line(loc))


func _enter_line(loc: String) -> String:
	var r := Locs.rec(DataDB.all(), loc)
	var people := Sched.people_at(DataDB.all(), GameState.run, loc, Calendar.day_name(), Calendar.part_id(), int(GameState.run.get("day_count", 0)))
	var names: Array = []
	for p in people:
		names.append(str(DataDB.table("npcs/" + str(p)).get("name", p)))
	if names.is_empty():
		return "%s. Nobody you know is here." % r.get("name", loc)
	return "%s. Here: %s." % [r.get("name", loc), ", ".join(PackedStringArray(names))]


func _leave_interior() -> void:
	var r := Locs.rec(DataDB.all(), interior_loc)
	if str(r.get("parent", "")) != "":
		var parent := str(r["parent"])
		var hall := Locs.interior(DataDB.all(), str(Locs.rec(DataDB.all(), parent).get("interior", "")))
		var back := Vector2i(15, 3)
		for d in hall.get("doors", []):
			if str(d["to"]) == interior_loc:
				back = Vector2i(int(d["at"][0]), int(d["at"][1]) + 1)
		_load_map(str(Locs.rec(DataDB.all(), parent).get("interior", "")), true, parent, back)
		return
	facing = Vector2i.DOWN
	_load_map(return_zone if return_zone != "" else "residential", false, "", return_cell)
	Audio.play_sfx("door")


# --- People ------------------------------------------------------------------------------

## Place everyone who is here now: at outdoor spots in zones, at the npc spots
## inside interiors. Residents at home light their windows.
func _refresh_people() -> void:
	for n in _npc_nodes:
		n.queue_free()
	_npc_nodes.clear()
	npcs.clear()
	if map == null:
		return
	var db: Dictionary = DataDB.all()
	var run: Dictionary = GameState.run
	var day := Calendar.day_name()
	var part := Calendar.part_id()
	var dc := int(run.get("day_count", 0))
	if interior:
		var spots: Array = map.npc_spots()
		var i := 0
		for id in Sched.people_at(db, run, interior_loc, day, part, dc):
			if i >= spots.size():
				break
			_place_npc(str(id), spots[i])
			i += 1
	else:
		for loc in map.spots:
			var anchor: Vector2i = map.spots[loc]
			for id in Sched.people_at(db, run, str(loc), day, part, dc):
				_place_npc(str(id), _free_near(anchor))
		map.lit = []
		map.shut = {}
		for b in map.buildings:
			var loc := str(b["loc"])
			if not Locs.residents_home(db, run, loc, day, part, dc).is_empty():
				map.lit.append(loc)
			var st := Locs.status(db, run, loc)
			if st == "CLOSED" or st == "STORY":
				map.shut[loc] = st
	if interior and str(Locs.rec(db, interior_loc).get("interior", "")) == "school_hall":
		map.shut = {}
		for c in map.room_doors:
			var room := str(map.room_doors[c])
			var st := Locs.status(db, run, room)
			if st == "CLOSED" or st == "STORY":
				map.shut[room] = st
	map.refresh_overlay()


func _free_near(anchor: Vector2i) -> Vector2i:
	if map.walkable(anchor) and not npcs.has(anchor) and anchor != cell:
		return anchor
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := anchor + Vector2i(dx, dy)
				if map.walkable(n) and not npcs.has(n) and n != cell:
					return n
	return anchor


func _place_npc(id: String, at: Vector2i) -> void:
	var rec: Dictionary = DataDB.table("npcs/" + id)
	var w := Walker.new(str(rec.get("sprite", "")))
	w.position = _cell_pos(at)
	w.z_index = 4
	w.face(Vector2i.DOWN)
	map.add_child(w)
	_npc_nodes.append(w)
	npcs[at] = id
	var tag := UiTheme.world_label(str(rec.get("name", id)).split(" ")[0], UiTheme.LABEL)
	tag.position = Vector2((w.frame_size.x - tag.get_minimum_size().x) / 2.0, -w.frame_size.y - UiTheme.FONT_SIZE - 3)
	w.add_child(tag)


# --- Movement -------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	# Only the closest person within reach shows a name tag, so crowds stay readable.
	var nearest: Node2D = null
	var best := TILE * 3.5
	for w in _npc_nodes:
		var d: float = w.position.distance_to(player.position)
		if d <= best:
			best = d
			nearest = w
	for w in _npc_nodes:
		if w.get_child_count() > 0:
			w.get_child(w.get_child_count() - 1).visible = w == nearest
	if _moving or Flow.is_busy() or map == null:
		_update_prompt()
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_up"):
		dir = Vector2i.UP
	elif Input.is_action_pressed("move_down"):
		dir = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"):
		dir = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"):
		dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		step(dir)
	_update_prompt()


## One tile step (free). Also used by tests.
func step(dir: Vector2i) -> void:
	facing = dir
	player.face(dir)
	var next := cell + dir
	for e in map.exits:
		var r: Rect2i = e["rect"]
		if r.has_point(next):
			_load_map(str(e["to"]), false, "", e["spawn"])
			return
	if interior and next == map.interior_exit + Vector2i(0, 1):
		_leave_interior()
		return
	if interior and cell == map.interior_exit and dir == Vector2i.DOWN:
		_leave_interior()
		return
	if not map.walkable(next) or npcs.has(next):
		return
	_moving = true
	cell = next
	var tw := create_tween()
	tw.tween_property(player, "position", _cell_pos(cell), STEP_TIME)
	player.play_walk(STEP_TIME)
	await tw.finished
	_moving = false
	if not Input.is_anything_pressed():
		player.stop()


func _unhandled_input(event: InputEvent) -> void:
	if Flow.is_busy():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact()


# --- Interaction -----------------------------------------------------------------------------

## The cell you're facing. Across a counter or desk, it's the person behind it.
func _front() -> Vector2i:
	var f := cell + facing
	if map != null and map.furniture.has(f) and str(map.furniture[f].get("kind", "")) in ["counter", "desk"] and npcs.has(f + facing):
		return f + facing
	return f


## What E would do right now, for the prompt line.
func _update_prompt() -> void:
	if Flow.is_busy() or map == null:
		_prompt.text = ""
		return
	var f := _front()
	var text := ""
	if npcs.has(f):
		text = "[E] Talk to %s" % DataDB.table("npcs/" + str(npcs[f])).get("name", "")
	elif map.doors.has(f):
		text = "[E] %s" % Locs.rec(DataDB.all(), str(map.doors[f]["loc"])).get("name", "Door")
	elif map.room_doors.has(f):
		text = "[E] %s" % Locs.rec(DataDB.all(), str(map.room_doors[f])).get("name", "Door")
	elif map.furniture.has(f) and map.furniture[f].has("label"):
		text = "[E] %s" % map.furniture[f]["label"]
	elif map.signs.has(f):
		text = "[E] Read sign"
	else:
		var loc := _spot_here()
		if loc != "":
			text = "[E] %s" % Locs.rec(DataDB.all(), loc).get("name", loc)
		elif interior:
			text = "[E] Look around %s" % Locs.rec(DataDB.all(), interior_loc).get("name", "")
	_prompt.text = text


## The outdoor location whose spot is within 2 tiles, if any.
func _spot_here() -> String:
	if interior:
		return ""
	for loc in map.spots:
		var s: Vector2i = map.spots[loc]
		if absi(s.x - cell.x) + absi(s.y - cell.y) <= 2:
			return str(loc)
	return ""


func interact() -> void:
	var db: Dictionary = DataDB.all()
	var f := _front()
	if npcs.has(f):
		await Social.talk(str(npcs[f]))
		_refresh_people()
		return
	if map.doors.has(f):
		await _use_door(str(map.doors[f]["loc"]), map.doors[f]["approach"])
		return
	if map.room_doors.has(f):
		var room := str(map.room_doors[f])
		var reason := Locs.closed_reason(db, GameState.run, room, Calendar.week(), Calendar.part_id())
		if reason != "":
			Narrator.say(reason)
		else:
			_enter_interior(room, return_zone, return_cell)
		return
	if map.signs.has(f):
		Narrator.say("The sign says: \"%s\"" % map.signs[f])
		return
	if map.furniture.has(f):
		var kind := str(map.furniture[f].get("kind", ""))
		if kind == "workbench":
			await _workbench(interior_loc)
			return
		if kind == "door_locked" and interior_loc == "hospital":
			var reason := Locs.closed_reason(db, GameState.run, "hospital_closed_wing", Calendar.week(), Calendar.part_id())
			if reason != "":
				Narrator.say(reason)
			else:
				_enter_interior("hospital_closed_wing", return_zone, return_cell)
			return
	var loc := interior_loc if interior else _spot_here()
	if loc != "":
		await location_menu(loc)
	else:
		Narrator.say("Nothing to do here. Walking is free; everything else costs time.")


func _use_door(loc: String, approach: Vector2i) -> void:
	var db: Dictionary = DataDB.all()
	var d := Locs.door(db, GameState.run, loc, Calendar.week(), Calendar.day_name(), Calendar.part_id(), int(GameState.run.get("day_count", 0)))
	match str(d["kind"]):
		"enter":
			if Locs.rec(db, loc).get("interior", "") != "":
				_enter_interior(loc, map_id, approach)
			else:
				await location_menu(loc)
		"walkup":
			await location_menu(loc)
		"doorstep":
			var who: Array = d["npcs"]
			var names: Array = who.map(func(n: Variant) -> String: return str(DataDB.table("npcs/" + str(n)).get("name", n)))
			Narrator.say("%s comes to the door." % " and ".join(PackedStringArray(names)))
			await Social.talk(str(who[0]), { "doorstep": true })
		_:
			Narrator.say(str(d["text"]))


## A place's menu: activities (AP), shop (1 AP per visit), workbench, bus.
func location_menu(loc: String) -> void:
	var db: Dictionary = DataDB.all()
	var r := Locs.rec(db, loc)
	var reason := Locs.closed_reason(db, GameState.run, loc, Calendar.week(), Calendar.part_id())
	if reason != "" and str(r.get("kind", "")) == "outdoor":
		Narrator.say(reason)
		return
	var m := Modal.new()
	m.build(str(r.get("name", loc)), 380)
	m.text("AP left: %d   $%d" % [Calendar.ap(), GameState.money], UiTheme.DIM)
	var acts := Locs.activities(db, GameState.run, loc, Calendar.part_id(), GameState.ctx())
	for a in acts:
		var act: Dictionary = a
		var cost := int(act.get("ap", 1))
		var price := int(act.get("money", 0))
		var label := "%s (%d AP%s)" % [act.get("label", "?"), cost, ", $%d" % price if price > 0 else ""]
		m.add_button(label, func() -> void: m.finish({ "act": act }), Calendar.ap() < cost or price > GameState.money)
	if r.has("shop"):
		var visit := int(DataDB.table("town/shops").get("rules", {}).get("visitAp", 1))
		m.add_button("Shop (%d AP per visit)" % visit, func() -> void: m.finish({ "shop": str(r["shop"]) }), Calendar.ap() < visit)
	if r.has("workbench"):
		m.add_button("Workbench (craft %d AP)" % int(r["workbench"]), func() -> void: m.finish({ "workbench": true }))
	if bool(r.get("busStop", false)):
		for z in ["school", "downtown", "residential", "outskirts"]:
			if z != map_id:
				var zone := str(z)
				m.add_button("Take the bus to %s (free)" % DataDB.table("town/zones/" + z).get("name", z), func() -> void: m.finish({ "bus": zone }))
	m.add_button("Leave", func() -> void: m.finish(null))
	var picked: Variant = await Flow.show_modal(m)
	if picked == null:
		return
	var p: Dictionary = picked
	if p.has("act"):
		var act: Dictionary = p["act"]
		if not Calendar.spend_ap(int(act.get("ap", 1)), "activity:" + loc):
			return
		if int(act.get("money", 0)) > 0:
			GameState.spend_money(int(act["money"]))
		var lines := GameState.apply_effects(act.get("effects", {}))
		Narrator.say(("%s %s" % [str(act.get("say", "")), " ".join(PackedStringArray(lines))]).strip_edges())
	elif p.has("shop"):
		var visit := int(DataDB.table("town/shops").get("rules", {}).get("visitAp", 1))
		if Calendar.spend_ap(visit, "shop:" + str(p["shop"])):
			var s := ShopScreen.new()
			s.shop_id = str(p["shop"])
			await Flow.show_modal(s)
	elif p.has("workbench"):
		await _workbench(loc)
	elif p.has("bus"):
		var spawn := { "school": Vector2i(29, 14), "downtown": Vector2i(27, 18), "residential": Vector2i(30, 19), "outskirts": Vector2i(52, 18) }
		_load_map(str(p["bus"]), false, "", spawn[str(p["bus"])])
		Narrator.say("The bus is empty except for a driver who doesn't blink. You arrive anyway.")
	_refresh_people()


func _workbench(loc: String) -> void:
	var wb := Workbench.new()
	wb.craft_ap = int(Locs.rec(DataDB.all(), loc).get("workbench", 2))
	wb.place = str(Locs.rec(DataDB.all(), loc).get("name", loc))
	await Flow.show_modal(wb)

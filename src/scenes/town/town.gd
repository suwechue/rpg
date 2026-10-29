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
const StoryRules := preload("res://src/core/story/story.gd")
const Crowd := preload("res://src/core/town/crowd.gd")
var _light: CanvasModulate
var _particles: CPUParticles2D
var _cars: Array = []
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
var crowd: Dictionary = {}    # cell -> generated person (M17)
var _followers: Array = []    # party walkers following the player (M17)
var _trail: Array = []        # the player's last cells, newest first
var _wander_t := 0.0
var _steps := 0
var _bark_until: Dictionary = {}  # walker instance id -> time a bark may play again
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

## M13: your locker at school. Items move between it and your inventory;
## friends' notes (run["lockerNotes"], filled in by M18) are taped inside.
func _locker() -> void:
	const LockerRules := preload("res://src/core/town/locker.gd")
	while true:
		var m := Modal.new()
		m.build(Strings.t("locker.title"), 340)
		var notes: Array = GameState.run.get("lockerNotes", [])
		m.text(Strings.t("locker.notes") if not notes.is_empty() else Strings.t("locker.no_notes"), UiTheme.DIM)
		for n in notes:
			m.text("- " + str(n))
		m.text(Strings.t("locker.inside"), UiTheme.ACCENT)
		var inside: Dictionary = GameState.run.get("locker", {})
		if inside.is_empty():
			m.text(Strings.t("locker.empty"), UiTheme.DIM)
		for id in inside:
			var iid := str(id)
			m.add_button(Strings.t("locker.take") % [str(DataDB.record("items", iid).get("name", iid)), int(inside[id])], func() -> void: m.finish(["take", iid]))
		var inv: Dictionary = GameState.run.get("inventory", {})
		for id in inv:
			if int(inv[id]) > 0:
				var iid := str(id)
				m.add_button(Strings.t("locker.store") % [str(DataDB.record("items", iid).get("name", iid)), int(inv[id])], func() -> void: m.finish(["store", iid]))
		m.add_button(Strings.t("locker.close"), func() -> void: m.finish(null))
		var r: Variant = await Flow.show_modal(m)
		if r == null:
			return
		if str(r[0]) == "take":
			LockerRules.take(GameState.run, str(r[1]))
		else:
			LockerRules.store(GameState.run, str(r[1]))


## M17: a generated person: who they are, a rumor, and maybe a small favor.
func _talk_crowd(p: Dictionary) -> void:
	var db: Dictionary = DataDB.all()
	var lines: Array = [Strings.t("crowd.intro") % [str(p.get("name", "")), str(p.get("trait", {}).get("text", ""))], Strings.t("crowd.rumor") % str(p.get("rumor", ""))]
	var favor: Dictionary = DataDB.table("town/crowd").get("favors", [])[int(p["favor"])] if int(p.get("favor", -1)) >= 0 else {}
	var choices: Array = []
	if not favor.is_empty():
		lines.append(str(favor.get("text", "")))
		choices.append({ "label": Strings.t("crowd.favor_help") % int(favor.get("ap", 1)), "cond": { "minAp": int(favor.get("ap", 1)) },
			"effects": favor.get("effects", {}).merged({ "ap": -int(favor.get("ap", 1)) }) })
		choices.append({ "label": Strings.t("crowd.favor_no"), "effects": {} })
	var r: Variant = await Flow.show_event({ "title": Strings.t("crowd.talk_title") % str(p.get("name", "")), "text": "\n".join(PackedStringArray(lines)), "choices": choices })
	# Helping uses the favor up (the helping choice is the one that costs AP).
	if not favor.is_empty() and r is Dictionary and (r as Dictionary).get("effects", {}).has("ap"):
		p["favor"] = -1


## Stories tied to a place play when the player gets there (within reach of
## the location's door or spot, or anywhere in its zone).
func _check_place_stories() -> void:
	if map == null or Flow.is_busy():
		return
	var near: Array = []
	var reach := int(DataDB.table("town/styles").get("storyReach", 4))
	if interior:
		near.append(interior_loc)
	else:
		for loc in map.door_by_loc:
			if (map.door_by_loc[loc] as Vector2i - cell).length() <= reach:
				near.append(str(loc))
		for loc in map.spots:
			if (map.spots[loc] as Vector2i - cell).length() <= reach:
				near.append(str(loc))
	for id in StoryRules.due_at(DataDB.all(), GameState.run, GameState.ctx(), map.map_id if not interior else return_zone, near):
		await Flow.play_inline_story(str(id))


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
	# M12: a CameraBounds marker narrows the limits (never below one screen).
	var cb: Rect2i = map.camera_rect
	if cb.size.x * TILE >= view.x and cb.size.y * TILE >= view.y:
		_camera.limit_left = cb.position.x * TILE
		_camera.limit_right = cb.end.x * TILE
		_camera.limit_top = cb.position.y * TILE - TILE
		_camera.limit_bottom = cb.end.y * TILE + TILE
	_camera.make_current()
	_apply_light()
	_spawn_followers()
	_refresh_people()
	_save_pos()
	var late := Calendar.part_id() in ["evening", "night"]
	if not interior:
		var zone_music := str(DataDB.table("town/zones/" + id).get("music", "town"))
		Audio.play_music_first(["weekend"] if Calendar.is_weekend() else (["town_night", zone_music] if late else ["town_" + Calendar.part_id(), zone_music]))
	# VD Part 1: ambience by place and time.
	Audio.play_ambience("school" if id == "school" else ("town_night" if late else "town_day"))


## M12b: cars driving along the zone's road rows (they never block walking).
func _spawn_cars(life: Dictionary) -> void:
	for c in _cars:
		if is_instance_valid(c):
			c.queue_free()
	_cars.clear()
	if interior:
		return
	var n := int(life.get("cars", {}).get(map.map_id, 0))
	var rows: Array = map.road_rows()
	if n <= 0 or rows.is_empty():
		return
	var car: Dictionary = DataDB.table("town/styles").get("props", {}).get("car", {})
	var tiles: Array = car.get("tiles", [0])
	var rng := Rng.stream("fx")
	for i in n:
		var sprite := Sprite2D.new()
		sprite.texture = map.tile_texture(str(car.get("pack", "city")), int(tiles[i % tiles.size()]))
		sprite.centered = false
		sprite.z_index = 3
		var y := float(int(rows[i % rows.size()]) * TILE)
		var left := i % 2 == 0
		var w := float(map.size.x * TILE)
		sprite.position = Vector2(rng.randf_range(0.0, w), y)
		sprite.flip_h = not left
		map.add_child(sprite)
		_cars.append(sprite)
		_drive(sprite, w, left, float(life.get("carSeconds", 9.0)))


func _drive(sprite: Sprite2D, w: float, left: bool, seconds: float) -> void:
	var tw := sprite.create_tween().set_loops()
	var start := -float(TILE) if left else w
	var end := w if left else -float(TILE)
	tw.tween_property(sprite, "position:x", end, seconds * absf(end - sprite.position.x) / maxf(1.0, w))
	tw.tween_callback(func() -> void: sprite.position.x = start)
	tw.tween_property(sprite, "position:x", end, seconds)


## M12b: the day part's light over the map, and leaves or fireflies outdoors.
func _apply_light() -> void:
	var tints: Dictionary = DataDB.table("display").get("dayTint", {})
	var life: Dictionary = DataDB.table("town/styles").get("life", {})
	map.night = not interior and life.get("nightParts", []).has(Calendar.part_id())
	map.find_lamps()
	map.sparkle = Vector2i(-1, -1)
	var fl := str(life.get("fountainLoc", ""))
	if not interior and map.spots.has(fl) and not GameState.flag("dance_interrupted"):
		map.sparkle = map.spots[fl] + Vector2i(0, -3)
	_spawn_cars(life)
	if _light == null:
		_light = CanvasModulate.new()
		add_child(_light)
	_light.color = Color(str(tints.get("interior" if interior else Calendar.part_id(), "#ffffff")))
	if _particles != null:
		_particles.queue_free()
		_particles = null
	if interior:
		return
	var late := Calendar.part_id() in ["evening", "night"]
	for key in ["leaves", "fireflies"]:
		var a: Dictionary = DataDB.table("display").get("ambient", {}).get(key, {})
		if a.is_empty() or not a.get("zones", []).has(map.map_id) or bool(a.get("day", true)) == late:
			continue
		var p := CPUParticles2D.new()
		p.amount = int(a.get("amount", 12))
		p.lifetime = 6.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(Display.base) / 2.0
		p.color = Color(str(a.get("color", "#ffffff")))
		p.scale_amount_min = Display.detail
		p.scale_amount_max = Display.detail * 1.5
		if key == "leaves":
			p.gravity = Vector2(6, 10)
			p.direction = Vector2(1, 0.4)
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 10.0
		else:
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 5.0
			p.spread = 180.0
		p.z_index = 20
		_camera.add_child(p)
		_particles = p
		break


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
	if map != null and _camera != null and _camera.is_inside_tree():
		_apply_light()
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
	Audio.event("door_open")
	Narrator.say(_enter_line(loc))


func _enter_line(loc: String) -> String:
	var r := Locs.rec(DataDB.all(), loc)
	var people := Sched.people_at(DataDB.all(), GameState.run, loc, Calendar.day_name(), Calendar.part_id(), int(GameState.run.get("day_count", 0)))
	var names: Array = []
	for p in people:
		names.append(str(DataDB.table("npcs/" + str(p)).get("name", p)))
	if names.is_empty():
		return Strings.t("town.nobody_you_know_is_here") % r.get("name", loc)
	return Strings.t("town.here") % [r.get("name", loc), ", ".join(PackedStringArray(names))]


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
	Audio.event("door_open")


# --- People ------------------------------------------------------------------------------

## Place everyone who is here now: at outdoor spots in zones, at the npc spots
## inside interiors. Residents at home light their windows.
func _refresh_people() -> void:
	for n in _npc_nodes:
		n.queue_free()
	_npc_nodes.clear()
	npcs.clear()
	crowd.clear()
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
				_place_npc(str(id), _spread_near(anchor))
		_spawn_crowd()
		_show_changes()
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


## M17: a free tile near a spot with nobody right next to it, so a crowd
## spreads out instead of clumping (falls back to any free tile).
func _spread_near(anchor: Vector2i) -> Vector2i:
	for r in range(0, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := anchor + Vector2i(dx, dy)
				if not map.walkable(c) or npcs.has(c) or crowd.has(c) or c == cell:
					continue
				var crowded := false
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						if npcs.has(c + Vector2i(ox, oy)) or crowd.has(c + Vector2i(ox, oy)):
							crowded = true
				if not crowded:
					return c
	return _free_near(anchor)


func _place_npc(id: String, at: Vector2i) -> void:
	var rec: Dictionary = DataDB.table("npcs/" + id)
	var w := Walker.new(str(rec.get("sprite", "")))
	w.position = _cell_pos(at)
	w.z_index = 4
	w.face(Vector2i.DOWN)
	map.add_child(w)
	_npc_nodes.append(w)
	npcs[at] = id
	w.set_meta("cell", at)
	w.set_meta("anchor", at)
	w.set_meta("kind", "named")
	var tag := UiTheme.world_label(str(rec.get("name", id)).split(" ")[0], UiTheme.LABEL)
	tag.position = Vector2((w.frame_size.x - tag.get_minimum_size().x) / 2.0, -w.frame_size.y - UiTheme.FONT_SIZE - 3)
	w.add_child(tag)


# --- Movement -------------------------------------------------------------------------------

## M17: generated students and townsfolk for this zone and part (seeded per day).
func _spawn_crowd() -> void:
	var db: Dictionary = DataDB.all()
	var rng := Sched.day_rng(GameState.run, "crowd:%s:%s" % [map.map_id, Calendar.part_id()], int(GameState.run.get("day_count", 0)))
	var keep := {}
	for d in map.doors:
		keep[map.doors[d]["approach"]] = true
	for s in map.spots:
		keep[map.spots[s]] = true
	for person in Crowd.generate(db, GameState.run, map.map_id, Calendar.part_id(), Calendar.week(), rng):
		for tries in 30:
			var c := Vector2i(rng.randi_range(1, map.size.x - 2), rng.randi_range(1, map.size.y - 2))
			if map.walkable(c) and not npcs.has(c) and not crowd.has(c) and not keep.has(c) and c != cell:
				_place_crowd(person, c)
				break


func _place_crowd(person: Dictionary, at: Vector2i) -> void:
	var w := Walker.new(str(person.get("sprite", "")))
	w.position = _cell_pos(at)
	w.z_index = 4
	w.modulate = Color(str(person.get("tint", "#ffffff")))
	w.face(Vector2i.DOWN)
	map.add_child(w)
	_npc_nodes.append(w)
	crowd[at] = person
	w.set_meta("cell", at)
	w.set_meta("anchor", at)
	w.set_meta("kind", str(person.get("kind", "adult")))
	var tag := UiTheme.world_label(str(person.get("name", "")).split(" ")[0], UiTheme.DIM)
	tag.position = Vector2((w.frame_size.x - tag.get_minimum_size().x) / 2.0, -w.frame_size.y - UiTheme.FONT_SIZE - 3)
	w.add_child(tag)


## Someone takes a step near where they belong (named people and the crowd).
func _wander_one() -> void:
	if map == null or _npc_nodes.is_empty() or _moving:
		return
	var rng := Rng.stream("npc")
	var w: Node2D = _npc_nodes[rng.randi_range(0, _npc_nodes.size() - 1)]
	if not is_instance_valid(w) or not w.has_meta("cell"):
		return
	var at: Vector2i = w.get_meta("cell")
	var anchor: Vector2i = w.get_meta("anchor")
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var d: Vector2i = dirs[rng.randi_range(0, 3)]
	var to := at + d
	var r := int(DataDB.table("town/crowd").get("wanderRadius", 2))
	if not map.walkable(to) or npcs.has(to) or crowd.has(to) or to == cell or absi(to.x - anchor.x) > r or absi(to.y - anchor.y) > r or map.doors.has(to - Vector2i(0, 1)):
		return
	if npcs.has(at):
		npcs[to] = npcs[at]
		npcs.erase(at)
	elif crowd.has(at):
		crowd[to] = crowd[at]
		crowd.erase(at)
	else:
		return
	w.set_meta("cell", to)
	w.face(d)
	var tw := create_tween()
	tw.tween_property(w, "position", _cell_pos(to), 0.3)
	w.play_walk(0.3)


## After the player steps: followers move up the trail, people nearby bark,
## and party members sometimes banter.
func _after_step() -> void:
	_trail.push_front(cell)
	_trail.resize(mini(_trail.size(), 8))
	for i in _followers.size():
		var f: Node2D = _followers[i]
		var idx := mini(i + 1, _trail.size() - 1)
		var tw := create_tween()
		tw.tween_property(f, "position", _cell_pos(_trail[idx]), STEP_TIME)
		f.play_walk(STEP_TIME)
	var now := Time.get_ticks_msec() / 1000.0
	var cfg: Dictionary = DataDB.table("town/crowd")
	for w in _npc_nodes:
		if not is_instance_valid(w) or not w.has_meta("cell"):
			continue
		var c: Vector2i = w.get_meta("cell")
		if (c - cell).length() <= 1.0 and now >= float(_bark_until.get(w.get_instance_id(), 0.0)):
			_bark_until[w.get_instance_id()] = now + float(cfg.get("barkCooldown", 4.0))
			_bubble(w, Crowd.bark(DataDB.all(), str(w.get_meta("kind")), Rng.stream("npc")))
			break
	_steps += 1
	if _steps % int(DataDB.table("town/party_banter").get("banterSteps", 40)) == 0 and _followers.size() >= 2:
		var line := Crowd.pair_line(DataDB.all(), GameState.run, GameState.party_ids, Rng.stream("npc"))
		if line != "":
			Narrator.say(line)


## A short speech bubble above someone.
func _bubble(w: Node2D, text: String) -> void:
	if text == "":
		return
	var l := UiTheme.world_label(text, UiTheme.TEXT)
	l.position = w.position + Vector2(-l.get_minimum_size().x / 2.0 + TILE / 2.0, -TILE * 2.0)
	l.z_index = 30
	map.add_child(l)
	var tw := create_tween()
	tw.tween_interval(float(DataDB.table("town/crowd").get("barkSeconds", 2.0)))
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## M17: party members follow you outdoors and comment on where you arrive.
func _spawn_followers() -> void:
	for f in _followers:
		if is_instance_valid(f):
			f.queue_free()
	_followers.clear()
	_trail.clear()
	if interior:
		return
	var first := true
	for id in GameState.party_ids:
		var rec: Dictionary = DataDB.table("npcs/" + str(id))
		if rec.is_empty():
			continue
		var w := Walker.new(str(rec.get("sprite", "")))
		w.position = _cell_pos(cell)
		w.z_index = 4
		map.add_child(w)
		_followers.append(w)
		if first:
			first = false
			var line := Crowd.zone_comment(DataDB.all(), str(id), map.map_id)
			if line != "":
				_bubble(w, line)


## M21: a leak point: a small Upside-Down fight in daylight; winning seals it.
func _leak_fight(c: Vector2i) -> void:
	for ch in Crowd.changes(DataDB.all(), GameState.run, GameState.ctx(), map.map_id):
		if str(ch.get("kind", "")) != "leak" or not ch.has("fight"):
			continue
		var base: Variant = map.door_by_loc.get(str(ch.get("loc", "")), map.spots.get(str(ch.get("loc", "")), null))
		var off: Array = ch.get("offset", [0, 0])
		if base == null or (base as Vector2i) + Vector2i(int(off[0]), int(off[1])) != c:
			continue
		Narrator.say(str(ch.get("text", "")))
		var setup := GameState.combat_setup(ch["fight"].get("enemies", []), "open_field", { "winFlag": str(ch["fight"].get("closeFlag", "")) })
		_save_pos()
		GameState.start_combat(setup, "res://src/scenes/town/town.tscn")
		return


## M17: the town's visible changes (posters, flyers, the forge, the crater).
func _show_changes() -> void:
	map.marks = {}
	for ch in Crowd.changes(DataDB.all(), GameState.run, GameState.ctx(), map.map_id):
		var loc := str(ch.get("loc", ""))
		var base: Variant = map.door_by_loc.get(loc, map.spots.get(loc, null))
		if base == null:
			continue
		var off: Array = ch.get("offset", [0, 0])
		var c: Vector2i = (base as Vector2i) + Vector2i(int(off[0]), int(off[1]))
		map.marks[c] = str(ch.get("kind", "poster"))
		map.signs[c] = str(ch.get("text", ""))
	map.refresh_overlay()


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
	if map != null:
		# Lamps flicker, the fountain sparkles, water ripples (M12b).
		map.refresh_overlay()
	_wander_t += _delta
	if _wander_t >= float(DataDB.table("town/crowd").get("wanderSeconds", 1.6)) and not Flow.is_busy():
		_wander_t = 0.0
		_wander_one()
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
	if not map.walkable(next) or npcs.has(next) or crowd.has(next):
		return
	_moving = true
	cell = next
	Audio.event("step_floor" if interior else "step_grass")
	var tw := create_tween()
	tw.tween_property(player, "position", _cell_pos(cell), STEP_TIME)
	player.play_walk(STEP_TIME)
	await tw.finished
	_moving = false
	if not Input.is_anything_pressed():
		player.stop()
	_after_step()
	_check_place_stories()


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
	if crowd.has(f):
		text = Strings.t("town.e_talk_to_crowd") % str(crowd[f].get("name", "")).split(" ")[0]
	elif npcs.has(f):
		text = Strings.t("town.e_talk_to") % DataDB.table("npcs/" + str(npcs[f])).get("name", "")
	elif map.doors.has(f):
		text = "[E] %s" % Locs.rec(DataDB.all(), str(map.doors[f]["loc"])).get("name", "Door")
	elif map.room_doors.has(f):
		text = "[E] %s" % Locs.rec(DataDB.all(), str(map.room_doors[f])).get("name", "Door")
	elif map.furniture.has(f) and map.furniture[f].has("label"):
		text = "[E] %s" % map.furniture[f]["label"]
	elif map.marks.get(f, "") == "leak":
		text = Strings.t("town.e_seal_leak")
	elif map.signs.has(f):
		text = Strings.t("town.e_read_sign")
	else:
		var loc := _spot_here()
		if loc != "":
			text = "[E] %s" % Locs.rec(DataDB.all(), loc).get("name", loc)
		elif interior:
			text = Strings.t("town.e_look_around") % Locs.rec(DataDB.all(), interior_loc).get("name", "")
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
	if crowd.has(f):
		await _talk_crowd(crowd[f])
		return
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
	if map.marks.get(f, "") == "leak":
		await _leak_fight(f)
		return
	if map.signs.has(f):
		Narrator.say(Strings.t("town.the_sign_says") % map.signs[f])
		return
	if map.furniture.has(f):
		var kind := str(map.furniture[f].get("kind", ""))
		if kind == "workbench":
			await _workbench(interior_loc)
			return
		if kind == "lockers" and interior_loc == "hallways":
			await _locker()
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
		Narrator.say(Strings.t("town.nothing_to_do_here_walking"))


func _use_door(loc: String, approach: Vector2i) -> void:
	var db: Dictionary = DataDB.all()
	var d := Locs.door(db, GameState.run, loc, Calendar.week(), Calendar.day_name(), Calendar.part_id(), int(GameState.run.get("day_count", 0)))
	if str(d["kind"]) in ["enter", "walkup"]:
		# M20: the week's mirror rooms lean toward places you went.
		var visited: Dictionary = GameState.run.get("visited", {})
		var wk: Array = visited.get(str(Calendar.week()), [])
		if not wk.has(loc):
			wk.append(loc)
		visited[str(Calendar.week())] = wk
		GameState.run["visited"] = visited
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
			Narrator.say(Strings.t("town.comes_to_the_door") % Strings.t("town.and").join(PackedStringArray(names)))
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
	m.text(Strings.t("town.ap_left") % [Calendar.ap(), GameState.money], UiTheme.DIM)
	var acts := Locs.activities(db, GameState.run, loc, Calendar.part_id(), GameState.ctx())
	for a in acts:
		var act: Dictionary = a
		var cost := int(act.get("ap", 1))
		var price := int(act.get("money", 0))
		var label := Strings.t("town.ap") % [act.get("label", "?"), cost, ", $%d" % price if price > 0 else ""]
		m.add_button(label, func() -> void: m.finish({ "act": act }), Calendar.ap() < cost or price > GameState.money)
	if r.has("shop"):
		var visit := int(DataDB.table("town/shops").get("rules", {}).get("visitAp", 1))
		m.add_button(Strings.t("town.shop_ap_per_visit") % visit, func() -> void: m.finish({ "shop": str(r["shop"]) }), Calendar.ap() < visit)
	if r.has("workbench"):
		m.add_button(Strings.t("town.workbench_craft_ap") % int(r["workbench"]), func() -> void: m.finish({ "workbench": true }))
	if bool(r.get("busStop", false)):
		for z in ["school", "downtown", "residential", "outskirts"]:
			if z != map_id:
				var zone := str(z)
				m.add_button(Strings.t("town.take_the_bus_to_free") % DataDB.table("town/zones/" + z).get("name", z), func() -> void: m.finish({ "bus": zone }))
	m.add_button(Strings.t("town.leave"), func() -> void: m.finish(null))
	var picked: Variant = await Flow.show_modal(m)
	if picked == null:
		return
	var p: Dictionary = picked
	if p.has("act") and bool(p["act"].get("rift", false)):
		# The Rift: the rest of After School goes into the Endless Arena (docs/ARENA.md).
		Narrator.say(str(p["act"].get("say", "")))
		Calendar.set_ap(0)
		GameState.run.erase("arena")
		GameState.run["rift"] = preload("res://src/core/arena/arena.gd").new_arena(hash("%d:%d:%s" % [int(GameState.run.get("seed", 0)), Calendar.week(), Calendar.day_name()]), true)
		_save_pos()
		SceneRouter.goto("res://src/scenes/arena/arena.tscn")
		return
	if p.has("act"):
		var act: Dictionary = p["act"]
		if not Calendar.spend_ap(int(act.get("ap", 1)), "activity:" + loc):
			return
		if int(act.get("money", 0)) > 0:
			GameState.spend_money(int(act["money"]))
		var lines := GameState.apply_effects(act.get("effects", {}))
		Narrator.say(("%s %s" % [str(act.get("say", "")), " ".join(PackedStringArray(lines))]).strip_edges())
		# M19: part-time jobs sometimes have a small event on the shift.
		var jobs: Dictionary = DataDB.table("jobs")
		var evs: Array = jobs.get("events", {}).get(str(act.get("job", "")), [])
		var rng := Rng.stream("events")
		if not evs.is_empty() and rng.randf() < float(jobs.get("eventChance", 0.6)):
			await Flow.show_event(evs[rng.randi_range(0, evs.size() - 1)])
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
		Narrator.say(Strings.t("town.the_bus_is_empty_except"))
	_refresh_people()


func _workbench(loc: String) -> void:
	var wb := Workbench.new()
	wb.craft_ap = int(Locs.rec(DataDB.all(), loc).get("workbench", 2))
	wb.place = str(Locs.rec(DataDB.all(), loc).get("name", loc))
	await Flow.show_modal(wb)

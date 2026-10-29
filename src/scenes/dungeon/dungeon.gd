## The night's Upside-Down floor, explored top-down (DESIGN.md Section 10).
## Rooms sit on a grid joined by corridors. Walking into an uncleared fight
## room starts a grid fight (and comes back here); E uses chests, fires,
## merchants, event figures and the exit. Leaving at the exit ends the night.
## State: run["floor"], run["floor_pos"] (cell), run["floor_fight"] (room id).
extends Node2D

const Night := preload("res://src/core/dungeon/night.gd")
const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const UpsideDownLook := preload("res://src/scenes/common/upside_down_look.gd")
const Sig := preload("res://src/core/dungeon/signature.gd")
const Walker := preload("res://src/scenes/common/walker_sprite.gd")
const Modal := preload("res://src/scenes/ui/modal.gd")
const ShopScreen := preload("res://src/scenes/town/shop_screen.gd")
const Char := preload("res://src/core/character.gd")
const SELF := "res://src/scenes/dungeon/dungeon.tscn"
const TOWN := "res://src/scenes/town/town.tscn"

var floor_data: Dictionary = {}
var room_rects: Dictionary = {}    # room id -> Rect2i (interior incl. walls)
var walkable: Dictionary = {}      # cell -> room id (or -1 corridor)
var features: Dictionary = {}      # cell -> room id (the room's feature tile)
var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var player: Walker
var _layer: TileMapLayer
var _overlay: Node2D
var _camera: Camera2D
var _moving := false
var _hud: Label
var _strip: VBoxContainer
var _prompt: Label
var _sprites: Dictionary = {}      # room id -> Node2D
var _week := 1
var _day := "mon"
var _cols := 1

var TILE: int:
	get: return Display.tile


func _ready() -> void:
	Flow.set_hud(false)
	_week = Calendar.week()
	_day = Calendar.day_name()
	var db: Dictionary = DataDB.all()
	floor_data = GameState.run.get("floor", {})
	if floor_data.is_empty() or int(floor_data.get("week", 0)) != _week or str(floor_data.get("day", "")) != _day:
		floor_data = Night.start(db, GameState.run, _week, _day)
		GameState.run["night_xp"] = 0
		GameState.run.erase("floor_pos")
	GameState.run["resume_scene"] = SELF
	_build()
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(Display.base.x, 0)
	ui.add_child(bar)
	_hud = UiTheme.label("")
	bar.add_child(_hud)
	_strip = preload("res://src/scenes/ui/effects_strip.gd").new()
	_strip.position = Vector2(2, 40)
	add_child(_strip)
	_prompt = UiTheme.world_label("", UiTheme.ACCENT)
	_prompt.position = Vector2(4, Display.base.y - 18)
	ui.add_child(_prompt)
	UpsideDownLook.add_to(self, Calendar.week())
	Audio.play_music_first(["dungeon_boss_floor"] if bool(floor_data.get("boss", false)) else ["upside_down_week%d" % Calendar.week(), "dungeon"])
	Audio.play_ambience("upside_down_week%d" % Calendar.week())
	if GameState.run.has("floor_fight"):
		await _after_fight(int(GameState.run["floor_fight"]))
	elif not GameState.run.has("floor_pos"):
		var intro := str(Sig.week_rec(db, _week).get("bossIntro" if bool(floor_data.get("boss", false)) else "intro", ""))
		Narrator.say(intro if bool(floor_data.get("boss", false)) else Strings.t("dungeon.the_upside_down_rebuilds_itself") % Sig.dominant(db, GameState.run, _week))
	_refresh()


# --- Building ---------------------------------------------------------------------

func _origin(room: Dictionary) -> Vector2i:
	var minx := 0
	var miny := 0
	for r in floor_data["rooms"]:
		minx = mini(minx, int(r["cell"][0]))
		miny = mini(miny, int(r["cell"][1]))
	var sp := int(DataDB.table("dungeon").get("roomSpacing", 13))
	return Vector2i((int(room["cell"][0]) - minx) * sp + 1, (int(room["cell"][1]) - miny) * sp + 1)


func _build() -> void:
	var db: Dictionary = DataDB.all()
	var dcfg: Dictionary = db.get("dungeon", {})
	var tiles: Dictionary = dcfg.get("tiles", {})
	var sz: Array = dcfg.get("roomSize", [11, 9])
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = Assets.texture(str(dcfg.get("tileset", "")))
	src.texture_region_size = Vector2i(TILE, TILE)
	_cols = maxi(1, src.texture.get_width() / TILE)
	for r in src.texture.get_height() / TILE:
		for c in _cols:
			src.create_tile(Vector2i(c, r))
	ts.add_source(src, 0)
	var void_bg := ColorRect.new()
	void_bg.color = Color("0b0812")
	void_bg.position = -Vector2.ONE * TILE * 100
	void_bg.size = Vector2.ONE * TILE * 300
	void_bg.z_index = -10
	add_child(void_bg)
	_layer = TileMapLayer.new()
	_layer.tile_set = ts
	add_child(_layer)
	var floors: Array = tiles.get("floor", [48])
	for room in floor_data["rooms"]:
		var o := _origin(room)
		var rect := Rect2i(o, Vector2i(int(sz[0]), int(sz[1])))
		room_rects[int(room["id"])] = rect
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector2i(x, y)
				var wall := x == rect.position.x or y == rect.position.y or x == rect.end.x - 1 or y == rect.end.y - 1
				if wall:
					_put(c, int(tiles.get("wall", 40)))
				else:
					_put(c, int(floors[absi(x * 3 + y * 7) % floors.size()]))
					walkable[c] = int(room["id"])
		var center := rect.position + rect.size / 2
		features[center] = int(room["id"])
	for room in floor_data["rooms"]:
		for n in Gen.neighbors(floor_data, room):
			if int(n["id"]) < int(room["id"]):
				continue
			_corridor(room_rects[int(room["id"])], room_rects[int(n["id"])], floors)
	player = Walker.new(str(GameState.player.get("sprite", Assets.role("player"))))
	player.z_index = 5
	add_child(player)
	var start_rect: Rect2i = room_rects[0]
	cell = start_rect.position + start_rect.size / 2 + Vector2i(0, 2)
	if GameState.run.has("floor_pos"):
		var fp: Array = GameState.run["floor_pos"]
		cell = Vector2i(int(fp[0]), int(fp[1]))
	player.position = _pos(cell)
	_camera = Camera2D.new()
	_camera.position = Vector2(TILE / 2.0, -TILE / 2.0)
	player.add_child(_camera)
	_camera.make_current()
	_overlay = Node2D.new()
	_overlay.z_index = 3
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	modulate = Color(str(DataDB.record("rooms/themes", str(floor_data.get("theme", "school"))).get("accent", "#ffffff"))).lerp(Color.WHITE, 0.55)
	_place_contents()


func _put(c: Vector2i, index: int) -> void:
	_layer.set_cell(c, 0, Vector2i(index % _cols, index / _cols))


func _corridor(a: Rect2i, b: Rect2i, floors: Array) -> void:
	var ac := a.position + a.size / 2
	var bc := b.position + b.size / 2
	var c := ac
	var step := Vector2i(signi(bc.x - ac.x), signi(bc.y - ac.y))
	while c != bc:
		c += step
		if not walkable.has(c):
			walkable[c] = -1
		_put(c, int(floors[0]))


func _pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE, (c.y + 1) * TILE)


## Sprites for what each room holds.
func _place_contents() -> void:
	var db: Dictionary = DataDB.all()
	var enemies := {}
	for e in DataDB.records_under("enemies/", "enemies"):
		enemies[str(e["id"])] = e
	for room in floor_data["rooms"]:
		var id := int(room["id"])
		var rect: Rect2i = room_rects[id]
		var center := rect.position + rect.size / 2
		var node: Node2D = null
		var t := str(room["type"])
		if t in ["combat", "elite", "boss"] and not bool(room.get("cleared", false)) and not room.get("enemies", []).is_empty():
			var rec: Dictionary = enemies.get(str(room["enemies"][0]), {})
			var sprite_id := str(rec.get("sprite", ""))
			if str(Assets.spec(sprite_id).get("kind", "")) == "strip":
				var frame := Assets.frame(sprite_id)
				var s := Sprite2D.new()
				s.texture = Assets.texture(sprite_id)
				s.region_enabled = true
				s.region_rect = Rect2(Vector2.ZERO, frame)
				s.centered = false
				s.offset = Vector2(-frame.x / 2.0 + TILE / 2.0, -frame.y)
				node = s
			else:
				var w := Walker.new(sprite_id)
				w.face(Vector2i.DOWN)
				node = w
		elif t == "event" and not bool(room.get("cleared", false)):
			node = Walker.new(Assets.role("dungeonEvent"))
		elif t == "merchant":
			node = Walker.new(Assets.role("dungeonMerchant"))
		if node != null:
			node.position = _pos(center)
			node.z_index = 4
			add_child(node)
			_sprites[id] = node
		var tiles: Dictionary = db.get("dungeon", {}).get("tiles", {})
		match t:
			"treasure":
				_put(center, int(tiles.get("chestOpen", 91)) if bool(room.get("cleared", false)) else int(tiles.get("chest", 89)))
			"rest":
				_put(center, int(tiles.get("fire", 29)))
			"exit":
				_put(center, int(tiles.get("stairs", 36)))


# --- Movement ----------------------------------------------------------------------

func _process(_delta: float) -> void:
	_update_prompt()
	if _moving or Flow.is_busy():
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


func step(dir: Vector2i) -> void:
	facing = dir
	player.face(dir)
	var next := cell + dir
	if not walkable.has(next) or features.has(next):
		return
	_moving = true
	cell = next
	GameState.run["floor_pos"] = [cell.x, cell.y]
	var tw := create_tween()
	tw.tween_property(player, "position", _pos(cell), 0.1)
	player.play_walk(0.1)
	await tw.finished
	_moving = false
	if not Input.is_anything_pressed():
		player.stop()
	_on_enter(cell)


func _room_at(c: Vector2i) -> Dictionary:
	var id := int(walkable.get(c, -1))
	return Gen.room_by_id(floor_data, id) if id >= 0 else {}


func _on_enter(c: Vector2i) -> void:
	var room := _room_at(c)
	if room.is_empty():
		return
	if not bool(room.get("visited", false)):
		room["visited"] = true
		_overlay.queue_redraw()
	var t := str(room["type"])
	if room.has("mirror") and not bool(room.get("cleared", false)):
		for mr in DataDB.table("rooms/mirror_rooms").get("rooms", []):
			if str(mr["id"]) == str(room["mirror"]):
				Narrator.say("%s. %s" % [str(mr.get("name", "")), str(mr.get("text", ""))])
	if t in ["combat", "elite", "boss"] and not bool(room.get("cleared", false)):
		_start_fight(room)


func _unhandled_input(event: InputEvent) -> void:
	if Flow.is_busy():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact()


func _front_feature() -> Dictionary:
	var f := cell + facing
	if features.has(f):
		return Gen.room_by_id(floor_data, int(features[f]))
	return {}


func _update_prompt() -> void:
	var room := _front_feature()
	var labels := { "treasure": Strings.t("dungeon.open_the_chest"), "rest": Strings.t("dungeon.rest_by_the_fire"), "merchant": Strings.t("dungeon.browse_the_merchant"), "event": Strings.t("dungeon.approach_the_figure"), "exit": Strings.t("dungeon.leave_the_upside_down"), "start": "" }
	var t := str(room.get("type", ""))
	if t == "exit" and Night.exit_blockers(DataDB.all(), floor_data) > 0:
		_prompt.text = "[E] %s" % (Strings.t("dungeon.exit_sealed_prompt") % Night.exit_blockers(DataDB.all(), floor_data))
		return
	_prompt.text = ("[E] %s" % labels[t]) if labels.has(t) and str(labels[t]) != "" and not (t in ["treasure", "event", "rest"] and bool(room.get("cleared", false))) else ""


func interact() -> void:
	var room := _front_feature()
	if room.is_empty():
		return
	var db: Dictionary = DataDB.all()
	var rng := Rng.stream("dungeon")
	match str(room["type"]):
		"treasure":
			if not bool(room.get("cleared", false)):
				var lines := Night.open_treasure(db, GameState.run, room, _week, rng)
				_put(room_rects[int(room["id"])].position + room_rects[int(room["id"])].size / 2, int(db["dungeon"]["tiles"].get("chestOpen", 91)))
				Audio.play_sfx("coin")
				await Flow.show_event({ "title": "Treasure", "text": "\n".join(PackedStringArray(lines)) })
		"rest":
			if not bool(room.get("cleared", false)):
				var lines := Night.rest(db, GameState.run, room)
				Audio.play_sfx("heal")
				await Flow.show_event({ "title": Strings.t("dungeon.a_strange_fire"), "text": "\n".join(PackedStringArray(lines)) })
		"merchant":
			var s := ShopScreen.new()
			s.shop_id = str(db.get("dungeon", {}).get("merchant", {}).get("shop", "upside_merchant"))
			await Flow.show_modal(s)
		"event":
			if not bool(room.get("cleared", false)):
				var ev: Dictionary = DataDB.record("events/dungeon_events", str(room.get("event", "")))
				if not ev.is_empty():
					await Flow.show_event(ev)
				room["cleared"] = true
				if _sprites.has(int(room["id"])):
					_sprites[int(room["id"])].queue_free()
					_sprites.erase(int(room["id"]))
		"exit":
			await _exit_prompt()
	_refresh()


func _exit_prompt() -> void:
	var m := Modal.new()
	m.build(Strings.t("dungeon.the_way_out"), 320)
	var sealed := Night.exit_blockers(DataDB.all(), floor_data)
	if sealed > 0:
		m.text(Strings.t("dungeon.exit_sealed") % sealed, UiTheme.BAD)
		m.add_button(Strings.t("dungeon.not_yet"), func() -> void: m.finish(false))
		await Flow.show_modal(m)
		return
	var left := 0
	for r in floor_data["rooms"]:
		if str(r["type"]) in ["combat", "elite", "treasure", "event"] and not bool(r.get("cleared", false)):
			left += 1
	m.text(Strings.t("dungeon.a_staircase_up_into_the") % (Strings.t("dungeon.rooms_left_unexplored_leaving_now") % left if left > 0 else Strings.t("dungeon.nothing_left_down_here_worth")), UiTheme.DIM)
	m.add_button(Strings.t("dungeon.leave_the_upside_down"), func() -> void: m.finish(true))
	m.add_button(Strings.t("dungeon.not_yet"), func() -> void: m.finish(false))
	var r: Variant = await Flow.show_modal(m)
	if bool(r):
		_end_night()


func _end_night() -> void:
	var db: Dictionary = DataDB.all()
	# New cards on the way out (user request, Oct 29).
	await Flow.card_reward("boss" if bool(floor_data.get("boss", false)) else "floor")
	Night.catch_up(db, GameState.run, int(GameState.run.get("night_xp", 0)), Rng.stream("leveling"))
	Night.end_night(GameState.run)
	GameState.run.erase("floor_pos")
	GameState.run.erase("resume_scene")
	if GameState.flag("week%d_cleared" % int(DataDB.table("calendar").get("totalWeeks", 5))) and not GameState.flag("act1_finale_won"):
		# M21: the finale is won; the aftermath weekend comes next, then End of Act 1.
		GameState.set_flag("act1_finale_won")
		Journal.note_ending("act1")
	Narrator.say(Strings.t("dungeon.you_climb_out_into_the"))
	GameState.advance_part()
	SceneRouter.goto(TOWN)


# --- Fights ----------------------------------------------------------------------

func _start_fight(room: Dictionary) -> void:
	var db: Dictionary = DataDB.all()
	var fs := Night.fight_setup(db, room, Night.party_size(GameState.run))
	var enemies: Array = fs["enemies"]
	var t := str(room["type"])
	var intro := ""
	if bool(room.get("returning", false)):
		intro = Strings.t("dungeon.unfinished_business") % (Strings.t("dungeon.you_ran_from_these_they") if bool(room.get("fled", false)) else Strings.t("dungeon.they_re_back_and_bigger"))
	elif t == "elite":
		intro = Strings.t("dungeon.something_bigger_than_the_rest")
	elif t == "boss":
		intro = str(Sig.week_rec(db, _week).get("bossIntro", ""))
	GameState.run["floor_fight"] = int(room["id"])
	var setup := GameState.combat_setup(enemies, str(room.get("layout", "open_field")), { "boss": t == "boss", "intro": intro,
		"formation": fs["formation"], "roles": fs["roles"], "reinforcements": fs["reinforcements"] })
	GameState.start_combat(setup, SELF)


func _after_fight(room_id: int) -> void:
	GameState.run.erase("floor_fight")
	var db: Dictionary = DataDB.all()
	var room := Gen.room_by_id(floor_data, room_id)
	var summary: Dictionary = GameState.last_combat
	GameState.run["night_xp"] = int(GameState.run.get("night_xp", 0)) + int(summary.get("xp", 0))
	var lines := Night.after_combat(db, GameState.run, room, summary, _week, _day, Rng.stream("dungeon"))
	if str(room.get("type", "")) == "boss" and str(summary.get("result", "")) == "win":
		lines.append_array(Night.boss_reward(db, GameState.run, _week, Rng.stream("dungeon")))
		Audio.play_sfx("win")
		await Flow.show_event({ "title": Strings.t("dungeon.week_cleared") % _week, "text": "\n".join(PackedStringArray(lines)) })
		# VD Part 5: the demo ends after the week 1 boss (thanks, then the survey).
		if Feedback.demo_active() and preload("res://src/core/demo.gd").ends_after(db, _week):
			await Feedback.end_demo()
			return
	elif not lines.is_empty():
		Narrator.say(" ".join(PackedStringArray(lines)))
	if _sprites.has(room_id) and bool(room.get("cleared", false)):
		_sprites[room_id].queue_free()
		_sprites.erase(room_id)
	if str(summary.get("result", "")) == "flee":
		var start_rect: Rect2i = room_rects[0]
		cell = start_rect.position + start_rect.size / 2 + Vector2i(0, 2)
		player.position = _pos(cell)
		GameState.run["floor_pos"] = [cell.x, cell.y]


# --- Display -------------------------------------------------------------------------

func _refresh() -> void:
	if _strip != null:
		_strip.refresh()
	var p: Dictionary = GameState.player
	var d := Char.derived(DataDB.all(), p)
	var party: Array = []
	for ch in Night.party_chars(GameState.run):
		if not ch.get("isPlayer", false):
			party.append("%s %d" % [str(ch.get("name", "")).split(" ")[0], int(ch.get("hp", 0))])
	var cleared := 0
	for r in floor_data["rooms"]:
		if bool(r.get("cleared", false)):
			cleared += 1
	_hud.text = Strings.t("dungeon.upside_down_week_hp_mp") % [_week, _day.capitalize(), Strings.t("dungeon.boss_floor") if bool(floor_data.get("boss", false)) else "",
		int(p.get("hp", 0)), int(d["maxHp"]), int(p.get("mp", 0)), int(d["maxMp"]), ", ".join(PackedStringArray(party)), cleared, floor_data["rooms"].size()] \
		+ (Strings.t("dungeon.fights_left") % Night.fights_left(floor_data) if Night.fights_left(floor_data) > 0 else "")
	_overlay.queue_redraw()


## Fog over rooms you haven't walked into yet, and type marks on visited ones.
func _draw_overlay() -> void:
	for room in floor_data["rooms"]:
		var rect: Rect2i = room_rects[int(room["id"])]
		var px := Rect2(rect.position * TILE, rect.size * TILE)
		if not bool(room.get("visited", false)) and int(room["id"]) != 0:
			_overlay.draw_rect(px, Color(0.03, 0.02, 0.06, 0.82))
		elif str(room["type"]) in ["combat", "elite", "boss"] and bool(room.get("cleared", false)):
			_overlay.draw_string(UiTheme.font, px.position + Vector2(4, 4) + Vector2(0, UiTheme.FONT_SIZE), "cleared" if not bool(room.get("fled", false)) else "fled", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color(1, 1, 1, 0.4))


# --- Test and simulation helpers ------------------------------------------------------

## Walk into a room (teleport) as if you'd entered it. Used by tests.
func visit_room(id: int) -> void:
	var rect: Rect2i = room_rects[id]
	cell = rect.position + rect.size / 2 + Vector2i(0, 2)
	player.position = _pos(cell)
	GameState.run["floor_pos"] = [cell.x, cell.y]
	_on_enter(cell)


## Stand in front of a room's feature and press E. Used by tests.
func use_feature(id: int) -> void:
	var rect: Rect2i = room_rects[id]
	cell = rect.position + rect.size / 2 + Vector2i(0, 1)
	facing = Vector2i.UP
	player.position = _pos(cell)
	await interact()


## The next room worth visiting: uncleared rooms in order, then the exit.
func next_room() -> Dictionary:
	for r in floor_data["rooms"]:
		if not bool(r.get("cleared", false)) and str(r["type"]) != "merchant":
			return r
	for r in floor_data["rooms"]:
		if str(r["type"]) == "exit":
			return r
	return {}

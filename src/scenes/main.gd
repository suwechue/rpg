## M4 hub: a placeholder town on a 16px grid (replaced by the real town in M5).
## Walk with WASD/arrows (free), E at a place to see its activities (AP),
## Space to end the day part. Flow shows classes, night and other screens.
extends Node2D

const Walker := preload("res://src/scenes/common/walker_sprite.gd")
const Modal := preload("res://src/scenes/ui/modal.gd")
const Workbench := preload("res://src/scenes/ui/workbench_screen.gd")
const TILE := 16
const COLS := 30
const ROWS := 16
const TOP_ROWS := 2

var player_tile := Vector2i(3, 12)
var _pois: Array = []
var _player_sprite: Walker


func _ready() -> void:
	if not GameState.has_run():
		GameState.new_run()
	_pois = DataDB.table("locations").get("locations", [])
	_player_sprite = Walker.new(str(GameState.player.get("sprite", "res://assets/packs/ninja_adventure/Actor/Character/Boy/SpriteSheet.png")))
	_player_sprite.z_index = 1
	add_child(_player_sprite)
	_place_player()
	EventBus.day_part_changed.connect(func(_w: int, _d: String, _p: String) -> void: queue_redraw())
	Flow.set_hud(true)
	Flow.begin()
	Audio.play_music("town")


func _unhandled_input(event: InputEvent) -> void:
	if Flow.is_busy():
		return
	var dir := Vector2i.ZERO
	if event.is_action_pressed("move_up", true):
		dir = Vector2i.UP
	elif event.is_action_pressed("move_down", true):
		dir = Vector2i.DOWN
	elif event.is_action_pressed("move_left", true):
		dir = Vector2i.LEFT
	elif event.is_action_pressed("move_right", true):
		dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		player_tile = Vector2i(clampi(player_tile.x + dir.x, 0, COLS - 1), clampi(player_tile.y + dir.y, TOP_ROWS, ROWS - 2))
		_player_sprite.face(dir)
		_player_sprite.play_walk(0.12)
		_place_player()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_interact()
		get_viewport().set_input_as_handled()


func _interact() -> void:
	var poi := _poi_at(player_tile)
	if poi.is_empty():
		Narrator.say("Nothing to do here. Walk onto one of the marked places.")
		return
	var part := Calendar.part_id()
	if not Array(poi.get("openParts", [])).has(part):
		Narrator.say("%s is closed right now." % poi.get("name", "That place"))
		return
	var m := Modal.new()
	m.build(str(poi.get("name", "")), 340)
	m.text("AP left: %d   $%d" % [Calendar.ap(), GameState.money], UiTheme.DIM)
	for a in poi.get("activities", []):
		var option: Dictionary = a
		var parts: Array = option.get("parts", [])
		if not parts.is_empty() and not parts.has(part):
			continue
		var cost := int(option.get("ap", 1))
		var price := int(option.get("money", 0))
		var label := "%s (%d AP)" % [option.get("label", "?"), cost] if not option.get("workbench", false) else str(option.get("label", "Workbench"))
		m.add_button(label, func() -> void:
			m.finish(option), Calendar.ap() < maxi(cost, 1 if option.get("workbench", false) else cost) or price > GameState.money)
	m.add_button("Leave", func() -> void: m.finish(null))
	var picked: Variant = await Flow.show_modal(m)
	if picked == null:
		return
	var act: Dictionary = picked
	if act.get("workbench", false):
		var wb := Workbench.new()
		wb.craft_ap = int(DataDB.table("minigames").get("craftAp", {}).get("elsewhere", 2))
		wb.place = str(poi.get("name", ""))
		await Flow.show_modal(wb)
		return
	if not Calendar.spend_ap(int(act.get("ap", 1))):
		return
	if int(act.get("money", 0)) > 0:
		GameState.spend_money(int(act["money"]))
	var lines := GameState.apply_effects(act.get("effects", {}))
	var said := str(act.get("say", ""))
	Narrator.say(("%s %s" % [said, " ".join(PackedStringArray(lines))]).strip_edges())


func _place_player() -> void:
	_player_sprite.position = Vector2(player_tile.x * TILE, (player_tile.y + 1) * TILE)


func _poi_at(tile: Vector2i) -> Dictionary:
	for poi in _pois:
		var t: Array = poi.get("tile", [0, 0])
		if Vector2i(int(t[0]), int(t[1])) == tile:
			return poi
	return {}


func _draw() -> void:
	var font: Font = UiTheme.font
	draw_rect(Rect2(0, 0, 480, 270), Color("1b1f2b"))
	for x in range(0, COLS + 1):
		draw_line(Vector2(x * TILE, TOP_ROWS * TILE), Vector2(x * TILE, (ROWS - 1) * TILE), Color(1, 1, 1, 0.05))
	for y in range(TOP_ROWS, ROWS):
		draw_line(Vector2(0, y * TILE), Vector2(COLS * TILE, y * TILE), Color(1, 1, 1, 0.05))
	var part_id := Calendar.part_id()
	for poi in _pois:
		var t: Array = poi.get("tile", [0, 0])
		var pos := Vector2(int(t[0]) * TILE, int(t[1]) * TILE)
		var color := Color(str(poi.get("color", "#888888")))
		if not Array(poi.get("openParts", [])).has(part_id):
			color = color.darkened(0.6)
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), color)
		draw_string(font, pos + Vector2(-8, -2), str(poi.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color(1, 1, 1, 0.8))

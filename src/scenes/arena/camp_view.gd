## The Arena Campfire (docs/ARENA_CAMPFIRE.md): a small walkable camp shown at
## each checkpoint. Walk with the movement keys, press E next to a station;
## the arena scene (host.camp_action) runs what the station does. Display and
## input only.
extends Node2D

const Camp := preload("res://src/core/arena/camp.gd")
const MapScript := preload("res://src/scenes/town/town_map.gd")
const Walker := preload("res://src/scenes/common/walker_sprite.gd")

var host: Node                  # the arena scene
var story := false
var wave := 0
var map: Node2D
var player: Node2D
var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var stations: Dictionary = {}   # cell -> station record
var _labels: Dictionary = {}    # station id -> Label
var _hud: Label
var _prompt: Label
var _moving := false
var _camera: Camera2D

var TILE: int:
	get: return Display.tile


func _ready() -> void:
	var db: Dictionary = DataDB.all()
	map = MapScript.new()
	map.build_custom(db, Camp.zone(db, wave))
	add_child(map)
	for s in Camp.stations(db, story):
		var c := Vector2i(int(s["cell"][0]), int(s["cell"][1]))
		stations[c] = s
		var l := UiTheme.world_label(Strings.t(str(s.get("label", ""))), UiTheme.ACCENT)
		l.position = Vector2(c * TILE) + Vector2(-TILE * 0.5, -UiTheme.FONT_SIZE - 2)
		map.add_child(l)
		_labels[str(s["id"])] = l
		var mark := ColorRect.new()
		mark.color = UiTheme.BAD if str(s.get("kind", "")) == "blacksmith" else UiTheme.ACCENT
		mark.modulate.a = 0.5
		mark.size = Vector2(TILE, TILE) * 0.75
		mark.position = Vector2(c * TILE) + Vector2(TILE, TILE) * 0.125
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.add_child(mark)
	var sp: Array = Camp.cfg(db).get("spawn", [10, 9])
	cell = Vector2i(int(sp[0]), int(sp[1]))
	player = Walker.new(str(GameState.player.get("sprite", Assets.role("player"))))
	player.position = _pos(cell)
	player.z_index = 5
	map.add_child(player)
	_camera = Camera2D.new()
	player.add_child(_camera)
	_camera.position = Vector2(TILE / 2.0, -TILE / 2.0)
	_camera.limit_left = 0
	_camera.limit_top = -TILE
	_camera.limit_right = maxi(map.size.x * TILE, Display.base.x)
	_camera.limit_bottom = maxi(map.size.y * TILE, Display.base.y)
	_camera.make_current()
	var ui := CanvasLayer.new()
	ui.layer = 4
	add_child(ui)
	_hud = UiTheme.label("", UiTheme.ACCENT)
	_hud.position = Vector2(4, 2)
	ui.add_child(_hud)
	_prompt = UiTheme.label("", UiTheme.ACCENT)
	_prompt.position = Vector2(4, Display.base.y - UiTheme.FONT_SIZE - 8)
	ui.add_child(_prompt)
	refresh()


func _pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE)


## Redraw the HUD and the done marks after an action.
func refresh() -> void:
	var arena: Dictionary = host.get("arena")
	_hud.text = Strings.t("camp.hud") % [int(arena.get("wave", 0)), int(arena.get("ap", 0)), int(arena.get("tickets", 0))]
	var done: Array = arena.get("campDone", [])
	for id in _labels:
		var l: Label = _labels[id]
		l.modulate = Color(1, 1, 1, 0.55) if done.has(id) else Color.WHITE
	_update_prompt()


## The station next to the player (or under them), or {}.
func _near() -> Dictionary:
	for d in [facing, Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if stations.has(cell + d):
			return stations[cell + d]
	return {}


func _update_prompt() -> void:
	var s := _near()
	_prompt.text = Strings.t("camp.press") % Strings.t(str(s.get("label", ""))) if not s.is_empty() else ""


func _unhandled_input(event: InputEvent) -> void:
	if Flow.is_busy() or _moving:
		return
	if event.is_action_pressed("interact"):
		var s := _near()
		if not s.is_empty():
			get_viewport().set_input_as_handled()
			await host.call("camp_action", s)
			if is_instance_valid(self):
				refresh()


func _process(_delta: float) -> void:
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
	if dir == Vector2i.ZERO:
		return
	facing = dir
	player.face(dir)
	var next := cell + dir
	if not map.walkable(next) or stations.has(next):
		_update_prompt()
		return
	_moving = true
	cell = next
	var tw := create_tween()
	tw.tween_property(player, "position", _pos(cell), 0.11)
	player.play_walk(0.11)
	await tw.finished
	_moving = false
	_update_prompt()

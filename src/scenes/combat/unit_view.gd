## An upright unit on the 2.5D battlefield: oval shadow, an integer-scaled
## pixel sprite facing left or right, and a small HP bar. Display only.
extends Node2D

const Walker := preload("res://src/scenes/common/walker_sprite.gd")
const SCALE := 2

var unit_id := ""
var team := "party"
var is_prop := false
var sprite: Sprite2D
var hp_ratio := 1.0
var shield := 0
var downed := false
var highlight := false
var statuses: Array = []   # short codes: RO, SL, BL, HA, RA, IN, GD

const STATUS_COLORS := { "RO": "#b07ce8", "SL": "#7cc7e8", "BL": "#f5e27a", "HA": "#9be36d", "RA": "#e87cc9", "IN": "#e8663c", "GD": "#c9c9c9" }
var _frame_w := 16
var _frame_h := 16
var _walker := false
var _bob := 0.0


func setup(id: String, p_team: String, sprite_path: String, frame: Array, prop_kind: String = "") -> void:
	unit_id = id
	team = p_team
	is_prop = prop_kind != ""
	if is_prop:
		return
	if frame.size() == 2:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.region_enabled = true
		_frame_w = int(frame[0])
		_frame_h = int(frame[1])
		sprite.region_rect = Rect2(0, 0, _frame_w, _frame_h)
		if ResourceLoader.exists(sprite_path):
			sprite.texture = load(sprite_path)
		sprite.offset = Vector2(-_frame_w / 2.0, -_frame_h)
		sprite.scale = Vector2(1, 1)
	else:
		var w := Walker.new(sprite_path)
		w.offset = Vector2(-8, -16)
		w.scale = Vector2(SCALE, SCALE)
		sprite = w
		_walker = true
	add_child(sprite)


func face(dir: int) -> void:
	if _walker:
		(sprite as Walker).face(Vector2i(dir, 0))
	elif sprite != null:
		sprite.flip_h = dir > 0


func walk_tick(delta: float) -> void:
	if _walker:
		(sprite as Walker).play_walk(delta)


func stop_walk() -> void:
	if _walker:
		(sprite as Walker).stop()


func _process(delta: float) -> void:
	if downed or is_prop:
		return
	_bob += delta
	queue_redraw()


func sprite_height() -> float:
	if is_prop:
		return 18.0
	if _walker:
		return 16.0 * SCALE
	return float(_frame_h)


func _draw() -> void:
	var w := 14.0 if not is_prop else 16.0
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * w, sin(a) * 3.5))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.35))
	if is_prop:
		var h := 18.0
		draw_rect(Rect2(-11, -h, 22, h), Color("7a5a3a"))
		draw_rect(Rect2(-11, -h, 22, 4), Color("9c7a52"))
		draw_rect(Rect2(-11, -h, 22, h), Color("3d2b1a"), false, 1.0)
		draw_line(Vector2(-11, -h), Vector2(11, 0), Color("3d2b1a"), 1.0)
	if highlight:
		draw_arc(Vector2.ZERO, w + 2.0, 0, TAU, 20, Color("ffd966"), 1.0)
	var top := -sprite_height() - 5.0
	var bar_w := 20.0
	draw_rect(Rect2(-bar_w / 2.0, top, bar_w, 3), Color(0, 0, 0, 0.7))
	var col := Color("8fd694") if team == "party" else Color("e8746a")
	if is_prop:
		col = Color("c9a66b")
	draw_rect(Rect2(-bar_w / 2.0, top, bar_w * clampf(hp_ratio, 0.0, 1.0), 3), col)
	if shield > 0:
		draw_rect(Rect2(-bar_w / 2.0, top - 2, bar_w, 1), Color("7cc7e8"))
	# Status chips sit in one row under the feet, clear of floating texts above.
	var chip_x := -float(statuses.size()) * 5.0
	for code in statuses:
		var c := Color(str(STATUS_COLORS.get(str(code), "#ffffff")))
		draw_rect(Rect2(chip_x, 5, 8, 4), c)
		draw_rect(Rect2(chip_x, 5, 8, 4), Color(0, 0, 0, 0.6), false, 1.0)
		chip_x += 10.0
	if downed and sprite != null:
		sprite.modulate = Color(0.5, 0.5, 0.6, 0.6)
		sprite.rotation = PI / 2.0 if team == "party" else -PI / 2.0
	elif sprite != null:
		sprite.modulate = Color.WHITE
		sprite.rotation = 0.0

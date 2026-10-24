## A 4-direction walking sprite from a walk sheet asset id (columns down, up,
## left, right; rows 0-3 are the walk cycle; frame size from the manifest).
## Scenes set the sheet, call face() and play_walk(); position is the feet.
class_name WalkerSprite
extends Sprite2D

const DIR_COLUMN := { Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3 }

var facing := Vector2i.DOWN
var frame_size := Vector2i.ONE
var _frame := 0
var _walk_time := 0.0


func _init(sheet_id: String = "") -> void:
	centered = false
	region_enabled = true
	if sheet_id != "":
		set_sheet(sheet_id)


func set_sheet(sheet_id: String) -> void:
	texture = Assets.texture(sheet_id)
	frame_size = Assets.frame(sheet_id)
	offset = Vector2(0, -frame_size.y)
	_update_region()


func face(dir: Vector2i) -> void:
	if DIR_COLUMN.has(dir):
		facing = dir
	_update_region()


## Advance the walk cycle for `seconds` of walking.
func play_walk(seconds: float) -> void:
	_walk_time += seconds
	_frame = int(_walk_time / 0.12) % 4
	_update_region()


func stop() -> void:
	_walk_time = 0.0
	_frame = 0
	_update_region()


func _update_region() -> void:
	var col := int(DIR_COLUMN.get(facing, 0))
	# A sheet smaller than 4x4 frames (a placeholder) shows its first frame.
	if texture != null and (texture.get_width() < frame_size.x * 4 or texture.get_height() < frame_size.y * 4):
		region_rect = Rect2(Vector2.ZERO, Vector2(frame_size).min(Vector2(texture.get_size())))
		return
	region_rect = Rect2(col * frame_size.x, _frame * frame_size.y, frame_size.x, frame_size.y)

## A 4-direction walking sprite from a Ninja Adventure character sheet
## (64x112: columns down, up, left, right; rows 0-3 are the walk cycle).
## Scenes set `sheet`, call face() and play_walk(); position is the feet.
class_name WalkerSprite
extends Sprite2D

const FRAME := 16
const DIR_COLUMN := { Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3 }

var facing := Vector2i.DOWN
var _frame := 0
var _walk_time := 0.0


func _init(sheet_path: String = "") -> void:
	centered = false
	offset = Vector2(0, -FRAME)
	region_enabled = true
	if sheet_path != "":
		set_sheet(sheet_path)


func set_sheet(sheet_path: String) -> void:
	if ResourceLoader.exists(sheet_path):
		texture = load(sheet_path)
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
	region_rect = Rect2(int(DIR_COLUMN.get(facing, 0)) * FRAME, _frame * FRAME, FRAME, FRAME)

## The camera's limits (M12), from this marker's tile, `tiles` wide and high.
## Without one, the zone's size is used.
@tool
extends "res://src/world/markers/marker.gd"

@export var tiles := Vector2i(10, 10):
	set(v):
		tiles = v
		queue_redraw()


func marker_color() -> Color:
	return Color("a0a0a0")


func marker_label() -> String:
	return "camera"


func marker_rect() -> Rect2i:
	return Rect2i(Vector2i.ZERO, tiles)

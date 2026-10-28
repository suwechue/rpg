## An exit to another zone (M12): stepping on any of its tiles goes to zone
## `to`, arriving at `spawn` (a tile in that zone).
@tool
extends "res://src/world/markers/marker.gd"

@export var to := "":
	set(v):
		to = v
		queue_redraw()
@export var tiles := Vector2i(1, 2):
	set(v):
		tiles = v
		queue_redraw()
@export var spawn := Vector2i.ZERO


func marker_color() -> Color:
	return Color("f28482")


func marker_label() -> String:
	return "exit to " + to


func marker_rect() -> Rect2i:
	return Rect2i(Vector2i.ZERO, tiles)

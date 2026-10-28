## A place people stand (M12): `spot_id` is an outdoor location id (town_square)
## or any name; tags ("bench", "counter", "crowd") say what kind of spot it is.
@tool
extends "res://src/world/markers/marker.gd"

@export var spot_id := "":
	set(v):
		spot_id = v
		queue_redraw()
@export var tags: PackedStringArray = []


func marker_color() -> Color:
	return Color("7bdff2")


func marker_label() -> String:
	return "spot: " + spot_id

## A building's door (M12): `loc` is a location id from data/town/locations.json.
## `building` is the building's tiles relative to the door tile (it blocks
## walking and shows lit windows); `sign` is the name drawn on it (blank =
## the location's name, so every house gets a nameplate).
@tool
extends "res://src/world/markers/marker.gd"

@export var loc := "":
	set(v):
		loc = v
		queue_redraw()
@export var sign_text := ""
@export var building := Rect2i(-2, -4, 5, 5):
	set(v):
		building = v
		queue_redraw()


func marker_color() -> Color:
	return Color("ffd166")


func marker_label() -> String:
	return "door: " + loc


func marker_rect() -> Rect2i:
	return building

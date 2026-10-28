## Where the player appears (M12): `spawn_id` "default" when arriving by bus or
## a new day; others for story scenes.
@tool
extends "res://src/world/markers/marker.gd"

@export var spawn_id := "default"


func marker_color() -> Color:
	return Color("cdb4db")


func marker_label() -> String:
	return "spawn: " + spawn_id

## Something to press E on (M12): a sign (`says` is read aloud), or a map
## label (`map_label` is drawn above it, like the water tower).
@tool
extends "res://src/world/markers/marker.gd"

@export var says := ""
@export var map_label := ""


func marker_color() -> Color:
	return Color("b8f2a5")


func marker_label() -> String:
	return "sign" if map_label == "" else map_label

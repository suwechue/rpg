## The root of a zone scene (ROADMAP M12, src/world/zones/<id>.tscn). Paint
## tiles on the Ground and Objects layers (Objects block walking), mark extra
## walls on Collision and water on Water, drop blocks from src/world/blocks/
## and markers from src/world/markers/. See docs/MAP_GUIDE.md.
@tool
extends Node2D

@export var zone_id := ""
## The zone's size in tiles (walkable area and default camera limits).
@export var tiles := Vector2i(60, 34)

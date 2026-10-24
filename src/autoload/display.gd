## Screen and art sizes from data/display.json (ROADMAP M10). Scenes read
## `Display.tile`, `Display.base` and friends instead of literal sizes.
extends Node

var tile := 0                     # one map tile, in pixels
var base := Vector2i.ZERO         # the game's pixel resolution before scaling
var character := Vector2i.ZERO
var portrait := Vector2i.ZERO
var detail := 1.0                 # multiplier for hand-drawn overlay offsets
var combat: Dictionary = {}


func _ready() -> void:
	reload()
	if DisplayServer.get_name() != "headless":
		var win := get_window()
		win.content_scale_size = base
		var scale := int(DataDB.table("display").get("windowScale", 1))
		if not Engine.is_embedded_in_editor() and win.mode == Window.MODE_WINDOWED:
			win.size = base * scale


func reload() -> void:
	var d: Dictionary = DataDB.table("display")
	tile = int(d.get("tileSize", 0))
	base = Vector2i(int(d.get("baseWidth", 0)), int(d.get("baseHeight", 0)))
	character = _vec(d.get("characterSize", []))
	portrait = _vec(d.get("portraitSize", []))
	detail = float(d.get("detailScale", 1))
	combat = d.get("combat", {})


func _vec(a: Variant) -> Vector2i:
	if a is Array and a.size() == 2:
		return Vector2i(int(a[0]), int(a[1]))
	return Vector2i.ZERO


func tile_v() -> Vector2i:
	return Vector2i(tile, tile)


func size_f() -> Vector2:
	return Vector2(base)


## Pixel position of a map cell's top-left corner.
func cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell * tile)

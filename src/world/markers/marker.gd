## Base for map markers (ROADMAP M12): nodes dragged into a zone or block
## scene. In the editor each draws a colored square on its tile and a label;
## in the game they are invisible and read by src/world/zone_reader.gd.
## Place a marker on the tile it marks (its position is the tile's top left).
@tool
extends Node2D

static var _tile := 0


## The tile size from data/display.json (markers run in the editor, where
## autoloads aren't available).
static func tile() -> int:
	if _tile == 0:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/display.json"))
		_tile = int(d.get("tileSize", 1)) if d is Dictionary else 1
	return _tile


func _ready() -> void:
	visible = Engine.is_editor_hint()


func marker_color() -> Color:
	return Color(1, 1, 1, 0.5)


func marker_label() -> String:
	return name


## Extra tiles to outline (relative, in tiles), for exits and buildings.
func marker_rect() -> Rect2i:
	return Rect2i(0, 0, 1, 1)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var t := float(tile())
	var r := marker_rect()
	draw_rect(Rect2(Vector2(r.position) * t, Vector2(r.size) * t), marker_color() * Color(1, 1, 1, 0.35))
	draw_rect(Rect2(Vector2(r.position) * t, Vector2(r.size) * t), marker_color(), false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(t, t)), marker_color(), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(2, -3), marker_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, marker_color())

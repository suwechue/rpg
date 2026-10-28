## A tiny footprint diagram (PT Part 3): a mini grid with the caster marked and
## the tiles a Form (at a Magnitude) or a boss pattern hits. Used on cards, in
## the deck editor and in the enemy hover panel. Display only.
extends Control

const GridScript := preload("res://src/core/combat/grid.gd")
const Forms := preload("res://src/core/combat/forms.gd")

const COLS := 7
const ROWS := 5

var cells: Array = []
var caster := Vector2i(1, 2)
var color := Color(1.0, 0.4, 0.35)
var cell_px := 3


## form: a Form record (data/forms.json); magnitude picks the footprint size.
func setup(form: Dictionary, magnitude: String = "standard", tint: Color = Color(1.0, 0.4, 0.35), px: int = 3) -> void:
	color = tint
	cell_px = px
	custom_minimum_size = Vector2(COLS * px + 1, ROWS * px + 1)
	var row := ".".repeat(COLS)
	var grid := GridScript.new({ "map": [row, row, row, row, row] })
	var f := Forms.at_magnitude(form, magnitude)
	var r := int(f.get("range", 1))
	caster = Vector2i(1, 2)
	var target := caster if r <= 0 or str(f.get("target", "")) == "self" else Vector2i(mini(caster.x + mini(r, 4), COLS - 1), 2)
	if str(f.get("footprint", "")) in ["single_los", "adjacent", "first_in_line"] and r > 1:
		target = Vector2i(mini(caster.x + 3, COLS - 1), 2)
	cells = Forms.footprint(grid, f, caster, target, {})
	queue_redraw()


func _draw() -> void:
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			var r := Rect2(Vector2(x * cell_px, y * cell_px), Vector2(cell_px - 1, cell_px - 1))
			if cells.has(c):
				draw_rect(r, color)
			elif c == caster:
				draw_rect(r, UiTheme.ACCENT)
			else:
				draw_rect(r, Color(1, 1, 1, 0.12))

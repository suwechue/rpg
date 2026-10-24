## Maps the flat combat grid to the 2.5D screen (DESIGN.md Section 9,
## "Battlefield and camera"). Rows further back (row 0) sit higher on screen and
## are narrower by `shrink` per row, so the floor reads as seen from ~30 degrees.
## Cells are trapezoids: row boundary k sits at y[k] with width scale s[k].
## Pure math (no nodes), so tests can check that to_cell() inverts the cells.
class_name GridProjection
extends RefCounted

var cols := 9
var rows := 5
var center_x := 240.0
var front_y := 196.0       # screen y of the front edge (bottom of the last row)
var cell_w := 44.0         # front-row cell width
var cell_h := 22.0         # front-row cell height
var shrink := 0.9          # each row back is 10% narrower
var _y: Array = []         # boundary k -> screen y (k = 0 back edge ... rows = front edge)
var _s: Array = []         # boundary k -> width scale


func _init(p_cols: int = 9, p_rows: int = 5, p_center_x: float = 240.0, p_front_y: float = 196.0, p_cell_w: float = 44.0, p_cell_h: float = 22.0, p_shrink: float = 0.9) -> void:
	cols = p_cols
	rows = p_rows
	center_x = p_center_x
	front_y = p_front_y
	cell_w = p_cell_w
	cell_h = p_cell_h
	shrink = p_shrink
	_y.resize(rows + 1)
	_s.resize(rows + 1)
	for k in range(rows, -1, -1):
		_s[k] = pow(shrink, rows - k)
	_y[rows] = front_y
	for k in range(rows - 1, -1, -1):
		var row_h: float = cell_h * (float(_s[k]) + float(_s[k + 1])) / 2.0
		_y[k] = float(_y[k + 1]) - row_h


## Screen point of the grid corner at column line j, row line k.
func corner(j: int, k: int) -> Vector2:
	var s: float = _s[k]
	return Vector2(center_x + (float(j) - float(cols) / 2.0) * cell_w * s, float(_y[k]))


## The cell's trapezoid, clockwise from top-left.
func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([
		corner(cell.x, cell.y), corner(cell.x + 1, cell.y),
		corner(cell.x + 1, cell.y + 1), corner(cell.x, cell.y + 1)])


## Where a unit standing on the cell puts its feet (the trapezoid's center).
func cell_center(cell: Vector2i) -> Vector2:
	var p := cell_polygon(cell)
	return (p[0] + p[1] + p[2] + p[3]) / 4.0


func row_scale(row: int) -> float:
	return (float(_s[row]) + float(_s[row + 1])) / 2.0


func top_y() -> float:
	return float(_y[0])


## Inverse projection: the cell under a screen point, or (-1, -1) if outside.
## Column edges are straight lines between boundary corners, so the width scale
## varies linearly with y inside a row and the inverse is exact.
func to_cell(p: Vector2) -> Vector2i:
	if p.y < float(_y[0]) or p.y >= float(_y[rows]):
		return Vector2i(-1, -1)
	var r := 0
	while r < rows - 1 and p.y >= float(_y[r + 1]):
		r += 1
	var t := (p.y - float(_y[r])) / (float(_y[r + 1]) - float(_y[r]))
	var s := lerpf(float(_s[r]), float(_s[r + 1]), t)
	var fx := (p.x - center_x) / (cell_w * s) + float(cols) / 2.0
	if fx < 0.0 or fx >= float(cols):
		return Vector2i(-1, -1)
	return Vector2i(floori(fx), r)

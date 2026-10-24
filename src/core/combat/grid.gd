## The flat logic grid for tactical combat. Knows nothing about the camera:
## cells are Vector2i(col, row), row 0 is the back row. Terrain comes from a
## layout record in data/rooms/; temporary tile effects (burning, steam) count
## down each round. Units and props are tracked by CombatState, which passes
## the occupied cells in when it asks for paths.
class_name CombatGrid
extends RefCounted

const FLOOR := "floor"
const WALL := "wall"
const COVER := "cover"
const HAZARD := "hazard"
const WATER := "water"
const ICE := "ice"

const LEGEND := { ".": FLOOR, "#": WALL, "c": COVER, "h": HAZARD, "w": WATER, "i": ICE }
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var cols := 9
var rows := 5
var terrain: Array = []          # rows of terrain ids
var burning: Dictionary = {}     # Vector2i -> turns left
var steam: Dictionary = {}       # Vector2i -> turns left
var fire_walls: Dictionary = {}  # Vector2i -> turns left: burning tiles nobody can walk through
var toxic: Dictionary = {}       # Vector2i -> turns left: Corrosion puddles
var exits: Array = []            # Vector2i cells the party can flee from
var party_spawns: Array = []
var enemy_spawns: Array = []
var prop_spawns: Array = []      # [{ "cell": Vector2i, "prop": "crate" }]
var theme := ""


## layout: { "cols", "rows", "map": ["P..x...E", ...], "theme" }
## Map letters: . floor, # wall, c cover, h hazard, w water, i ice,
## P party spawn, E enemy spawn, < exit (floor), x crate prop (floor under it).
func _init(layout: Dictionary = {}) -> void:
	var map: Array = layout.get("map", [])
	rows = maxi(1, map.size()) if not map.is_empty() else int(layout.get("rows", 5))
	cols = str(map[0]).length() if not map.is_empty() else int(layout.get("cols", 9))
	theme = str(layout.get("theme", ""))
	terrain = []
	for r in rows:
		var row: Array = []
		var line := str(map[r]) if r < map.size() else ""
		for c in cols:
			var ch := line[c] if c < line.length() else "."
			var cell := Vector2i(c, r)
			match ch:
				"P":
					party_spawns.append(cell)
				"E":
					enemy_spawns.append(cell)
				"<":
					exits.append(cell)
				"x":
					prop_spawns.append({ "cell": cell, "prop": "crate" })
			row.append(LEGEND.get(ch, FLOOR))
		terrain.append(row)
	if exits.is_empty():
		for r in rows:
			if walkable_terrain(Vector2i(0, r)):
				exits.append(Vector2i(0, r))


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func get_terrain(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return WALL
	return str(terrain[cell.y][cell.x])


func set_terrain(cell: Vector2i, t: String) -> void:
	if in_bounds(cell):
		terrain[cell.y][cell.x] = t


## Terrain you can stand on (water only once frozen).
func walkable_terrain(cell: Vector2i) -> bool:
	var t := get_terrain(cell)
	return t != WALL and t != WATER and not fire_walls.has(cell)


func blocks_sight(cell: Vector2i) -> bool:
	return get_terrain(cell) == WALL or steam.has(cell)


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Cells on the straight segment between a and b (Bresenham), excluding both ends.
static func cells_between(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while p != b:
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
		if p != b:
			out.append(p)
	return out


## Line of sight: no wall, steam or blocking cell between a and b.
func has_los(a: Vector2i, b: Vector2i, blockers: Dictionary = {}) -> bool:
	for c in cells_between(a, b):
		if blocks_sight(c) or blockers.has(c):
			return false
	return true


## Cells reachable within `budget` steps, avoiding walls, water and occupied
## cells. Returns { Vector2i: steps }. The start cell is included at 0.
func reachable(start: Vector2i, budget: int, occupied: Dictionary) -> Dictionary:
	var dist := { start: 0 }
	var frontier: Array = [start]
	while not frontier.is_empty():
		var next: Array = []
		for cell in frontier:
			var d := int(dist[cell])
			if d >= budget:
				continue
			for dir in DIRS:
				var n: Vector2i = cell + dir
				if dist.has(n) or not in_bounds(n) or not walkable_terrain(n) or occupied.has(n):
					continue
				dist[n] = d + 1
				next.append(n)
		frontier = next
	return dist


## Shortest path from a to b with AStarGrid2D (4-way). Empty if unreachable.
## The path excludes `a` and includes `b`.
func path(a: Vector2i, b: Vector2i, occupied: Dictionary) -> Array:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, cols, rows)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for r in rows:
		for c in cols:
			var cell := Vector2i(c, r)
			if not walkable_terrain(cell) or (occupied.has(cell) and cell != a and cell != b):
				astar.set_point_solid(cell, true)
	if astar.is_point_solid(b) or not in_bounds(a) or not in_bounds(b):
		return []
	var ids := astar.get_id_path(a, b)
	var out: Array = []
	for i in range(1, ids.size()):
		out.append(ids[i])
	return out


## Count down tile effects at the end of a round.
func tick_round() -> void:
	for table in [burning, steam, fire_walls, toxic]:
		for cell in table.keys():
			table[cell] = int(table[cell]) - 1
			if int(table[cell]) <= 0:
				table.erase(cell)


func all_cells() -> Array:
	var out: Array = []
	for r in rows:
		for c in cols:
			out.append(Vector2i(c, r))
	return out

## Draws the battlefield: themed backdrop, the trapezoid floor, terrain, tile
## effects and the tinted overlays (reach, card range, footprint in the card's
## Vector color, enemy telegraphs with their damage, push landings, predicted
## numbers, hover).
## Display only; the controller sets the overlay arrays and calls queue_redraw().
extends Node2D

const Proj := preload("res://src/scenes/combat/grid_projection.gd")
const GridScript := preload("res://src/core/combat/grid.gd")

var proj: Proj
var grid: GridScript
var theme_rec: Dictionary = {}
var reach_cells: Array = []
var target_cells: Array = []
var footprint_cells: Array = []
var footprint_heal := false
var footprint_color := Color(1.0, 0.35, 0.3, 0.45)
var threat_cells: Dictionary = {}    # cell -> { "damage": n, "charge": n }
var push_marks: Array = []           # [{ "from", "to", "collide", "hazard", "slide" }]
var preview_labels: Dictionary = {}  # cell -> text drawn above the unit there
var support_cells: Array = []        # enemy heals and summons (green)
var threat_view := false             # held: every tile shaded by incoming damage
var cover_cells: Array = []          # reachable tiles next to cover (outlined while moving)
var telegraphs: Array = []           # PT Part 3: [{ "unit", "from", "cells", "tag", "tint", "since" }] one per planning enemy
var focus_cells: Array = []          # the hovered enemy's tiles (or the hovered red tile's attackers' tiles)
var lingering: Dictionary = {}       # cell -> rounds left (burning, toxic, glyphs), drawn as small counters
var move_marks: Array = []           # enemy plans: [{ "from", "to" }] where they'll walk first
var hover_cell := Vector2i(-1, -1)
var cursor_cell := Vector2i(-1, -1)
var glyph_cells: Array = []
var flash_cells: Array = []
var flash_color := Color.WHITE
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	if not grid.burning.is_empty() or not flash_cells.is_empty() or not threat_cells.is_empty() or not telegraphs.is_empty():
		queue_redraw()


func col(key: String, fallback: String) -> Color:
	return Color(str(theme_rec.get(key, fallback)))


func _draw() -> void:
	if proj == null or grid == null:
		return
	_draw_backdrop()
	for r in grid.rows:
		for c in grid.cols:
			_draw_cell(Vector2i(c, r))
	if threat_view:
		_draw_threat_view()
		return
	_draw_overlay(reach_cells, Color(0.45, 0.75, 1.0, 0.28))
	for c in cover_cells:
		draw_polyline(_closed(proj.cell_polygon(c)), Color(0.5, 0.8, 1.0, 0.9), 1.0)
	_draw_threats()
	_draw_telegraph_shapes()
	_draw_overlay(support_cells, Color(UiTheme.GOOD, 0.3))
	for m in move_marks:
		var a := proj.cell_center(m["from"])
		var b := proj.cell_center(m["to"])
		var c := Color(UiTheme.color("bad"), 0.8)
		var steps := 6
		for i in steps:
			if i % 2 == 0:
				draw_line(a.lerp(b, float(i) / steps), a.lerp(b, float(i + 1) / steps), c, 1.0)
		draw_arc(b, 5.0, 0, TAU, 12, c, 1.0)
	_draw_overlay(target_cells, Color(1.0, 0.85, 0.4, 0.22))
	_draw_overlay(footprint_cells, Color(0.55, 1.0, 0.6, 0.45) if footprint_heal else footprint_color)
	_draw_overlay(flash_cells, flash_color)
	_draw_pushes()
	for g in glyph_cells:
		var ctr := proj.cell_center(g)
		draw_arc(ctr, 6.0, 0, TAU, 12, Color("b07ce8"), 1.0)
		draw_line(ctr + Vector2(-4, 0), ctr + Vector2(4, 0), Color("b07ce8"), 1.0)
	if hover_cell.x >= 0:
		draw_polyline(_closed(proj.cell_polygon(hover_cell)), Color("ffd966"), 1.0)
	if cursor_cell.x >= 0 and cursor_cell != hover_cell:
		draw_polyline(_closed(proj.cell_polygon(cursor_cell)), Color("ffffff"), 1.0)
	for cell in preview_labels:
		var at := proj.cell_center(cell) + Vector2(-8, -Display.tile * 1.6)
		draw_string_outline(UiTheme.font, at, str(preview_labels[cell]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, 3, UiTheme.color("outline"))
		draw_string(UiTheme.font, at, str(preview_labels[cell]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, UiTheme.ACCENT)


## Threat view: safe tiles dimmed, threatened ones from pale to deep red by damage.
func _draw_threat_view() -> void:
	var worst := 1
	for c in threat_cells:
		worst = maxi(worst, int(threat_cells[c].get("damage", 0)))
	for r in grid.rows:
		for c in grid.cols:
			var cell := Vector2i(c, r)
			var poly := proj.cell_polygon(cell)
			if threat_cells.has(cell):
				var k := float(threat_cells[cell].get("damage", 0)) / float(worst)
				draw_colored_polygon(poly, Color(UiTheme.color("bad"), 0.25 + 0.55 * k))
				var at := (poly[3] + poly[2]) / 2.0 + Vector2(-6, -2)
				draw_string_outline(UiTheme.font, at, str(int(threat_cells[cell].get("damage", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, 3, UiTheme.color("outline"))
				draw_string(UiTheme.font, at, str(int(threat_cells[cell].get("damage", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, UiTheme.TEXT)
			else:
				draw_colored_polygon(poly, Color(0, 0, 0, 0.35))


## Enemy telegraphs: red tiles (pulsing harder while charging) with the damage waiting there.
func _draw_threats() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	for cell in threat_cells:
		var t: Dictionary = threat_cells[cell]
		var charging := int(t.get("charge", 0)) > 0
		var c := UiTheme.color("bad")
		c.a = (0.35 + 0.25 * pulse) if charging else 0.45
		var poly := proj.cell_polygon(cell)
		draw_colored_polygon(poly, c)
		draw_polyline(_closed(poly), Color(UiTheme.color("bad"), 0.9), 2.0 if charging else 1.0)
		var dmg := int(t.get("damage", 0))
		if dmg > 0:
			# On the tile's front edge, where a unit standing there doesn't cover it.
			var at := (poly[3] + poly[2]) / 2.0 + Vector2(-6, -2)
			draw_string_outline(UiTheme.font, at, str(dmg), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, 3, UiTheme.color("outline"))
			draw_string(UiTheme.font, at, str(dmg), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, UiTheme.color("damage"))


## Each enemy's telegraph as one shape (PT Part 3): its own tint, an outline
## around the whole footprint, a line from the attacker, the enemy's number on
## its tiles, and a short pulse when it first appears. Hovered ones stand out.
func _draw_telegraph_shapes() -> void:
	for t in telegraphs:
		var cells: Array = t["cells"]
		if cells.is_empty():
			continue
		var tint: Color = t["tint"]
		var age := _time - float(t.get("since", 0.0))
		var pulse := clampf(1.0 - age / 0.6, 0.0, 1.0)
		var focused := focus_cells.has(cells[0])
		var w := 2.0 if focused else 1.0
		var set := {}
		for c in cells:
			set[c] = true
		for c in cells:
			var poly := proj.cell_polygon(c)
			if pulse > 0.0 or focused:
				draw_colored_polygon(poly, Color(tint, 0.25 * pulse + (0.25 if focused else 0.0)))
			# Outline only the shape's outer edges.
			var edges := [[Vector2i(0, -1), 0, 1], [Vector2i(1, 0), 1, 2], [Vector2i(0, 1), 2, 3], [Vector2i(-1, 0), 3, 0]]
			for e in edges:
				if not set.has(c + e[0]):
					draw_line(poly[e[1]], poly[e[2]], Color(tint, 0.95), w)
		var center := Vector2.ZERO
		for c in cells:
			center += proj.cell_center(c)
		center /= float(cells.size())
		var from := proj.cell_center(t["from"])
		draw_line(from, center, Color(tint, 0.5 if not focused else 0.9), 1.0)
		if str(t.get("badge", "")) != "":
			var bat := proj.cell_center(cells[0]) + Vector2(-10, -10)
			draw_string_outline(UiTheme.font, bat, str(t["badge"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, 2, UiTheme.color("outline"))
			draw_string(UiTheme.font, bat, str(t["badge"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, UiTheme.ACCENT)
		if int(t.get("tag", 0)) > 0:
			var at := proj.cell_center(cells[0]) + Vector2(4, -2)
			draw_string_outline(UiTheme.font, at, str(t["tag"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, 2, UiTheme.color("outline"))
			draw_string(UiTheme.font, at, str(t["tag"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, tint.lightened(0.4))
	for c in lingering:
		var at := proj.cell_center(c) + Vector2(-9, 2)
		draw_string_outline(UiTheme.font, at, str(lingering[c]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, 2, UiTheme.color("outline"))
		draw_string(UiTheme.font, at, str(lingering[c]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, UiTheme.ACCENT)


## Where pushed or pulled units would land: an arrow and a ring, "!" on a collision or hazard.
func _draw_pushes() -> void:
	for m in push_marks:
		var a := proj.cell_center(m["from"])
		var b := proj.cell_center(m["to"])
		var c := UiTheme.ACCENT
		if a != b:
			draw_line(a, b, c, 1.0)
			draw_arc(b, 6.0, 0, TAU, 12, c, 1.0)
		if bool(m.get("collide", false)) or bool(m.get("hazard", false)):
			var at := b + Vector2(5, -4)
			draw_string_outline(UiTheme.font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, 3, UiTheme.color("outline"))
			draw_string(UiTheme.font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, UiTheme.color("bad"))


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	out.append(p[0])
	return out


func _draw_backdrop() -> void:
	var top := col("skyTop", "#1a1030")
	var bottom := col("skyBottom", "#4a2c5e")
	var horizon_y := proj.top_y()
	var view := Display.size_f()
	var steps := 12
	for i in steps:
		var y0 := horizon_y * float(i) / float(steps)
		var y1 := horizon_y * float(i + 1) / float(steps)
		draw_rect(Rect2(0, y0, view.x, y1 - y0 + 1), top.lerp(bottom, float(i) / float(steps - 1)))
	# A skyline of crooked town shapes, the Upside-Down version of wherever this is.
	var hcol := col("horizon", "#251b38")
	var x := 0.0
	var i := 0
	while x < view.x:
		var w := 18.0 + float((i * 37) % 23)
		var h := 14.0 + float((i * 53) % 29)
		draw_rect(Rect2(x, horizon_y - h, w - 2.0, h), hcol)
		if (i % 3) == 0:
			draw_rect(Rect2(x + 4, horizon_y - h + 4, 3, 3), col("accent", "#f5e27a").darkened(0.4))
		x += w
		i += 1
	draw_rect(Rect2(0, horizon_y, view.x, view.y - horizon_y), hcol.darkened(0.3))


func _draw_cell(cell: Vector2i) -> void:
	var poly := proj.cell_polygon(cell)
	var t := grid.get_terrain(cell)
	var depth := 1.0 - 0.06 * float(grid.rows - 1 - cell.y)
	var base := col("floor", "#3b3552") if (cell.x + cell.y) % 2 == 0 else col("floorAlt", "#343049")
	match t:
		GridScript.WATER:
			base = Color("2c5d8a")
		GridScript.ICE:
			base = Color("a9d8ef")
		GridScript.HAZARD:
			base = Color("6b4a1a")
		GridScript.COVER:
			base = base.lightened(0.08)
		GridScript.WALL:
			base = base.darkened(0.5) if grid.wall_hp.has(cell) else base.darkened(0.7)
		GridScript.RUBBLE:
			base = base.lerp(Color("6e6a62"), 0.4)
		GridScript.PIT:
			base = Color("050308")
		GridScript.COLLAPSE:
			base = base.lerp(Color("6b4a2a"), 0.35)
		GridScript.DARK:
			base = base.darkened(0.25)
	if grid.exits.has(cell):
		base = base.lerp(Color("3d6b4a"), 0.5)
	draw_colored_polygon(poly, base * Color(depth, depth, depth, 1.0))
	draw_polyline(_closed(poly), col("line", "#6d6391") * Color(1, 1, 1, 0.45), 1.0)
	var ctr := proj.cell_center(cell)
	if t == GridScript.RUBBLE:
		for i in 3:
			draw_rect(Rect2(ctr + Vector2(-6 + i * 4, -2 + (i % 2) * 2), Vector2(3, 2)), Color("9a958a"))
	if grid.wall_hp.has(cell) and int(grid.wall_hp[cell]) < int(DataDB.table("stats").get("combat", {}).get("walls", {}).get("wallHp", 25)):
		# A cracked wall: it has taken damage.
		draw_line(ctr + Vector2(-5, -3), ctr + Vector2(0, 1), Color("1d140c"), 1.0)
		draw_line(ctr + Vector2(0, 1), ctr + Vector2(4, -2), Color("1d140c"), 1.0)
	if t == GridScript.HAZARD:
		draw_line(ctr + Vector2(-5, -2), ctr + Vector2(5, 2), Color("e8b04a"), 1.0)
		draw_line(ctr + Vector2(-5, 2), ctr + Vector2(5, -2), Color("e8b04a"), 1.0)
	if t == GridScript.COVER:
		draw_rect(Rect2(ctr + Vector2(-7, -9), Vector2(14, 7)), Color("4f7a3a"))
		draw_rect(Rect2(ctr + Vector2(-7, -9), Vector2(14, 7)), Color("2c4a20"), false, 1.0)
	if grid.burning.has(cell):
		var flick := 0.5 + 0.5 * sin(_time * 9.0 + float(cell.x))
		draw_colored_polygon(poly, Color(1.0, 0.45, 0.15, 0.25 + 0.2 * flick))
	if grid.steam.has(cell):
		draw_colored_polygon(poly, Color(0.9, 0.9, 0.95, 0.45))
	if t == GridScript.COLLAPSE and grid.cracked.has(cell):
		draw_line(ctr + Vector2(-7, -2), ctr + Vector2(1, 1), Color("1d140c"), 1.0)
		draw_line(ctr + Vector2(1, 1), ctr + Vector2(6, -1), Color("1d140c"), 1.0)
	if GridScript.CONVEYORS.has(t):
		var dir: Vector2i = GridScript.CONVEYORS[t]
		var tip := ctr + Vector2(dir) * 6.0
		draw_line(ctr - Vector2(dir) * 6.0, tip, UiTheme.ACCENT, 1.0)
		draw_line(tip, tip - Vector2(dir) * 3.0 + Vector2(dir.y, dir.x) * 3.0, UiTheme.ACCENT, 1.0)
		draw_line(tip, tip - Vector2(dir) * 3.0 - Vector2(dir.y, dir.x) * 3.0, UiTheme.ACCENT, 1.0)
	if t == GridScript.DARK and not grid.lit.has(cell):
		draw_colored_polygon(poly, Color(0, 0, 0, 0.55))
	if grid.toxic.has(cell):
		draw_colored_polygon(poly, Color(UiTheme.vector_color("corrosion"), 0.45))
	if grid.fire_walls.has(cell):
		var top := ctr + Vector2(0, -Display.tile * 0.6)
		draw_line(ctr + Vector2(-6, 0), top, Color(1.0, 0.55, 0.2, 0.9), 3.0)
		draw_line(ctr + Vector2(6, 0), top + Vector2(0, 4), Color(1.0, 0.75, 0.3, 0.9), 2.0)
	if grid.exits.has(cell):
		draw_string(UiTheme.font, ctr + Vector2(-3, 3), "<", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color("8fd694"))


func _draw_overlay(cells: Array, color: Color) -> void:
	for c in cells:
		draw_colored_polygon(proj.cell_polygon(c), color)

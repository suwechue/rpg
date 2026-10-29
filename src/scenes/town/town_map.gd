## Builds one town map (a zone scene from src/world/zones/ built in the editor
## (M12), else a zone from data/town/zones/, or an interior template
## from data/town/interiors.json) as TileMapLayers stamped from the tilesets
## named in data/town/styles.json "packs" (asset ids), plus a drawn overlay for water, furniture, signs,
## lit windows and shut doors. Display only; the town scene asks it what is
## blocked, where doors, spots and exits are.
extends Node2D

const SRC := { "town": 0, "city": 1, "floor": 2 }
const Locs := preload("res://src/core/town/locations.gd")
const ZoneReader := preload("res://src/world/zone_reader.gd")
const TileTints := preload("res://src/world/tile_tints.gd")
const ZONE_DIR := "res://src/world/zones/"

var TILE: int:
	get: return Display.tile

var map_id := ""
var is_interior := false
var size := Vector2i(30, 17)
var blocked: Dictionary = {}       # Vector2i -> true
var doors: Dictionary = {}         # door cell -> { "loc", "approach": Vector2i }
var door_by_loc: Dictionary = {}   # loc id -> door cell
var spots: Dictionary = {}         # loc id -> Vector2i
var exits: Array = []              # [{ "rect": Rect2i, "to", "spawn" }]
var furniture: Dictionary = {}     # cell -> furniture record
var signs: Dictionary = {}         # cell -> text
var interior_exit := Vector2i(-1, -1)
var room_doors: Dictionary = {}    # school hall: cell -> room loc id
var lit: Array = []                # loc ids with someone home
var shut: Dictionary = {}          # loc id -> "closed" | "story" (drawn boards)
var buildings: Array = []
var camera_rect := Rect2i()
var marks: Dictionary = {}
var lamps: Array = []                # M12b: lamp tiles (glow at night)
var night := false
var sparkle := Vector2i(-1, -1)      # M12b: the fountain's tile, sparkling until it's gone           # M17 town changes: cell -> poster, flyer, smoke, cold, crater, banner          # M12 CameraBounds marker (empty = the whole zone)

var _ground: TileMapLayer
var _decor: TileMapLayer             # M12b decorations (never block)
var _objects: TileMapLayer
var _alts: Dictionary = {}           # roof tint name -> alternative tile id
var _overlay: Node2D
var _water: Array = []
var _labels: Array = []            # [{ "pos", "text", "color" }]
var _styles: Dictionary = {}
var _db: Dictionary = {}
var _cols: Dictionary = {}          # pack -> tileset columns


func build(db: Dictionary, id: String, interior: bool) -> void:
	_db = db
	map_id = id
	is_interior = interior
	_styles = db.get("town/styles", {})
	var ts := _tileset()
	_ground = TileMapLayer.new()
	_ground.tile_set = ts
	add_child(_ground)
	_decor = TileMapLayer.new()
	_decor.tile_set = ts
	add_child(_decor)
	_objects = TileMapLayer.new()
	_objects.tile_set = ts
	add_child(_objects)
	_overlay = Node2D.new()
	_overlay.z_index = 2
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	if interior:
		_build_interior(db.get("town/interiors", {}).get("interiors", []).filter(func(r: Variant) -> bool: return str(r.get("id", "")) == id)[0])
	elif ResourceLoader.exists(scene_path(id)):
		var inst := (load(scene_path(id)) as PackedScene).instantiate()
		_build_from_scene(ZoneReader.read(inst, TILE))
		inst.free()
	else:
		_build_zone(db.get("town/zones/" + id, {}))
	_overlay.queue_redraw()


static func scene_path(id: String) -> String:
	return ZONE_DIR + id + ".tscn"


## Build from a zone dictionary in the data format (the migration tool and
## blocks use this to stamp pieces).
func build_custom(db: Dictionary, zone: Dictionary) -> void:
	_db = db
	map_id = str(zone.get("id", "custom"))
	_styles = db.get("town/styles", {})
	var ts := _tileset()
	_ground = TileMapLayer.new()
	_ground.tile_set = ts
	add_child(_ground)
	_decor = TileMapLayer.new()
	_decor.tile_set = ts
	add_child(_decor)
	_objects = TileMapLayer.new()
	_objects.tile_set = ts
	add_child(_objects)
	_overlay = Node2D.new()
	_build_zone(zone)


## The stamped layers and data, for the migration tool.
func layers() -> Dictionary:
	return { "ground": _ground, "objects": _objects, "decor": _decor, "water": _water.duplicate(), "labels": _labels.duplicate() }


# --- Zone scenes (M12) ---------------------------------------------------------------

## Build from a zone scene read by ZoneReader: Ground and Objects tiles (Objects
## and Collision block, Water is drawn and blocks), doors with their buildings,
## spots, signs and exits.
func _build_from_scene(z: Dictionary) -> void:
	size = z["tiles"]
	for key in ["Ground", "Decor", "Objects"]:
		var layer := _ground if key == "Ground" else (_decor if key == "Decor" else _objects)
		for t in z[key]:
			layer.set_cell(t["cell"], int(t["source"]), t["atlas"], int(t.get("alt", 0)))
			if key == "Objects":
				_block(t["cell"])
	for t in z["Collision"]:
		_block(t["cell"])
	for t in z["Water"]:
		_water.append(t["cell"])
		_ground.erase_cell(t["cell"])
		_block(t["cell"])
	for d in z["doors"]:
		var r: Rect2i = d["rect"]
		var door: Vector2i = d["cell"]
		var loc := str(d["loc"])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_block(Vector2i(x, y))
		_block(door)
		doors[door] = { "loc": loc, "approach": door + Vector2i(0, 1) }
		door_by_loc[loc] = door
		buildings.append({ "loc": loc, "rect": r, "door": door })
		# Every building has a sign; houses get a nameplate with the location's name.
		var text := str(d["sign"]) if str(d["sign"]) != "" else str(Locs.rec(_db, loc).get("name", ""))
		if text != "":
			var row := r.end.y - 1 - (1 if r.size.y >= 5 else 0)
			_labels.append({ "pos": Vector2(r.position.x * TILE + 2, row * TILE + TILE / 2.0 + 4), "text": text, "color": Color("fff3c4") })
	for s in z["spots"]:
		spots[str(s["id"])] = s["cell"]
	for s in z["signs"]:
		if str(s["text"]) != "":
			signs[s["cell"]] = str(s["text"])
		if str(s["label"]) != "":
			var c: Vector2i = s["cell"]
			_labels.append({ "pos": Vector2(c.x * TILE - TILE * 0.75, c.y * TILE - 2), "text": str(s["label"]), "color": Color("c9c9c9") })
	for e in z["exits"]:
		exits.append({ "rect": e["rect"], "to": str(e["to"]), "spawn": e["spawn"] })
	if not z["bounds"].is_empty():
		camera_rect = z["bounds"][0]


func _tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var packs: Dictionary = _styles.get("packs", {})
	for key in ["town", "city", "floor"]:
		var src := TileSetAtlasSource.new()
		var tex := Assets.texture(str(packs.get(key, "")))
		src.texture = tex
		src.texture_region_size = Vector2i(TILE, TILE)
		var cols := tex.get_width() / TILE
		var rows := tex.get_height() / TILE
		_cols[key] = maxi(cols, 1)
		for r in rows:
			for c in cols:
				src.create_tile(Vector2i(c, r))
		ts.add_source(src, int(SRC[key]))
	_alts = TileTints.add(ts, _styles.get("roofTints", {}))
	return ts


func _put(layer: TileMapLayer, cell: Vector2i, pack: String, index: int, alt: int = 0) -> void:
	var cols := int(_cols.get(pack, 1))
	layer.set_cell(cell, int(SRC[pack]), Vector2i(index % cols, index / cols), alt)


func _block(cell: Vector2i) -> void:
	blocked[cell] = true


# --- Zones -------------------------------------------------------------------------

func _build_zone(z: Dictionary) -> void:
	var sz: Array = z.get("size", [60, 34])
	size = Vector2i(int(sz[0]), int(sz[1]))
	_fill(Rect2i(0, 0, size.x, size.y), str(z.get("ground", "grass")))
	for f in z.get("fills", []):
		_fill(_rect(f["rect"]), str(f["ground"]))
	var road: Dictionary = _styles.get("road", {})
	for r in z.get("roads", []):
		var x := int(r["x"])
		var y := int(r["y"])
		for i in int(r["len"]):
			if str(r["dir"]) == "h":
				_put(_ground, Vector2i(x + i, y), "city", int(road["h"][0]))
				_put(_ground, Vector2i(x + i, y + 1), "city", int(road["h"][1]))
			else:
				_put(_ground, Vector2i(x, y + i), "city", int(road["v"][0]))
				_put(_ground, Vector2i(x + 1, y + i), "city", int(road["v"][1]))
	for b in z.get("buildings", []):
		_stamp_building(b)
	for p in z.get("props", []):
		_prop(p)
	for key in z.get("spots", {}):
		var a: Array = z["spots"][key]
		spots[str(key)] = Vector2i(int(a[0]), int(a[1]))
	for e in z.get("exits", []):
		var sp: Array = e["spawn"]
		exits.append({ "rect": _rect(e["rect"]), "to": str(e["to"]), "spawn": Vector2i(int(sp[0]), int(sp[1])) })


func _rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


func _fill(r: Rect2i, ground: String) -> void:
	var g: Dictionary = _styles.get("ground", {}).get(ground, {})
	var tiles: Array = g.get("tiles", [0])
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var cell := Vector2i(x, y)
			if ground == "water":
				_water.append(cell)
				_ground.erase_cell(cell)
				_block(cell)
				continue
			var t := int(tiles[absi(x * 7 + y * 13 + (x * y) % 5) % tiles.size()])
			_put(_ground, cell, str(g.get("pack", "town")), t)
			if bool(g.get("blocked", false)):
				_block(cell)


## Stamp a building: roof rows, plain wall rows, then the base row with the door.
func _stamp_building(b: Dictionary) -> void:
	var r := _rect(b["rect"])
	var style: Dictionary = _styles.get("styles", {}).get(str(b.get("style", "house_red")), {})
	var pack := str(style.get("pack", "town"))
	var door_dx := int(b.get("door", r.size.x / 2))
	var wall_rows := 1 if r.size.y >= 5 else 0
	var roof_rows := maxi(1, r.size.y - 1 - wall_rows)
	var roof: Dictionary = style.get("roof", {})
	var tint := int(_alts.get(str(style.get("roofTint", "")), 0))
	for ry in roof_rows:
		var set_key := "top"
		if ry == roof_rows - 1 and roof_rows > 1:
			set_key = "bottom"
		elif ry > 0 and roof.has("mid"):
			set_key = "mid"
		var row: Array = roof.get(set_key, roof.get("top", [0, 0, 0]))
		for dx in r.size.x:
			var t := int(row[1])
			if dx == 0:
				t = int(row[0])
			elif dx == r.size.x - 1:
				t = int(row[2])
			if set_key == "bottom" and dx == door_dx and roof.has("gable"):
				t = int(roof["gable"])
			_put(_objects, r.position + Vector2i(dx, ry), pack, t, tint)
	var wall: Array = style.get("wall", [0, 0, 0])
	for wy in wall_rows:
		for dx in r.size.x:
			var t := int(wall[1])
			if dx == 0:
				t = int(wall[0])
			elif dx == r.size.x - 1:
				t = int(wall[2])
			elif style.has("wallWindow") and dx % 3 == 1:
				t = int(style["wallWindow"])
			_put(_objects, r.position + Vector2i(dx, roof_rows + wy), pack, t)
	var base: Dictionary = style.get("base", {})
	var by := r.end.y - 1
	var dbl: Array = base.get("doubleDoor", [])
	var win: Array = base.get("window", [])
	for dx in r.size.x:
		var t := int(base.get("mid", 0))
		if dx == 0:
			t = int(base.get("left", 0))
		elif dx == r.size.x - 1:
			t = int(base.get("right", 0))
		if win.size() == 2 and dx >= 1 and dx <= 2 and door_dx > 2:
			t = int(win[dx - 1])
		if dx == door_dx:
			t = int(dbl[0]) if dbl.size() == 2 else int(base.get("door", 0))
		elif dbl.size() == 2 and dx == door_dx + 1 and dx < r.size.x - 1:
			t = int(dbl[1])
		_put(_objects, Vector2i(r.position.x + dx, by), pack, t)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_block(Vector2i(x, y))
	var door := Vector2i(r.position.x + door_dx, by)
	var loc := str(b.get("loc", ""))
	doors[door] = { "loc": loc, "approach": door + Vector2i(0, 1) }
	door_by_loc[loc] = door
	buildings.append({ "loc": loc, "rect": r, "door": door })
	if b.has("label"):
		_labels.append({ "pos": Vector2(r.position.x * TILE + 2, (r.position.y + roof_rows) * TILE + TILE / 2.0 + 4), "text": str(b["label"]), "color": Color("fff3c4") })


func _prop(p: Dictionary) -> void:
	var kind := str(p.get("kind", ""))
	if p.has("rect"):
		var r := _rect(p["rect"])
		match kind:
			"trees":
				var step := int(p.get("step", 2))
				for y in range(r.position.y, r.end.y, step):
					for x in range(r.position.x + (y / step) % 2, r.end.x, step):
						if not blocked.has(Vector2i(x, y)):
							_tree(Vector2i(x, y))
			"fence", "chainfence":
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						var c := Vector2i(x, y)
						var fence: Dictionary = _styles.get("fence", {})
						if kind == "chainfence":
							var chain: Dictionary = _styles.get("chainfence", {})
							_put(_objects, c, str(chain.get("pack", "city")), int(chain.get("tile", 0)))
						elif r.size.y == 1:
							var part := "left" if x == r.position.x else ("right" if x == r.end.x - 1 else "mid")
							_put(_objects, c, str(fence.get("pack", "town")), int(fence.get(part, 0)))
						else:
							_put(_objects, c, str(fence.get("pack", "town")), int(fence.get("post", 0)))
						_block(c)
		return
	var a: Array = p.get("at", [0, 0])
	var cell := Vector2i(int(a[0]), int(a[1]))
	if kind == "tree":
		_tree(cell)
		return
	# Props are one or more tiles in a row (data/town/styles.json "props").
	var props: Dictionary = _styles.get("props", {})
	var prop: Dictionary = props.get(kind, props.get("default", {}))
	var tiles: Array = prop.get("tiles", [])
	for i in tiles.size():
		_put(_objects, cell + Vector2i(i, 0), str(prop.get("pack", "town")), int(tiles[i]))
		_block(cell + Vector2i(i, 0))
	if kind == "sign" and p.has("text"):
		signs[cell] = str(p["text"])
	if kind == "tower":
		_labels.append({ "pos": Vector2(cell.x * TILE - TILE * 0.75, cell.y * TILE - 2), "text": Strings.t("town_map.water_tower"), "color": Color("c9c9c9") })


func _tree(cell: Vector2i) -> void:
	var trees: Dictionary = _styles.get("trees", {})
	var options: Array = trees.get("tiles", [0])
	_put(_objects, cell, str(trees.get("pack", "town")), int(options[absi(cell.x * 3 + cell.y * 5) % options.size()]))
	_block(cell)


# --- Interiors ---------------------------------------------------------------------------

func _build_interior(t: Dictionary) -> void:
	var sz: Array = t.get("size", [12, 10])
	size = Vector2i(int(sz[0]), int(sz[1]))
	var wall_rows := int(t.get("wallRows", 2))
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var edge := y < wall_rows or x == 0 or x == size.x - 1 or y == size.y - 1
			_put(_ground, cell, "floor", int(t.get("wall", 266)) if edge else int(t.get("floor", 34)))
			if edge:
				_block(cell)
	interior_exit = Vector2i(size.x / 2, size.y - 1)
	blocked.erase(interior_exit)
	_put(_ground, interior_exit, "floor", int(t.get("floor", 34)))
	for f in t.get("furniture", []):
		var r := _rect(f["rect"])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				furniture[Vector2i(x, y)] = f
				_block(Vector2i(x, y))
	for key in t.get("spots", {}):
		var a: Array = t["spots"][key]
		spots[str(key)] = Vector2i(int(a[0]), int(a[1]))
	for d in t.get("doors", []):
		var a: Array = d["at"]
		room_doors[Vector2i(int(a[0]), int(a[1]))] = str(d["to"])


## NPC standing spots for this interior, in order.
func npc_spots() -> Array:
	var out: Array = []
	var t: Array = _db.get("town/interiors", {}).get("interiors", [])
	for r in t:
		if str(r.get("id", "")) == map_id:
			for a in r.get("npcSpots", []):
				out.append(Vector2i(int(a[0]), int(a[1])))
	return out


func walkable(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y and not blocked.has(cell)


func refresh_overlay() -> void:
	_overlay.queue_redraw()


# --- Overlay ---------------------------------------------------------------------------

const FURN_COLORS := { "counter": "#8a5a3a", "table": "#9c7a52", "bed": "#6d8fbf", "workbench": "#a0703c", "shelf": "#6b4a2a",
	"fridge": "#c9e3ef", "forge": "#c0502a", "anvil": "#4a4a55", "desk": "#7a5a3a", "machine": "#4a3a7a", "lockers": "#5a6a88",
	"board": "#2f4a3a", "labbench": "#6a7a8a", "hoop": "#d9773a", "bench": "#8a6a4a", "saw": "#888888", "cabinet": "#5a4a3a",
	"easel": "#b08a5a", "closet": "#6a5a4a", "door_locked": "#3a2a2a" }


## M12b: find the lamp tiles on the Objects layer (by their atlas tile).
func find_lamps() -> void:
	lamps.clear()
	var lamp: Dictionary = _styles.get("props", {}).get("lamp", {})
	var pack := str(lamp.get("pack", "city"))
	var cols := int(_cols.get(pack, 1))
	var wanted := {}
	for t in lamp.get("tiles", []):
		wanted[Vector2i(int(t) % cols, int(t) / cols)] = true
	for c in _objects.get_used_cells():
		if _objects.get_cell_source_id(c) == int(SRC[pack]) and wanted.has(_objects.get_cell_atlas_coords(c)):
			lamps.append(c)


## A texture for one atlas tile (cars driving by use the car tiles).
func tile_texture(pack: String, index: int) -> AtlasTexture:
	var src := _ground.tile_set.get_source(int(SRC[pack])) as TileSetAtlasSource
	var cols := int(_cols.get(pack, 1))
	var at := AtlasTexture.new()
	at.atlas = src.texture
	at.region = Rect2(Vector2((index % cols) * TILE, (index / cols) * TILE), Vector2(TILE, TILE))
	return at


## Road rows (horizontal road tiles) for traffic.
func road_rows() -> Array:
	var road: Dictionary = _styles.get("road", {})
	var cols := int(_cols.get("city", 1))
	var h0 := int(road.get("h", [0])[0])
	var want := Vector2i(h0 % cols, h0 / cols)
	var count := {}
	for c in _ground.get_used_cells():
		if _ground.get_cell_source_id(c) == int(SRC["city"]) and _ground.get_cell_atlas_coords(c) == want:
			count[c.y] = int(count.get(c.y, 0)) + 1
	var rows: Array = []
	for y in count:
		if int(count[y]) >= size.x / 2:
			rows.append(int(y))
	rows.sort()
	return rows


func _draw_overlay() -> void:
	var font: Font = UiTheme.font
	var d := Display.detail
	var t := Time.get_ticks_msec() / 1000.0
	for c in _water:
		var shade := 0.06 * sin(t * 1.5 + float(c.x + c.y))
		_overlay.draw_rect(Rect2(c * TILE, Vector2(TILE, TILE)), Color(0.24 + shade, 0.45 + shade, 0.75, 1.0))
	for cell in furniture:
		var f: Dictionary = furniture[cell]
		var col := Color(str(FURN_COLORS.get(str(f.get("kind", "")), "#7a6a5a")))
		var o := Vector2(cell * TILE) + Vector2(1, 2) * d
		_overlay.draw_rect(Rect2(o, Vector2(TILE - 2 * d, TILE - 3 * d)), col)
		_overlay.draw_rect(Rect2(o, Vector2(TILE - 2 * d, 3 * d)), col.lightened(0.2))
	for cell in furniture:
		var f: Dictionary = furniture[cell]
		var r := _rect(f["rect"])
		if f.has("label") and cell == r.position:
			_overlay.draw_string(font, Vector2(r.position.x * TILE, r.position.y * TILE - 1), str(f["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color("fff3c4"))
	for cell in room_doors:
		var loc := str(room_doors[cell])
		var st := str(shut.get(loc, ""))
		_overlay.draw_rect(Rect2(Vector2(cell * TILE) + Vector2(3, 2) * d, Vector2(10, 14) * d), Color("5a3a22"))
		if st != "":
			_draw_boards(cell)
	for b in buildings:
		var loc := str(b["loc"])
		var door: Vector2i = b["door"]
		if lit.has(loc):
			var r: Rect2i = b["rect"]
			for dx in r.size.x:
				if r.position.x + dx != door.x and dx % 2 == 0:
					_overlay.draw_rect(Rect2(Vector2((r.position.x + dx) * TILE, (r.end.y - 1) * TILE) + Vector2(4, 4) * d, Vector2(8, 6) * d), Color(1.0, 0.85, 0.4, 0.45))
		if shut.has(loc):
			_draw_boards(door)
	for c in marks:
		_draw_mark(c, str(marks[c]), t)
	var life: Dictionary = _styles.get("life", {})
	if night:
		var glow := Color(str(life.get("lampGlow", "#ffd27a")))
		for c in lamps:
			var flicker := 0.85 + 0.15 * sin(t * 7.0 + float(c.x * 3 + c.y))
			var center := Vector2(c * TILE) + Vector2(TILE / 2.0, TILE * 0.3)
			_overlay.draw_circle(center, TILE * float(life.get("lampRadius", 1.6)), Color(glow, 0.2 * flicker))
			_overlay.draw_circle(center, TILE * 0.6, Color(glow, 0.4 * flicker))
	if sparkle.x >= 0:
		for i in 4:
			var a := t * 2.0 + float(i) * TAU / 4.0
			var p := Vector2(sparkle * TILE) + Vector2(TILE / 2.0, TILE / 2.0) + Vector2(cos(a), sin(a) * 0.5) * TILE * 0.6
			_overlay.draw_circle(p, Display.detail * (1.0 + 0.5 * sin(t * 5.0 + float(i))), Color(0.75, 0.9, 1.0, 0.8))
	for l in _labels:
		var p: Vector2 = l["pos"]
		_overlay.draw_string(font, p + Vector2(1, 1), str(l["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color(0, 0, 0, 0.7))
		_overlay.draw_string(font, p, str(l["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, l["color"])


## M17: a town change on a tile.
func _draw_mark(c: Vector2i, kind: String, t: float) -> void:
	var o := Vector2(c * TILE)
	var d := Display.detail
	match kind:
		"poster":
			_overlay.draw_rect(Rect2(o + Vector2(3, 2) * d, Vector2(10, 12) * d), Color("f4e3b5"))
			_overlay.draw_rect(Rect2(o + Vector2(4, 4) * d, Vector2(8, 3) * d), Color("c0392b"))
		"flyer":
			_overlay.draw_rect(Rect2(o + Vector2(4, 3) * d, Vector2(8, 10) * d), Color("ffffff"))
			_overlay.draw_rect(Rect2(o + Vector2(5, 5) * d, Vector2(6, 4) * d), Color("555555"))
		"banner":
			_overlay.draw_rect(Rect2(o + Vector2(0, 3) * d, Vector2(TILE, 5 * d)), Color("2e86de"))
		"smoke":
			for i in 3:
				var rise := fmod(t * 6.0 + float(i) * 5.0, 15.0)
				_overlay.draw_circle(o + Vector2(8, 12 - rise) * d, (2.0 + rise * 0.2) * d, Color(0.75, 0.75, 0.75, 0.6 - rise * 0.035))
		"cold":
			_overlay.draw_rect(Rect2(o, Vector2(TILE, TILE)), Color(0.2, 0.25, 0.4, 0.35))
		"crater":
			_overlay.draw_circle(o + Vector2(TILE, TILE) / 2.0, TILE * 0.9, Color("2a2a33"))
			_overlay.draw_circle(o + Vector2(TILE, TILE) / 2.0, TILE * 0.6, Color(0.24, 0.45, 0.75, 0.9 + 0.05 * sin(t)))


## Boarded-up door: two planks and a CLOSED tag. Never an invisible wall.
func _draw_boards(cell: Vector2i) -> void:
	var o := Vector2(cell * TILE)
	var d := Display.detail
	_overlay.draw_line(o + Vector2(1, 3) * d, o + Vector2(TILE - d, 13 * d), Color("8a6a3a"), 3.0 * d)
	_overlay.draw_line(o + Vector2(TILE - d, 3 * d), o + Vector2(1, 13) * d, Color("6a4a2a"), 3.0 * d)
	_overlay.draw_rect(Rect2(o + Vector2(2, -6) * d, Vector2(12, 5) * d), Color("b03a2a"))

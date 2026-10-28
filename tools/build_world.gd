## M12 migration: turns the data-built town (data/town/zones/*.json) into
## editor scenes, and writes the block library.
##   --phase=1  save the scaled tile atlases to assets/tiles/world/ (then run
##              Godot with --import once so the editor can use them)
##   --phase=2  write src/world/world_tileset.tres, src/world/zones/<id>.tscn
##              and src/world/blocks/*.tscn
## Run: Godot_console.exe --headless --path . -s res://tools/build_world.gd -- --phase=N
## Zone scenes keep every tile, location, spot, sign and exit. Re-running
## phase 2 overwrites the zone scenes, so only do it before hand-editing them.
extends SceneTree

const ATLAS_DIR := "res://assets/tiles/world/"
const KEYS := ["town", "city", "floor"]
const SRC := { "town": 0, "city": 1, "floor": 2 }
const ZONES := ["downtown", "residential", "outskirts", "school"]
const M := "res://src/world/markers/"

var db: Dictionary
var tile := 0
var ts: TileSet


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	db = root.get_node("DataDB").call("all")
	tile = int(root.get_node("Display").get("tile"))
	var phase := "2"
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--phase="):
			phase = str(a).trim_prefix("--phase=")
	if phase == "1":
		_save_atlases()
	else:
		ts = _tileset()
		ResourceSaver.save(ts, "res://src/world/world_tileset.tres")
		ts = load("res://src/world/world_tileset.tres")
		for id in ZONES:
			_save(_zone_scene(id), "res://src/world/zones/%s.tscn" % id)
		_blocks()
	quit(0)


func _save_atlases() -> void:
	DirAccess.make_dir_recursive_absolute(ATLAS_DIR)
	var packs: Dictionary = db.get("town/styles", {}).get("packs", {})
	for key in KEYS:
		var img: Image = root.get_node("Assets").call("image", str(packs.get(key, "")))
		img.save_png(ProjectSettings.globalize_path(ATLAS_DIR + key + ".png"))
		print("saved %s%s.png" % [ATLAS_DIR, key])


## The editor's TileSet: the same sources and atlas coords the game builds at
## runtime from asset ids (the game swaps in its own, so custom art still applies).
func _tileset() -> TileSet:
	var t := TileSet.new()
	t.tile_size = Vector2i(tile, tile)
	for key in KEYS:
		var src := TileSetAtlasSource.new()
		var tex: Texture2D = load(ATLAS_DIR + key + ".png")
		src.texture = tex
		src.texture_region_size = Vector2i(tile, tile)
		for r in tex.get_height() / tile:
			for c in tex.get_width() / tile:
				src.create_tile(Vector2i(c, r))
		t.add_source(src, int(SRC[key]))
	return t


func _save(n: Node, path: String) -> void:
	_own(n, n)
	var ps := PackedScene.new()
	ps.pack(n)
	ResourceSaver.save(ps, path)
	print("saved " + path)
	n.free()


func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		_own(c, owner_node)


func _layer(name: String) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = name
	l.tile_set = ts
	return l


func _marker(script_name: String, node_name: String, cell: Vector2i, props: Dictionary) -> Node2D:
	var n := Node2D.new()
	n.set_script(load(M + script_name))
	n.name = node_name
	n.position = Vector2(cell * tile)
	for k in props:
		n.set(k, props[k])
	return n


## Stamp a zone dictionary with the town map builder and copy its layers.
func _stamp(zone: Dictionary) -> Dictionary:
	var m: Node2D = (load("res://src/scenes/town/town_map.gd") as GDScript).new()
	m.call("build_custom", db, zone)
	var ly: Dictionary = m.call("layers")
	var out := { "ground": _copy(ly["ground"], "Ground"), "objects": _copy(ly["objects"], "Objects"), "water": ly["water"],
		"blocked": m.get("blocked"), "buildings": m.get("buildings"), "spots": m.get("spots"), "signs": m.get("signs"), "exits": m.get("exits") }
	m.free()
	return out


func _copy(src: TileMapLayer, name: String) -> TileMapLayer:
	var l := _layer(name)
	for c in src.get_used_cells():
		l.set_cell(c, src.get_cell_source_id(c), src.get_cell_atlas_coords(c))
	return l


func _zone_scene(id: String) -> Node2D:
	var z: Dictionary = db.get("town/zones/" + id, {})
	var s := _stamp(z)
	var root_node := Node2D.new()
	root_node.set_script(load("res://src/world/zone_root.gd"))
	root_node.name = id.capitalize().replace(" ", "")
	root_node.set("zone_id", id)
	var sz: Array = z.get("size", [60, 34])
	root_node.set("tiles", Vector2i(int(sz[0]), int(sz[1])))
	var ground: TileMapLayer = s["ground"]
	var objects: TileMapLayer = s["objects"]
	root_node.add_child(ground)
	root_node.add_child(objects)
	# Collision: blocked tiles that have no object tile and aren't water.
	var col := _layer("Collision")
	col.modulate = Color(1, 0.3, 0.3, 0.5)
	var water := _layer("Water")
	water.modulate = Color(0.4, 0.6, 1.0, 0.8)
	for c in s["water"]:
		water.set_cell(c, int(SRC["floor"]), Vector2i.ZERO)
	for c in s["blocked"]:
		if objects.get_cell_source_id(c) == -1 and not s["water"].has(c):
			col.set_cell(c, int(SRC["floor"]), Vector2i.ZERO)
	root_node.add_child(col)
	root_node.add_child(water)
	var blocks := Node2D.new()
	blocks.name = "Blocks"
	root_node.add_child(blocks)
	var markers := Node2D.new()
	markers.name = "Markers"
	root_node.add_child(markers)
	var labels := {}
	for b in z.get("buildings", []):
		labels[str(b.get("loc", ""))] = str(b.get("label", ""))
	for b in s["buildings"]:
		var r: Rect2i = b["rect"]
		var door: Vector2i = b["door"]
		var loc := str(b["loc"])
		markers.add_child(_marker("door_marker.gd", "Door_" + loc, door, { "loc": loc, "sign_text": labels.get(loc, ""), "building": Rect2i(r.position - door, r.size) }))
	for loc in s["spots"]:
		markers.add_child(_marker("npc_spot.gd", "Spot_" + str(loc), s["spots"][loc], { "spot_id": str(loc) }))
	var i := 0
	for c in s["signs"]:
		i += 1
		markers.add_child(_marker("interactable.gd", "Sign%d" % i, c, { "says": str(s["signs"][c]) }))
	for p in z.get("props", []):
		if str(p.get("kind", "")) == "tower":
			var a: Array = p["at"]
			markers.add_child(_marker("interactable.gd", "WaterTower", Vector2i(int(a[0]), int(a[1])), { "map_label": str(root.get_node("Strings").call("t", "town_map.water_tower")) }))
	for e in s["exits"]:
		var r: Rect2i = e["rect"]
		markers.add_child(_marker("zone_exit.gd", "Exit_" + str(e["to"]), r.position, { "to": str(e["to"]), "tiles": r.size, "spawn": e["spawn"] }))
	# Spawn points: a tile, or a location id (in front of its door).
	for k in z.get("starts", {}):
		var v: Variant = z["starts"][k]
		var at := Vector2i(-1, -1)
		if v is Array:
			at = Vector2i(int(v[0]), int(v[1]))
		else:
			for b in s["buildings"]:
				if str(b["loc"]) == str(v):
					at = Vector2i(b["door"]) + Vector2i(0, 1)
		if at.x >= 0:
			markers.add_child(_marker("spawn_point.gd", "Spawn_" + str(k), at, { "spawn_id": str(k) }))
	return root_node


## The block library: one lot per building style, road pieces, a park, a
## fence row and small props. Each is a scene to drop into a zone's Blocks node.
func _blocks() -> void:
	var styles: Dictionary = db.get("town/styles", {}).get("styles", {})
	for st in styles:
		var shop := str(st).begins_with("shop") or str(st) in ["civic", "hospital", "school"]
		_block("lot_" + str(st), { "size": [7, 7], "ground": "concrete" if shop else "grass",
			"fills": [] if shop else [{ "ground": "path", "rect": [3, 6, 1, 1] }],
			"buildings": [{ "loc": "", "rect": [1, 1, 5, 5], "style": str(st), "door": 2 }] })
	_block("road_horizontal", { "size": [8, 2], "ground": "concrete", "roads": [{ "dir": "h", "x": 0, "y": 0, "len": 8 }] })
	_block("road_vertical", { "size": [2, 8], "ground": "concrete", "roads": [{ "dir": "v", "x": 0, "y": 0, "len": 8 }] })
	_block("road_crossing", { "size": [8, 8], "ground": "concrete", "roads": [{ "dir": "h", "x": 0, "y": 3, "len": 8 }, { "dir": "v", "x": 3, "y": 0, "len": 8 }] })
	_block("park", { "size": [8, 6], "ground": "grass", "fills": [{ "ground": "path", "rect": [0, 2, 8, 2] }],
		"props": [{ "kind": "trees", "rect": [0, 0, 8, 2], "step": 2 }, { "kind": "bench", "at": [2, 4] }, { "kind": "lamp", "at": [5, 4] }] })
	_block("fence_row", { "size": [6, 1], "ground": "grass", "props": [{ "kind": "fence", "rect": [0, 0, 6, 1] }] })
	_block("props_street", { "size": [6, 1], "ground": "concrete", "props": [{ "kind": "lamp", "at": [0, 0] }, { "kind": "bench", "at": [1, 0] }, { "kind": "bin", "at": [3, 0] }, { "kind": "hydrant", "at": [4, 0] }, { "kind": "planter", "at": [5, 0] }] })
	_block("props_yard", { "size": [4, 1], "ground": "grass", "props": [{ "kind": "tree", "at": [0, 0] }, { "kind": "mailbox", "at": [2, 0] }] })


func _block(name: String, zone: Dictionary) -> void:
	zone["id"] = name
	var s := _stamp(zone)
	var n := Node2D.new()
	n.name = name.capitalize().replace(" ", "")
	n.add_child(s["ground"])
	n.add_child(s["objects"])
	for b in s["buildings"]:
		var r: Rect2i = b["rect"]
		var door: Vector2i = b["door"]
		n.add_child(_marker("door_marker.gd", "Door", door, { "loc": "", "building": Rect2i(r.position - door, r.size) }))
	_save(n, "res://src/world/blocks/%s.tscn" % name)

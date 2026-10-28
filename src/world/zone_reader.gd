## Reads a zone scene (ROADMAP M12) into plain data: tile cells per layer and
## markers by kind, with blocks flattened into zone tiles. Used by TownMap to
## build the town and by the tests to validate maps. No autoloads: the tile
## size is passed in.
extends RefCounted

const LAYERS := ["Ground", "Objects", "Collision", "Water"]


static func read(root: Node, tile: int) -> Dictionary:
	var out := { "zone": str(root.get("zone_id")) if root.get("zone_id") != null else "", "tiles": root.get("tiles") if root.get("tiles") != null else Vector2i.ZERO,
		"Ground": [], "Objects": [], "Collision": [], "Water": [],
		"doors": [], "spots": [], "signs": [], "exits": [], "spawns": [], "bounds": [] }
	_walk(root, Vector2.ZERO, tile, out, true)
	return out


## Pixel offset of a node from the root, summed along its parents (works
## before the scene is in the tree).
static func _cell(offset: Vector2, tile: int) -> Vector2i:
	return Vector2i(roundi(offset.x / float(tile)), roundi(offset.y / float(tile)))


static func _walk(n: Node, offset: Vector2, tile: int, out: Dictionary, is_root: bool) -> void:
	var here := offset
	if n is Node2D and not is_root:
		here += (n as Node2D).position
	if n is TileMapLayer and LAYERS.has(str(n.name)):
		var layer: TileMapLayer = n
		var base := _cell(here, tile)
		var list: Array = out[str(n.name)]
		for c in layer.get_used_cells():
			list.append({ "cell": base + c, "source": layer.get_cell_source_id(c), "atlas": layer.get_cell_atlas_coords(c) })
	var s: Script = n.get_script()
	var path := s.resource_path if s != null else ""
	var cell := _cell(here, tile)
	match path.get_file():
		"door_marker.gd":
			var r: Rect2i = n.get("building")
			out["doors"].append({ "cell": cell, "loc": str(n.get("loc")), "sign": str(n.get("sign_text")), "rect": Rect2i(cell + r.position, r.size) })
		"npc_spot.gd":
			out["spots"].append({ "cell": cell, "id": str(n.get("spot_id")), "tags": Array(n.get("tags")) })
		"interactable.gd":
			out["signs"].append({ "cell": cell, "text": str(n.get("says")), "label": str(n.get("map_label")) })
		"zone_exit.gd":
			out["exits"].append({ "rect": Rect2i(cell, n.get("tiles")), "to": str(n.get("to")), "spawn": n.get("spawn") })
		"spawn_point.gd":
			out["spawns"].append({ "cell": cell, "id": str(n.get("spawn_id")) })
		"camera_bounds.gd":
			out["bounds"].append(Rect2i(cell, n.get("tiles")))
	for c in n.get_children():
		_walk(c, here, tile, out, false)

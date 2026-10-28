## M12: zone scenes built in the editor, markers and the map validation.
extends "res://tests/suite.gd"

const Reader := preload("res://src/world/zone_reader.gd")
const MapCheck := preload("res://src/core/town/map_check.gd")
const ZONES := ["downtown", "residential", "outskirts", "school"]


func _zones() -> Dictionary:
	var out := {}
	var tile := int(db()["display"]["tileSize"])
	for id in ZONES:
		var ps: PackedScene = load("res://src/world/zones/%s.tscn" % id)
		var inst := ps.instantiate()
		out[id] = Reader.read(inst, tile)
		inst.free()
	return out


func test_zone_scenes() -> void:
	var zones := _zones()
	for id in ZONES:
		var z: Dictionary = zones[id]
		check(str(z["zone"]) == id and z["Ground"].size() > 100, "%s scene has ground tiles (%d)" % [id, z["Ground"].size()])
		check(not z["exits"].is_empty(), "%s has exits" % id)
	check(zones["downtown"]["doors"].any(func(d: Dictionary) -> bool: return d["loc"] == "garys_deli"), "Gary's Deli has a door marker")


func test_maps_validate() -> void:
	var probs := MapCheck.problems(db(), _zones())
	check(probs.is_empty(), "every location, home and exit checks out: %s" % str(probs))


func test_validation_catches_mistakes() -> void:
	var zones := _zones()
	zones["downtown"]["doors"] = zones["downtown"]["doors"].filter(func(d: Dictionary) -> bool: return d["loc"] != "garys_deli")
	zones["downtown"]["exits"].append({ "rect": Rect2i(0, 0, 1, 1), "to": "moon", "spawn": Vector2i.ZERO })
	var probs := MapCheck.problems(db(), zones)
	check(probs.any(func(p: String) -> bool: return p.contains("garys_deli")), "a missing door is caught")
	check(probs.any(func(p: String) -> bool: return p.contains("moon")), "an exit to nowhere is caught")


func test_blocks() -> void:
	var tile := int(db()["display"]["tileSize"])
	var houses := 0
	for f in DirAccess.get_files_at("res://src/world/blocks"):
		if not f.ends_with(".tscn"):
			continue
		var inst := (load("res://src/world/blocks/" + f) as PackedScene).instantiate()
		var b := Reader.read(inst, tile)
		inst.free()
		check(b["Ground"].size() > 0, "block %s has tiles" % f)
		if f.begins_with("lot_house") or f.begins_with("lot_stone"):
			houses += 1
			check(b["doors"].size() == 1, "house lot %s has a door marker" % f)
	check(houses >= 4, "at least 4 house styles (%d)" % houses)


## M12b: the decorator is seeded, stays off blocked and kept-clear tiles.
func test_decorator() -> void:
	const Decor := preload("res://src/core/world/decor.gd")
	var rules: Dictionary = db()["world/decor_rules"]
	var grounds := {}
	for y in 20:
		for x in 20:
			grounds[Vector2i(x, y)] = "grass"
	var blocked := { Vector2i(5, 5): true }
	var clear := { Vector2i(10, 10): true }
	var a := Decor.scatter(rules, grounds, blocked, clear, seeded(3))
	var b := Decor.scatter(rules, grounds, blocked, clear, seeded(3))
	check(a == b and not a.is_empty(), "the decorator is seeded (%d decorations)" % a.size())
	check(not a.any(func(d: Dictionary) -> bool: return d["cell"] == Vector2i(5, 5) or maxi(absi(d["cell"].x - 10), absi(d["cell"].y - 10)) <= 1), "never on blocked tiles or next to doors")


func test_zone_decor_and_styles() -> void:
	var zones := _zones()
	check(not zones["residential"]["Decor"].is_empty(), "residential has decorations")
	var styles: Dictionary = db()["town/styles"]["styles"]
	var houses := styles.keys().filter(func(k: String) -> bool: return k.begins_with("house") or k.begins_with("stone"))
	check(houses.size() >= 6, "at least 6 house styles (%d)" % houses.size())
	# Neighbours on a street never share a style.
	var rows := {}
	for bld in db()["town/zones/residential"]["buildings"]:
		var y := int(bld["rect"][1])
		if not rows.has(y):
			rows[y] = []
		rows[y].append(bld)
	var same := 0
	for y in rows:
		var row: Array = rows[y]
		row.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p["rect"][0]) < int(q["rect"][0]))
		for i in range(1, row.size()):
			if row[i]["style"] == row[i - 1]["style"]:
				same += 1
	check(same == 0, "no two neighbouring houses look the same (%d pairs match)" % same)
	var tints: Dictionary = db()["display"]["dayTint"]
	for part in ["before_school", "after_school", "evening", "night"]:
		check(tints.has(part), "a light for %s" % part)


func test_roof_tints() -> void:
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(32, 32)
	src.create_tile(Vector2i(0, 0))
	src.create_tile(Vector2i(1, 0))
	ts.add_source(src, 0)
	var alts: Dictionary = preload("res://src/world/tile_tints.gd").add(ts, db()["town/styles"]["roofTints"])
	check(alts.size() == 4 and src.get_alternative_tiles_count(Vector2i(1, 0)) == 5, "each tile gets a tinted alternative per roof tint")

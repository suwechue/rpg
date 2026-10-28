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

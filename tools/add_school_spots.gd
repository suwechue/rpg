## M13 one-off: adds NpcSpot markers for the bleachers and the back stairs to
## src/world/zones/school.tscn, on free tiles near the field and the school.
## Run: Godot_console.exe --headless --path . -s res://tools/add_school_spots.gd
extends SceneTree

const PATH := "res://src/world/zones/school.tscn"


func _initialize() -> void:
	var tile := int((JSON.parse_string(FileAccess.get_file_as_string("res://data/display.json")) as Dictionary)["tileSize"])
	var root_node := (load(PATH) as PackedScene).instantiate()
	var z: Dictionary = (load("res://src/world/zone_reader.gd") as GDScript).call("read", root_node, tile)
	var blocked: Dictionary = (load("res://src/core/town/map_check.gd") as GDScript).call("blocked", z)
	var field := Vector2i(30, 25)
	var steps := Vector2i(30, 12)
	for s in z["spots"]:
		if s["id"] == "field":
			field = s["cell"]
		if s["id"] == "front_steps":
			steps = s["cell"]
	var markers := root_node.get_node("Markers")
	for want in [["bleachers", field + Vector2i(-4, -2), ["bench", "crowd"]], ["back_stairs", steps + Vector2i(8, 0), ["nap"]]]:
		if markers.has_node("Spot_" + str(want[0])):
			continue
		var cell := _free_near(want[1], blocked, z["tiles"])
		var n := Node2D.new()
		n.set_script(load("res://src/world/markers/npc_spot.gd"))
		n.name = "Spot_" + str(want[0])
		n.position = Vector2(cell * tile)
		n.set("spot_id", str(want[0]))
		n.set("tags", PackedStringArray(want[2]))
		markers.add_child(n)
		n.owner = root_node
		blocked[cell] = true
		print("added %s at %s" % [want[0], cell])
	var ps := PackedScene.new()
	ps.pack(root_node)
	ResourceSaver.save(ps, PATH)
	root_node.free()
	quit(0)


func _free_near(c: Vector2i, blocked: Dictionary, size: Vector2i) -> Vector2i:
	for r in range(0, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p := c + Vector2i(dx, dy)
				if p.x >= 1 and p.y >= 1 and p.x < size.x - 1 and p.y < size.y - 1 and not blocked.has(p):
					return p
	return c

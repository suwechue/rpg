## Writes docs/ASSETS.md from data/assets/manifest.json (every asset id with
## its target size, layout and whether assets/custom/ already replaces it).
## Run: godot --headless --path . -s res://tools/gen_assets_doc.gd
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const Spec := preload("res://src/core/assets/asset_specs.gd")
const Doc := preload("res://src/core/assets/asset_doc.gd")


func _initialize() -> void:
	var db := DT.tables("res://data")
	var root := str(Spec.manifest(db).get("customRoot", "res://assets/custom"))
	var custom := {}
	var all: Dictionary = Spec.manifest(db).get("assets", {})
	for id in all:
		for p in Spec.custom_candidates(root, all[id], str(id)):
			if FileAccess.file_exists(str(p)):
				custom[str(id)] = str(p)
				break
	var f := FileAccess.open("res://docs/ASSETS.md", FileAccess.WRITE)
	f.store_string(Doc.render(db, custom))
	f.close()
	print("docs/ASSETS.md: %d assets, %d replaced" % [all.size(), custom.size()])
	quit(0)

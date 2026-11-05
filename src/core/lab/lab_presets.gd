## Presets the player saved from the Lab live in user://lab/presets.json and are
## merged over data/lab/presets.json when the data loads.
extends RefCounted

const UserPaths := preload("res://src/core/user_paths.gd")


static func path() -> String:
	return UserPaths.of("lab/") + "presets.json"


## Write the saved presets from a whole preset list.
static func save(list: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UserPaths.of("lab/")))
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({ "presets": list.filter(func(p: Dictionary) -> bool: return bool(p.get("saved", false))) }, "  "))


## Add saved presets to the loaded table.
static func merge_into(table: Dictionary) -> void:
	if not FileAccess.file_exists(path()):
		return
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path()))
	if typeof(saved) != TYPE_DICTIONARY:
		return
	var list: Array = table.get("presets", [])
	for p in saved.get("presets", []):
		list = list.filter(func(o: Dictionary) -> bool: return str(o.get("id", "")) != str(p.get("id", "")))
		list.append(p)
	table["presets"] = list

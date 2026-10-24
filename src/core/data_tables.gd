## Loads every JSON file under a folder into a Dictionary of tables keyed by
## relative path without extension ("calendar", "cards/starter_cards").
## Pure file I/O, no nodes: DataDB uses it at runtime and tests use it headless.
class_name DataTables
extends RefCounted


## Returns { "tables": {...}, "errors": [...] }.
static func load_all(root: String) -> Dictionary:
	var tables := {}
	var errors: Array = []
	_load_dir(root, "", tables, errors)
	return { "tables": tables, "errors": errors }


## Convenience for tests: just the tables.
static func tables(root: String = "res://data") -> Dictionary:
	return load_all(root)["tables"]


## Every record in `list_key` arrays across tables whose path starts with prefix.
static func records_under(tables_dict: Dictionary, prefix: String, list_key: String) -> Array:
	var out: Array = []
	var keys: Array = tables_dict.keys()
	keys.sort()
	for key in keys:
		if str(key).begins_with(prefix):
			var t: Variant = tables_dict[key]
			if typeof(t) == TYPE_DICTIONARY and typeof(t.get(list_key)) == TYPE_ARRAY:
				out.append_array(t[list_key])
	return out


## Find a record by id in any array value of one table.
static func record(tables_dict: Dictionary, table_key: String, id: String) -> Dictionary:
	var t: Variant = tables_dict.get(table_key, {})
	if typeof(t) != TYPE_DICTIONARY:
		return {}
	for key in t:
		var value: Variant = t[key]
		if typeof(value) == TYPE_ARRAY:
			for item in value:
				if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")) == id:
					return item
	return {}


## Build an id -> record index over records_under().
static func index_under(tables_dict: Dictionary, prefix: String, list_key: String) -> Dictionary:
	var out := {}
	for r in records_under(tables_dict, prefix, list_key):
		if typeof(r) == TYPE_DICTIONARY:
			out[str(r.get("id", ""))] = r
	return out


static func _load_dir(path: String, prefix: String, tables: Dictionary, errors: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		errors.append("cannot open %s" % path)
		return
	var files := Array(dir.get_files())
	files.sort()
	for file_name in files:
		if not str(file_name).ends_with(".json"):
			continue
		var full := path + "/" + str(file_name)
		var json := JSON.new()
		var err := json.parse(FileAccess.get_file_as_string(full))
		if err != OK:
			errors.append("%s line %d: %s" % [full, json.get_error_line(), json.get_error_message()])
			continue
		tables[prefix + str(file_name).get_basename()] = json.data
	var dirs := Array(dir.get_directories())
	dirs.sort()
	for sub in dirs:
		_load_dir(path + "/" + str(sub), prefix + str(sub) + "/", tables, errors)

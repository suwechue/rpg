## Loads every JSON file under res://data into tables keyed by relative path
## without extension ("calendar", "cards/starter_cards"), and validates them.
## Note for exports: add *.json to the export preset's "non-resource files" filter.
extends Node

const DATA_ROOT := "res://data"

var errors: Array[String] = []
var _tables: Dictionary = {}
var _loaded := false


func _ready() -> void:
	_ensure_loaded()


func reload() -> void:
	_tables.clear()
	errors.clear()
	_load_dir(DATA_ROOT, "")
	_loaded = true
	_validate()
	for e in errors:
		push_error("DataDB: " + e)
	print("DataDB: loaded %d tables, %d errors" % [_tables.size(), errors.size()])


func has_table(key: String) -> bool:
	_ensure_loaded()
	return _tables.has(key)


## The parsed JSON for a table, or `fallback` if it does not exist.
func table(key: String, fallback: Variant = {}) -> Variant:
	_ensure_loaded()
	return _tables.get(key, fallback)


## Find a record by id inside a table. Searches every array value in the table
## (for example "classes" in school_classes.json).
func record(table_key: String, id: String) -> Dictionary:
	var t: Variant = table(table_key)
	if typeof(t) != TYPE_DICTIONARY:
		return {}
	for key in t:
		var value: Variant = t[key]
		if typeof(value) == TYPE_ARRAY:
			for item in value:
				if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")) == id:
					return item
	return {}


## All records with this id key across tables whose path starts with prefix
## (for example every card in data/cards/).
func records_under(prefix: String, list_key: String) -> Array:
	_ensure_loaded()
	var out: Array = []
	for key in _tables:
		if str(key).begins_with(prefix):
			var t: Variant = _tables[key]
			if typeof(t) == TYPE_DICTIONARY and typeof(t.get(list_key)) == TYPE_ARRAY:
				out.append_array(t[list_key])
	return out


func _ensure_loaded() -> void:
	if not _loaded:
		reload()


func _load_dir(path: String, prefix: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		errors.append("cannot open %s" % path)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var full := path + "/" + file_name
		var json := JSON.new()
		var err := json.parse(FileAccess.get_file_as_string(full))
		if err != OK:
			errors.append("%s line %d: %s" % [full, json.get_error_line(), json.get_error_message()])
			continue
		_tables[prefix + file_name.get_basename()] = json.data
	for sub in dir.get_directories():
		_load_dir(path + "/" + sub, prefix + sub + "/")


## Minimal schema checks. Extend as new tables are added.
func _validate() -> void:
	for required in ["spaces", "matchups", "calendar", "vectors", "forms", "classes", "player_template"]:
		if not _tables.has(required):
			errors.append("missing required table data/%s.json" % required)
	if not (_tables.has("spaces") and _tables.has("forms") and _tables.has("vectors")):
		return
	var arcane: Array = _tables["spaces"].get("arcane", {}).get("axes", [])
	var forms := {}
	for f in _tables["forms"].get("forms", []):
		forms[f["id"]] = f
	var magnitudes: Dictionary = _tables["vectors"].get("magnitudes", {})
	var hybrid_extra := int(_tables["vectors"].get("hybridExtraCost", 1))
	for card in records_under("cards/", "cards"):
		var id := str(card.get("id", "?"))
		if str(card.get("kind", "")) != "spell":
			continue
		var vectors: Dictionary = card.get("vectors", {})
		for axis in vectors:
			if not arcane.has(axis):
				errors.append("card %s: unknown vector '%s'" % [id, axis])
		var form_id := str(card.get("form", ""))
		var mag_id := str(card.get("magnitude", ""))
		if not forms.has(form_id):
			errors.append("card %s: unknown form '%s'" % [id, form_id])
			continue
		if not magnitudes.has(mag_id):
			errors.append("card %s: unknown magnitude '%s'" % [id, mag_id])
			continue
		var expected := int(magnitudes[mag_id]["cost"]) + int(forms[form_id]["cost"])
		if vectors.size() > 1:
			expected += hybrid_extra
		if int(card.get("cost", -1)) != expected:
			errors.append("card %s: cost %s but rules say %d" % [id, str(card.get("cost")), expected])

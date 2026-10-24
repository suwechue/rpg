## Loads every JSON file under res://data into tables keyed by relative path
## without extension ("calendar", "cards/starter_cards"), and validates them.
## The loading itself is src/core/data_tables.gd, shared with the tests.
## Note for exports: add *.json to the export preset's "non-resource files" filter.
extends Node

const DT := preload("res://src/core/data_tables.gd")
const CardRules := preload("res://src/core/card.gd")
const DATA_ROOT := "res://data"

var errors: Array[String] = []
var _tables: Dictionary = {}
var _loaded := false


func _ready() -> void:
	_ensure_loaded()


func reload() -> void:
	var result := DT.load_all(DATA_ROOT)
	_tables = result["tables"]
	errors.clear()
	for e in result["errors"]:
		errors.append(str(e))
	_loaded = true
	_validate()
	for e in errors:
		push_error("DataDB: " + e)
	print("DataDB: loaded %d tables, %d errors" % [_tables.size(), errors.size()])


## Every table, for passing to src/core functions.
func all() -> Dictionary:
	_ensure_loaded()
	return _tables


func has_table(key: String) -> bool:
	_ensure_loaded()
	return _tables.has(key)


## The parsed JSON for a table, or `fallback` if it does not exist.
func table(key: String, fallback: Variant = {}) -> Variant:
	_ensure_loaded()
	return _tables.get(key, fallback)


## Find a record by id inside a table (searches every array value).
func record(table_key: String, id: String) -> Dictionary:
	_ensure_loaded()
	return DT.record(_tables, table_key, id)


## All records in `list_key` arrays across tables whose path starts with prefix.
func records_under(prefix: String, list_key: String) -> Array:
	_ensure_loaded()
	return DT.records_under(_tables, prefix, list_key)


func _ensure_loaded() -> void:
	if not _loaded:
		reload()


## Schema checks. Extend as new tables are added.
func _validate() -> void:
	for required in ["spaces", "matchups", "calendar", "vectors", "forms", "classes", "stats", "leveling", "perks", "traits"]:
		if not _tables.has(required):
			errors.append("missing required table data/%s.json" % required)
	if not (_tables.has("spaces") and _tables.has("forms") and _tables.has("vectors")):
		return
	var arcane: Array = _tables["spaces"].get("arcane", {}).get("axes", [])
	var stat_axes: Array = _tables["spaces"].get("stats", {}).get("axes", [])
	var form_axes: Array = _tables["spaces"].get("forms", {}).get("axes", [])
	_validate_cards(arcane)
	var perk_ids := {}
	for p in records_under("perks", "perks"):
		perk_ids[str(p.get("id"))] = true
	for cls in _tables.get("classes", {}).get("classes", []):
		var id := str(cls.get("id", "?"))
		for s in cls.get("growth", {}):
			if not stat_axes.has(s):
				errors.append("class %s: unknown growth stat '%s'" % [id, s])
		for v in cls.get("vectorAffinity", {}):
			if not arcane.has(v):
				errors.append("class %s: unknown Vector '%s'" % [id, v])
		for f in cls.get("formAffinity", {}):
			if not form_axes.has(f):
				errors.append("class %s: unknown Form '%s'" % [id, f])
		for f in cls.get("startForms", []):
			if not form_axes.has(f):
				errors.append("class %s: unknown start Form '%s'" % [id, f])
		for entry in cls.get("starterDeck", []):
			if entry.has("basic") and CardRules.resolve(_tables, str(entry["basic"])).is_empty():
				errors.append("class %s: unknown starter card '%s'" % [id, entry["basic"]])
	for t in records_under("traits", "traits"):
		for s in t.get("mods", {}).get("stats", {}):
			if not stat_axes.has(s):
				errors.append("trait %s: unknown stat '%s'" % [t.get("id"), s])


func _validate_cards(arcane: Array) -> void:
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
		if DT.record(_tables, "forms", form_id).is_empty():
			errors.append("card %s: unknown form '%s'" % [id, form_id])
			continue
		if not _tables["vectors"].get("magnitudes", {}).has(mag_id):
			errors.append("card %s: unknown magnitude '%s'" % [id, mag_id])
			continue
		var expected := CardRules.spell_cost(_tables, card)
		if int(card.get("cost", -1)) != expected:
			errors.append("card %s: cost %s but rules say %d" % [id, str(card.get("cost")), expected])

## Loads every JSON file under res://data into tables keyed by relative path
## without extension ("calendar", "cards/starter_cards"), and validates them.
## The loading itself is src/core/data_tables.gd, shared with the tests.
## Note for exports: add *.json to the export preset's "non-resource files" filter.
extends Node

const DT := preload("res://src/core/data_tables.gd")
const CardRules := preload("res://src/core/card.gd")
const AssetSpecs := preload("res://src/core/assets/asset_specs.gd")
const CardEffects := preload("res://src/core/combat/card_effects.gd")
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
	for required in ["spaces", "matchups", "calendar", "vectors", "forms", "classes", "stats", "leveling", "perks", "traits", "display", "assets/manifest", "assets/roles", "ui", "audio_events", "strings"]:
		if not _tables.has(required):
			errors.append("missing required table data/%s.json" % required)
	if not (_tables.has("spaces") and _tables.has("forms") and _tables.has("vectors")):
		return
	var arcane: Array = _tables["spaces"].get("arcane", {}).get("axes", [])
	var stat_axes: Array = _tables["spaces"].get("stats", {}).get("axes", [])
	var form_axes: Array = _tables["spaces"].get("forms", {}).get("axes", [])
	_validate_cards(arcane)
	_validate_card_effects()
	_validate_behaviors()
	_validate_assets()
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
	_validate_combat(arcane)
	_validate_forge()
	for c in records_under("cutscenes/", "cutscenes"):
		for msg in preload("res://src/core/story/cutscenes.gd").problems(_tables, c):
			errors.append(msg)
	_validate_events()
	_validate_town()
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


func _validate_combat(arcane: Array) -> void:
	var seen := {}
	for e in records_under("enemies/", "enemies"):
		var id := str(e.get("id", "?"))
		if seen.has(id):
			errors.append("enemy %s: duplicate id" % id)
		seen[id] = true
		for list_key in ["weakTo", "strongAgainst"]:
			for axis in e.get(list_key, []):
				if not arcane.has(axis):
					errors.append("enemy %s: unknown Vector '%s' in %s" % [id, axis, list_key])
		var actions: Array = e.get("actions", []).duplicate()
		for ph in e.get("phases", []):
			actions.append_array(ph.get("actions", []))
		for a in actions:
			if str(a.get("kind", "attack")) != "strike" and DT.record(_tables, "forms", str(a.get("form", "bolt"))).is_empty():
				errors.append("enemy %s action %s: unknown form '%s'" % [id, a.get("id"), a.get("form")])
			for axis in a.get("vectors", {}):
				if not arcane.has(axis):
					errors.append("enemy %s action %s: unknown Vector '%s'" % [id, a.get("id"), axis])
	for l in table("rooms/combat_layouts").get("layouts", []):
		var map: Array = l.get("map", [])
		for row in map:
			if str(row).length() != str(map[0]).length():
				errors.append("layout %s: rows have different lengths" % l.get("id"))
				break


const EFFECT_KEYS := ["statXp", "stats", "affinity", "grade", "gradeFor", "bond", "flag", "unflag", "hp", "mp", "money",
	"item", "card", "kellyRisk", "learnVector", "learnForm", "xp", "signature", "counter", "disposition", "narrate",
	"repeatClassGain", "bondPartner", "healInjuries", "sigHint", "ap", "narratorBond", "recruit", "topic", "rumor", "narratorBond", "goto", "combat", "journal", "classChange"]


## Every effects Dictionary in event tables must use known keys.
func _validate_effects(where: String, fx: Variant) -> void:
	if typeof(fx) != TYPE_DICTIONARY:
		return
	for k in fx:
		if not EFFECT_KEYS.has(str(k)):
			errors.append("%s: unknown effect '%s'" % [where, k])


func _validate_events() -> void:
	var class_ids := ["any"]
	for c in table("school_classes").get("classes", []):
		class_ids.append(str(c["id"]))
		if not table("school_classes").get("professors", {}).has(str(c.get("professor", ""))):
			errors.append("class %s: unknown professor '%s'" % [c["id"], c.get("professor")])
	for key in _tables:
		if str(key).begins_with("story/"):
			for st in _tables[key].get("stories", []):
				for step in st.get("steps", []):
					var ev: Dictionary = step.get("event", {})
					for ch in ev.get("choices", []):
						_validate_effects("%s/%s" % [key, st.get("id")], ch.get("effects", {}))
						if ch.has("misheard"):
							_validate_effects("%s/%s misheard" % [key, st.get("id")], ch["misheard"].get("effects", {}))
				for step in st.get("steps", []):
					if str(step.get("type", "")) == "combat":
						for e in step.get("enemies", []):
							if not _enemy_ids().has(str(e)):
								errors.append("%s/%s: unknown enemy '%s'" % [key, st.get("id"), e])
		if not str(key).begins_with("events/"):
			continue
		for e in _tables[key].get("events", []):
			var id := "%s/%s" % [key, e.get("id", "?")]
			if str(key) == "events/class_events" and not class_ids.has(str(e.get("class", "any"))):
				errors.append("%s: unknown class '%s'" % [id, e.get("class")])
			for fk in ["effects", "success", "fail"]:
				_validate_effects(id, e.get(fk, {}))
			for ch in e.get("choices", []):
				for fk in ["effects", "success", "fail"]:
					_validate_effects(id, ch.get(fk, {}))


## AR cards: known effect ops, targeting types, rarities and footprints.
func _validate_card_effects() -> void:
	var rarities := ["common", "uncommon", "rare"]
	for c in records_under("cards/", "cards"):
		var id := str(c.get("id", "?"))
		if c.has("rarity") and not rarities.has(str(c["rarity"])):
			errors.append("card %s: unknown rarity '%s'" % [id, c["rarity"]])
		for e in c.get("effects", []) + c.get("upgrade", {}).get("effects", []):
			if not CardEffects.OPS.has(str(e.get("op", ""))):
				errors.append("card %s: unknown effect op '%s'" % [id, e.get("op", "")])
		if c.has("targeting") and not CardEffects.TARGETING.has(str(c["targeting"].get("type", ""))):
			errors.append("card %s: unknown targeting '%s'" % [id, c["targeting"].get("type", "")])
		if str(c.get("kind", "")) == "spell" and DT.record(_tables, "forms", str(c.get("form", ""))).is_empty():
			errors.append("card %s: unknown form '%s'" % [id, c.get("form", "")])


## AR enemies: known behaviors, and summons and splits that exist.
func _validate_behaviors() -> void:
	var known := ["charger", "bomber", "healer", "summoner", "shield_bearer", "burrower", "sniper", "splitter", "hazard_maker", "mirror", "leech", "anchor"]
	var ids := _enemy_ids()
	for e in records_under("enemies/", "enemies"):
		if e.has("behavior") and not known.has(str(e["behavior"])):
			errors.append("enemy %s: unknown behavior '%s'" % [e.get("id"), e["behavior"]])
		for k in ["summons", "splitInto"]:
			if e.has(k) and not ids.has(str(e[k])):
				errors.append("enemy %s: %s '%s' is not an enemy" % [e.get("id"), k, e[k]])
		for a in e.get("affixes", []):
			if not table("enemy_affixes").get("affixes", {}).has(str(a)):
				errors.append("enemy %s: unknown affix '%s'" % [e.get("id"), a])


## Asset ids: the manifest is well formed, data only names listed ids, and
## every pack source file exists (missing art would show as a placeholder).
func _validate_assets() -> void:
	for e in AssetSpecs.validate(_tables):
		errors.append(str(e))
	var all: Dictionary = AssetSpecs.manifest(_tables).get("assets", {})
	for id in all:
		var src := str(all[id].get("source", ""))
		if src != "" and not bool(all[id].get("planned", false)) and not ResourceLoader.exists(src):
			errors.append("asset %s: source file missing: %s" % [id, src])


func _validate_town() -> void:
	var locs := {}
	for l in table("town/locations").get("locations", []):
		locs[str(l["id"])] = true
	for key in _tables:
		if str(key).begins_with("npcs/"):
			var n: Dictionary = _tables[key]
			if not locs.has(str(n.get("home", ""))):
				errors.append("%s: home '%s' is not a location" % [key, n.get("home")])
			if not n.has("sprite"):
				errors.append("%s: no sprite" % key)
		elif str(key).begins_with("town/zones/"):
			for b in _tables[key].get("buildings", []):
				if not locs.has(str(b.get("loc", ""))):
					errors.append("%s: building '%s' is not a location" % [key, b.get("loc")])
	for s in table("town/shops").get("shops", []):
		for e in s.get("entries", []):
			if str(e.get("type", "")) == "item" and record("items", str(e.get("item", ""))).is_empty():
				errors.append("shop %s: unknown item '%s'" % [s.get("id"), e.get("item")])


func _enemy_ids() -> Dictionary:
	var out := {}
	for e in records_under("enemies/", "enemies"):
		out[str(e["id"])] = true
	return out


## PT Part 5: riders have unique ids; exclusive pairs and rarities in the forge rules exist.
func _validate_forge() -> void:
	var ids := {}
	for r in _tables.get("riders", {}).get("riders", []):
		var id := str(r.get("id", ""))
		if ids.has(id):
			errors.append("riders: duplicate id '%s'" % id)
		ids[id] = true
	for pair in _tables.get("forge", {}).get("exclusiveRiders", []):
		for id in pair:
			if not ids.has(str(id)):
				errors.append("forge: exclusive rider '%s' is not in data/riders.json" % id)
	for rarity in _tables.get("forge", {}).get("riderSlots", {}):
		if not _tables.get("forge", {}).get("rarityOrder", []).has(rarity):
			errors.append("forge: riderSlots rarity '%s' is not in rarityOrder" % rarity)

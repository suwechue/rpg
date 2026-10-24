## The character model shared by the player, party members, NPCs and (partly)
## enemies. A character is a plain Dictionary (see DESIGN.md Section 5) so it
## saves as JSON; these static functions build it and read derived values.
## `db` is the tables Dictionary from DataTables / DataDB.
class_name Character
extends RefCounted

const VO := preload("res://src/core/vector_ops.gd")
const DT := preload("res://src/core/data_tables.gd")
const CardRules := preload("res://src/core/card.gd")

const DEFAULT_STATS := ["str", "dex", "con", "int", "per", "wil", "cha"]


static func class_data(db: Dictionary, class_id: String) -> Dictionary:
	return DT.record(db, "classes", class_id)


static func stat_order(db: Dictionary) -> Array:
	return db.get("stats", {}).get("order", DEFAULT_STATS)


static func arcane_axes(db: Dictionary) -> Array:
	return db.get("spaces", {}).get("arcane", {}).get("axes", [])


static func form_axes(db: Dictionary) -> Array:
	return db.get("spaces", {}).get("forms", {}).get("axes", [])


static func vector_tier(db: Dictionary, axis: String) -> int:
	return int(db.get("spaces", {}).get("arcane", {}).get("tiers", {}).get(axis, 1))


static func form_tier(db: Dictionary, form_id: String) -> int:
	return int(DT.record(db, "forms", form_id).get("tier", 1))


## Build a fresh character of a class.
## opts: id, name, stats, knownVectors, knownForms, traits, vectorAffinity, isPlayer
static func create(db: Dictionary, class_id: String, rng: RandomNumberGenerator, opts: Dictionary = {}) -> Dictionary:
	var cls := class_data(db, class_id)
	var stats: Dictionary = opts.get("stats", cls.get("startStats", {})).duplicate()
	for s in stat_order(db):
		stats[s] = int(stats.get(s, 3))
	var affinity: Dictionary = opts.get("vectorAffinity", cls.get("vectorAffinity", {})).duplicate()
	var known_vectors: Array = []
	if opts.has("knownVectors"):
		known_vectors = opts["knownVectors"].duplicate()
	else:
		known_vectors = _roll_start_vectors(db, cls, affinity, rng)
	var ch := {
		"id": str(opts.get("id", "player")),
		"name": str(opts.get("name", "New Kid")),
		"class": class_id,
		"classHistory": [class_id],
		"level": 1,
		"xp": 0,
		"stats": stats,
		"vectorAffinity": affinity,
		"formAffinity": cls.get("formAffinity", {}).duplicate(),
		"knownVectors": known_vectors,
		"knownForms": opts.get("knownForms", cls.get("startForms", [])).duplicate(),
		"knowledgeTier": 1,
		"resistances": opts.get("resistances", {}).duplicate(),
		"traits": opts.get("traits", []).duplicate(),
		"perks": [],
		"pendingPerks": [],
		"deck": [],
		"equipment": { "weapon": null, "armor": null, "trinket": null },
		"dryVectorRolls": 0,
		"dryFormRolls": 0,
		"pairUses": {},
		"wildSurges": 0,
		"flags": {},
		"isPlayer": bool(opts.get("isPlayer", false)),
	}
	ch["deck"] = starter_deck(db, ch)
	var d := derived(db, ch)
	ch["hp"] = int(d["maxHp"])
	ch["mp"] = int(d["maxMp"])
	return ch


## Forced class Vectors first, then Sample the rest without repeats from the
## Tier 1 part of the affinity table.
static func _roll_start_vectors(db: Dictionary, cls: Dictionary, affinity: Dictionary, rng: RandomNumberGenerator) -> Array:
	var known: Array = cls.get("forcedVectors", []).duplicate()
	var want := int(cls.get("startVectors", 1))
	var pool := {}
	for axis in affinity:
		if vector_tier(db, axis) <= 1 and not known.has(axis):
			pool[axis] = affinity[axis]
	var need := want - known.size()
	if need > 0:
		known.append_array(VO.sample_unique(pool, rng, need, arcane_axes(db)))
	return known


## The class starter deck as card ids. Spell slots use the character's known
## Vectors (slot index wraps around).
static func starter_deck(db: Dictionary, ch: Dictionary) -> Array:
	var cls := class_data(db, str(ch.get("class", "")))
	var out: Array = []
	var known: Array = ch.get("knownVectors", [])
	for entry in cls.get("starterDeck", []):
		var count := int(entry.get("count", 1))
		var id := ""
		if entry.has("basic"):
			id = str(entry["basic"])
		elif not known.is_empty():
			var axis := str(known[int(entry.get("vectorSlot", 0)) % known.size()])
			id = CardRules.spell_id(db, { axis: 1.0 }, str(entry["form"]), str(entry["magnitude"]))
		if id == "":
			continue
		for i in count:
			out.append(id)
	return out


## Merge every mod source (traits, perks, equipment) into one mods Dictionary.
## Numbers add, keys ending in "Mul" multiply, booleans OR.
static func collect_mods(db: Dictionary, ch: Dictionary) -> Dictionary:
	var sources: Array = []
	var traits := DT.index_under(db, "traits", "traits")
	for t in ch.get("traits", []):
		if traits.has(str(t)):
			sources.append(traits[str(t)].get("mods", {}))
	var perks := DT.index_under(db, "perks", "perks")
	for p in ch.get("perks", []):
		if perks.has(str(p)):
			sources.append(perks[str(p)].get("mods", {}))
	var items := DT.index_under(db, "items", "items")
	var equipment: Dictionary = ch.get("equipment", {})
	for slot in equipment:
		var item_id: Variant = equipment[slot]
		if item_id != null and items.has(str(item_id)):
			sources.append(items[str(item_id)].get("mods", {}))
	if ch.has("extraMods"):
		sources.append(ch["extraMods"])
	sources.append(class_data(db, str(ch.get("class", ""))).get("mods", {}))
	return merge_mods(sources)


static func merge_mods(sources: Array) -> Dictionary:
	var out := {}
	for src in sources:
		for group in src:
			if typeof(src[group]) != TYPE_DICTIONARY:
				continue
			if not out.has(group):
				out[group] = {}
			for key in src[group]:
				var v: Variant = src[group][key]
				var k := str(key)
				if typeof(v) == TYPE_BOOL:
					out[group][k] = bool(out[group].get(k, false)) or v
				elif k.ends_with("Mul"):
					out[group][k] = float(out[group].get(k, 1.0)) * float(v)
				else:
					out[group][k] = float(out[group].get(k, 0.0)) + float(v)
	return out


static func mod(mods: Dictionary, group: String, key: String, fallback: float = 0.0) -> float:
	return float(mods.get(group, {}).get(key, fallback))


## Base stats plus trait/perk/equipment stat edits, clamped to the stat range.
static func effective_stats(db: Dictionary, ch: Dictionary, mods: Dictionary = {}) -> Dictionary:
	if mods.is_empty():
		mods = collect_mods(db, ch)
	var lo := int(db.get("stats", {}).get("statMin", 1))
	var hi := int(db.get("stats", {}).get("statMax", 20))
	var out := {}
	var base: Dictionary = ch.get("stats", {})
	for s in stat_order(db):
		out[s] = clampi(int(base.get(s, 0)) + int(mod(mods, "stats", s)), lo, hi)
	return out


## Derived combat values (DESIGN.md Section 5) from data/stats.json.
static func derived(db: Dictionary, ch: Dictionary) -> Dictionary:
	var mods := collect_mods(db, ch)
	var st := effective_stats(db, ch, mods)
	var f: Dictionary = db.get("stats", {}).get("derived", {})
	var cls := class_data(db, str(ch.get("class", "")))
	var level := int(ch.get("level", 1))
	var armor := 0
	var items := DT.index_under(db, "items", "items")
	var armor_id: Variant = ch.get("equipment", {}).get("armor")
	if armor_id != null and items.has(str(armor_id)):
		armor = int(items[str(armor_id)].get("defense", 0))
	var out := {}
	out["maxHp"] = int(_lin(f.get("maxHp", {}), st)) + int(cls.get("hpBonus", 0)) \
		+ int(cls.get("hpPerLevel", 0)) * (level - 1) + int(mod(mods, "derived", "maxHp"))
	out["maxMp"] = int(_lin(f.get("maxMp", {}), st)) + int(cls.get("mpBonus", 0)) + int(mod(mods, "derived", "maxMp")) \
		+ floori(float(f.get("maxMp", {}).get("perLevel", 0.0)) * float(level - 1))
	var mv: Dictionary = f.get("movement", {})
	out["movement"] = int(mv.get("base", 3)) + floori(float(st["dex"]) / float(mv.get("dexDivisor", 5))) + int(mod(mods, "derived", "movement"))
	out["initiative"] = int(floor(_lin(f.get("initiative", {}), st))) + int(mod(mods, "derived", "initiative"))
	out["physDefense"] = int(floor(_lin(f.get("physDefense", {}), st))) + armor + int(mod(mods, "derived", "physDefense"))
	out["magicResist"] = int(floor(_lin(f.get("magicResist", {}), st))) + int(mod(mods, "derived", "magicResist"))
	out["stability"] = int(floor(_lin(f.get("stability", {}), st))) + int(mod(mods, "derived", "stability"))
	out["critChancePct"] = _lin(f.get("critChancePct", {}), st) + mod(mods, "derived", "critChancePct")
	var rg: Dictionary = f.get("mpRegen", {})
	var wil_div := float(rg.get("wilDivisor", 0))
	out["mpRegen"] = int(rg.get("base", 1)) + (floori(float(st["wil"]) / wil_div) if wil_div > 0.0 else 0) + int(mod(mods, "derived", "mpRegen"))
	out["maxHp"] = maxi(1, int(out["maxHp"]))
	out["maxMp"] = maxi(0, int(out["maxMp"]))
	out["movement"] = maxi(1, int(out["movement"]))
	return out


## base + sum(stat x coefficient) for the stat keys present in a formula.
static func _lin(formula: Dictionary, st: Dictionary) -> float:
	var v := float(formula.get("base", 0.0))
	for key in formula:
		if st.has(key):
			v += float(st[key]) * float(formula[key])
	return v


## Vector affinity table as odds, with trait affinity edits (percent points
## of the table total) blended in.
static func affinity_odds(db: Dictionary, ch: Dictionary) -> Dictionary:
	var table: Dictionary = ch.get("vectorAffinity", {})
	var mods := collect_mods(db, ch)
	var extra: Dictionary = mods.get("affinity", {})
	if not extra.is_empty():
		var t := VO.total(table)
		var scaled := {}
		for axis in extra:
			scaled[axis] = float(extra[axis]) / 100.0 * t
		table = VO.blend([table, scaled])
	return VO.normalize_sum(table)


## Max deck size at this level.
static func deck_max(db: Dictionary, ch: Dictionary) -> int:
	var lv: Dictionary = db.get("leveling", {})
	var n := int(lv.get("deckMaxBase", 20))
	for g in lv.get("deckMaxGrowth", []):
		if int(ch.get("level", 1)) >= int(g["level"]):
			n += int(g["add"])
	return n


## Clamp current HP and MP to their maximums (after level-ups or gear changes).
static func clamp_pools(db: Dictionary, ch: Dictionary) -> void:
	var d := derived(db, ch)
	ch["hp"] = clampi(int(ch.get("hp", d["maxHp"])), 0, int(d["maxHp"]))
	ch["mp"] = clampi(int(ch.get("mp", d["maxMp"])), 0, int(d["maxMp"]))


static func full_restore(db: Dictionary, ch: Dictionary) -> void:
	var d := derived(db, ch)
	ch["hp"] = int(d["maxHp"])
	ch["mp"] = int(d["maxMp"])

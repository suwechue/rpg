## Level-up rules (DESIGN.md Section 6), using the Vector operations:
## 1. Sample stat points from the class growth weights (traits nudge them).
## 2. HP and MP follow from the new stats and class bonuses.
## 3. Learning rolls: a Vector roll every level, a Form roll on even levels,
##    with pity: after 3 dry rolls only unknown axes stay in the table.
## 4. Perks at levels 3, 6 and 9 (pick 1 of 2).
## All randomness comes from the RNG passed in (use the "leveling" stream).
class_name Leveling
extends RefCounted

const VO := preload("res://src/core/vector_ops.gd")
const DT := preload("res://src/core/data_tables.gd")
const Char := preload("res://src/core/character.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("leveling", {})


## XP needed to go from `level` to level + 1.
static func xp_to_next(db: Dictionary, level: int) -> int:
	return int(cfg(db).get("xpPerLevel", 20)) * level


## Add XP and run every level-up it pays for. Returns the level-up reports.
static func add_xp(db: Dictionary, ch: Dictionary, amount: int, rng: RandomNumberGenerator) -> Array:
	var reports: Array = []
	ch["xp"] = int(ch.get("xp", 0)) + maxi(0, amount)
	var max_level := int(cfg(db).get("maxLevel", 20))
	while int(ch["level"]) < max_level and int(ch["xp"]) >= xp_to_next(db, int(ch["level"])):
		ch["xp"] = int(ch["xp"]) - xp_to_next(db, int(ch["level"]))
		reports.append(level_up(db, ch, rng))
	return reports


## One level-up. Mutates ch and returns a report for the UI and tests.
static func level_up(db: Dictionary, ch: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var before := Char.derived(db, ch)
	ch["level"] = int(ch.get("level", 1)) + 1
	var level := int(ch["level"])
	var report := { "level": level, "stats": {}, "learned": [], "raised": [], "perkChoices": [], "tierUp": false }
	report["stats"] = _roll_stats(db, ch, rng)
	var v := learning_roll(db, ch, "vectorAffinity", "knownVectors", "dryVectorRolls", rng)
	_note_roll(report, v)
	if level % int(cfg(db).get("formRollEvery", 2)) == 0:
		var f := learning_roll(db, ch, "formAffinity", "knownForms", "dryFormRolls", rng)
		_note_roll(report, f)
	if update_knowledge_tier(db, ch):
		report["tierUp"] = true
	var choices := perk_options(db, ch, level)
	if not choices.is_empty():
		report["perkChoices"] = choices
		ch["pendingPerks"] = ch.get("pendingPerks", []) + [level]
	var after := Char.derived(db, ch)
	ch["hp"] = int(ch.get("hp", 0)) + maxi(0, int(after["maxHp"]) - int(before["maxHp"]))
	ch["mp"] = int(ch.get("mp", 0)) + maxi(0, int(after["maxMp"]) - int(before["maxMp"]))
	Char.clamp_pools(db, ch)
	return report


static func _note_roll(report: Dictionary, roll: Dictionary) -> void:
	if roll.is_empty():
		return
	if roll["kind"] == "new":
		report["learned"].append(roll["axis"])
	else:
		report["raised"].append(roll["axis"])


## Sample N stat points from the class growth table (plus trait "growth" nudges).
## Stats already at the cap leave the table.
static func _roll_stats(db: Dictionary, ch: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cls := Char.class_data(db, str(ch.get("class", "")))
	var growth: Dictionary = cls.get("growth", {}).duplicate()
	var nudge: Dictionary = Char.collect_mods(db, ch).get("growth", {})
	growth = VO.blend([growth, nudge])
	var hi := int(db.get("stats", {}).get("statMax", 20))
	var order := Char.stat_order(db)
	var gained := {}
	for i in int(cfg(db).get("statPointsPerLevel", 3)):
		var table := {}
		for s in growth:
			if int(ch["stats"].get(s, 0)) < hi:
				table[s] = growth[s]
		if VO.total(table) <= 0.0:
			break
		var s := VO.sample(table, rng, order)
		ch["stats"][s] = int(ch["stats"].get(s, 0)) + 1
		gained[s] = int(gained.get(s, 0)) + 1
	return gained


## One learning roll on an affinity table. An unknown axis is learned; a known
## one gains affinity. Pity narrows the table to unknown axes after N dry rolls.
## Only axes the Knowledge Tier allows are in the table.
static func learning_roll(db: Dictionary, ch: Dictionary, table_key: String, known_key: String, dry_key: String, rng: RandomNumberGenerator) -> Dictionary:
	var table: Dictionary = ch.get(table_key, {})
	var known: Array = ch.get(known_key, [])
	var tier := int(ch.get("knowledgeTier", 1))
	var is_vectors := table_key == "vectorAffinity"
	var allowed := {}
	for axis in table:
		var t := Char.vector_tier(db, axis) if is_vectors else Char.form_tier(db, axis)
		if t <= tier and float(table[axis]) > 0.0:
			allowed[axis] = table[axis]
	if allowed.is_empty():
		return {}
	var unknown := {}
	for axis in allowed:
		if not known.has(axis):
			unknown[axis] = allowed[axis]
	var pity := int(ch.get(dry_key, 0)) >= int(cfg(db).get("pityDryRolls", 3)) and not unknown.is_empty()
	var pool: Dictionary = unknown if pity else allowed
	var order := Char.arcane_axes(db) if is_vectors else Char.form_axes(db)
	var axis := VO.sample(pool, rng, order)
	if not known.has(axis):
		known.append(axis)
		ch[known_key] = known
		ch[dry_key] = 0
		return { "kind": "new", "axis": axis, "pity": pity }
	ch[table_key] = VO.shift(table, { axis: float(cfg(db).get("affinityRaiseOnKnown", 2)) })
	ch[dry_key] = int(ch.get(dry_key, 0)) + 1
	return { "kind": "raise", "axis": axis, "pity": false }


## Raise the Knowledge Tier when level and INT reach a line. Returns true on a change.
static func update_knowledge_tier(db: Dictionary, ch: Dictionary) -> bool:
	var changed := false
	var st := Char.effective_stats(db, ch)
	for line in cfg(db).get("knowledgeTiers", []):
		var t := int(line["tier"])
		if t > int(ch.get("knowledgeTier", 1)) and int(ch["level"]) >= int(line["minLevel"]) and int(st.get("int", 0)) >= int(line["minInt"]):
			ch["knowledgeTier"] = t
			changed = true
	return changed


## The 2 perks a class offers at this level (empty if none).
static func perk_options(db: Dictionary, ch: Dictionary, level: int) -> Array:
	var offered := false
	for l in cfg(db).get("perkLevels", [3, 6, 9]):
		offered = offered or int(l) == level
	if not offered:
		return []
	var out: Array = []
	for p in DT.records_under(db, "perks", "perks"):
		if str(p.get("class", "")) == str(ch.get("class", "")) and int(p.get("level", 0)) == level:
			out.append(str(p["id"]))
	return out


## Take a perk for the oldest pending perk level. Returns false if not offered.
static func choose_perk(db: Dictionary, ch: Dictionary, perk_id: String) -> bool:
	var pending: Array = ch.get("pendingPerks", [])
	if pending.is_empty():
		return false
	var level := int(pending[0])
	if not perk_options(db, ch, level).has(perk_id):
		return false
	pending.remove_at(0)
	ch["pendingPerks"] = pending
	ch["perks"] = ch.get("perks", []) + [perk_id]
	Char.clamp_pools(db, ch)
	return true


## Auto-pick the first offered perk for every pending level (NPC party members, tests).
static func auto_perks(db: Dictionary, ch: Dictionary) -> void:
	while not ch.get("pendingPerks", []).is_empty():
		var options := perk_options(db, ch, int(ch["pendingPerks"][0]))
		if options.is_empty():
			ch["pendingPerks"].remove_at(0)
		else:
			choose_perk(db, ch, str(options[0]))

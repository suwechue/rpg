## Combat 2.0 loadouts (docs/COMBAT_2.md Part 4): what a character equips in
## their limited slots from the collection, where they may change it, three saved
## loadouts each, synergy hints and collection filters. A loadout is
## { moves, spells, perks, ultimate, gear: { weapon, armor, trinket1, trinket2 } }.
## Pure data: no nodes, no autoloads.
extends RefCounted

const Kits := preload("res://src/core/combat2/kits.gd")
const Check := preload("res://src/core/combat2/c2_check.gd")
const Night := preload("res://src/core/combat2/night.gd")

const SAVED_MAX := 3
const LISTS := ["moves", "spells", "perks"]


## Everything this character could equip from the slice collection:
## { moves, spells, perks, ultimates, gear: { slot: [ids] } }.
static func collection(db: Dictionary, char_id: String) -> Dictionary:
	var ch := Kits.character(db, char_id)
	var perks: Array = []
	for p in db.get("combat2/perks", {}).get("perks", []):
		if str(p.get("class", "any")) in ["any", str(ch.get("class", ""))]:
			perks.append(str(p["id"]))
	var gear := { "weapon": [], "armor": [], "trinket": [] }
	for g in db.get("combat2/gear", {}).get("gear", []):
		(gear[str(g["slot"])] as Array).append(str(g["id"]))
	return { "moves": (ch.get("pool", []) as Array).duplicate(), "spells": (ch.get("spells", []) as Array).duplicate(),
		"perks": perks, "ultimates": (ch.get("ultimates", []) as Array).duplicate(), "gear": gear }


static func problems(db: Dictionary, rules: RefCounted, char_id: String, level: int, lo: Dictionary) -> Array:
	return Check.loadout_problems(db, rules, char_id, level, lo)


## Equip or unequip one piece. kind: moves, spells, perks, ultimate or a gear slot.
## Returns the new loadout, or {} when it doesn't fit (full slots, not owned, the basic attack).
static func toggle(db: Dictionary, rules: RefCounted, char_id: String, level: int, lo: Dictionary, kind: String, id: String) -> Dictionary:
	var out := lo.duplicate(true)
	if LISTS.has(kind):
		var list: Array = out.get(kind, [])
		if list.has(id):
			if kind == "moves" and bool(Kits.move(db, id).get("basic", false)):
				return {}
			list.erase(id)
		else:
			list.append(id)
		out[kind] = list
	elif kind == "ultimate":
		out["ultimate"] = id
	else:
		var g: Dictionary = out.get("gear", {})
		g[kind] = "" if str(g.get(kind, "")) == id and kind != "weapon" else id
		out["gear"] = g
	return out if problems(db, rules, char_id, level, out).is_empty() else {}


## Swaps used so far this rest and where we are: can this character change their loadout?
static func can_swap(place: String, swaps_used: int) -> bool:
	var limit := Night.swap_limit(place)
	return limit < 0 or swaps_used < limit


## Save a loadout in one of the three slots: { char id: [loadout or {}, x3] }.
static func save_slot(saved: Dictionary, char_id: String, index: int, lo: Dictionary) -> Dictionary:
	var out := saved.duplicate(true)
	var list: Array = out.get(char_id, [{}, {}, {}])
	while list.size() < SAVED_MAX:
		list.append({})
	if index < 0 or index >= SAVED_MAX:
		return out
	list[index] = lo.duplicate(true)
	out[char_id] = list
	return out


## Pairs of equipped pieces that share a tag ("wall-slammer"): the synergy hints.
static func synergies(db: Dictionary, lo: Dictionary) -> Array:
	var pieces: Array = []
	for mid in lo.get("moves", []):
		pieces.append({ "id": str(mid), "name": str(Kits.move(db, str(mid)).get("name", mid)), "tags": Kits.move(db, str(mid)).get("tags", []) })
	for sid in lo.get("spells", []):
		pieces.append({ "id": str(sid), "name": str(Kits.spell(db, str(sid)).get("name", sid)), "tags": Kits.spell(db, str(sid)).get("tags", []) })
	for pid in lo.get("perks", []):
		pieces.append({ "id": str(pid), "name": str(Kits.perk(db, str(pid)).get("name", pid)), "tags": Kits.perk(db, str(pid)).get("tags", []) })
	var out: Array = []
	var seen := {}
	for i in pieces.size():
		for j in range(i + 1, pieces.size()):
			for t in pieces[i]["tags"]:
				if str(t) in ["basic", "general", "area"] or not (pieces[j]["tags"] as Array).has(t):
					continue
				var key := "%s|%s|%s" % [pieces[i]["id"], pieces[j]["id"], t]
				if not seen.has(key):
					seen[key] = true
					out.append({ "a": pieces[i]["name"], "b": pieces[j]["name"], "tag": str(t) })
	return out


## Collection pieces that match a filter: { vector, shape, tag } (any can be "").
static func filter(db: Dictionary, ids: Array, kind: String, f: Dictionary) -> Array:
	var out: Array = []
	for id in ids:
		var r: Dictionary
		match kind:
			"moves":
				r = Kits.move(db, str(id))
			"spells":
				r = Kits.spell(db, str(id))
			"perks":
				r = Kits.perk(db, str(id))
			_:
				r = Kits.gear(db, str(id))
		if str(f.get("vector", "")) != "":
			var types: Array = r.get("vectors", [str(r.get("type", ""))])
			if not types.has(str(f["vector"])):
				continue
		if str(f.get("shape", "")) != "" and str(r.get("shape", "")) != str(f["shape"]):
			continue
		if str(f.get("tag", "")) != "" and not (r.get("tags", []) as Array).has(str(f["tag"])):
			continue
		out.append(str(id))
	return out


## A random loadout that fits this level (for loadout variety in sweeps): the
## basic attack, then random picks from the collection up to each slot count.
static func random(db: Dictionary, rules: RefCounted, char_id: String, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var col := collection(db, char_id)
	var sl := Kits.slots(rules, level)
	var moves: Array = []
	var rest: Array = []
	for m in col["moves"]:
		if bool(Kits.move(db, str(m)).get("basic", false)):
			moves.append(str(m))
		else:
			rest.append(str(m))
	moves.append_array(_pick(rest, int(sl["moves"]) - moves.size(), rng))
	var gear := {}
	for slot in ["weapon", "armor", "trinket1", "trinket2"]:
		var pool: Array = col["gear"][slot.rstrip("12")]
		gear[slot] = str(pool[rng.randi_range(0, pool.size() - 1)]) if not pool.is_empty() else ""
	if str(gear["trinket1"]) == str(gear["trinket2"]):
		gear["trinket2"] = ""
	var ults: Array = col["ultimates"]
	return { "moves": moves, "spells": _pick(col["spells"], int(sl["spells"]), rng), "perks": _pick(col["perks"], int(sl["perks"]), rng),
		"ultimate": str(ults[rng.randi_range(0, ults.size() - 1)]) if not ults.is_empty() else "", "gear": gear }


static func _pick(pool: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var left: Array = pool.duplicate()
	var out: Array = []
	while out.size() < n and not left.is_empty():
		out.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
	return out


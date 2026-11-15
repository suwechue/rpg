## Combat 2.0 kits (docs/COMBAT_2.md Part 2): slot counts by level, spell
## charges, and a character's kit for a fight from their loadout (moves, spells,
## ultimate, perks and gear). Pure data: no nodes, no autoloads.
extends RefCounted

const C2Rules := preload("res://src/core/combat2/c2_rules.gd")


static func rec(db: Dictionary, table: String, list: String, id: String) -> Dictionary:
	for r in db.get("combat2/" + table, {}).get(list, []):
		if str(r.get("id", "")) == id:
			return r
	return {}


static func character(db: Dictionary, id: String) -> Dictionary:
	return rec(db, "characters", "characters", id)


static func move(db: Dictionary, id: String) -> Dictionary:
	return rec(db, "moves", "moves", id)


static func spell(db: Dictionary, id: String) -> Dictionary:
	return rec(db, "spells", "spells", id)


static func ultimate(db: Dictionary, id: String) -> Dictionary:
	return rec(db, "ultimates", "ultimates", id)


static func perk(db: Dictionary, id: String) -> Dictionary:
	return rec(db, "perks", "perks", id)


static func gear(db: Dictionary, id: String) -> Dictionary:
	return rec(db, "gear", "gear", id)


static func item(db: Dictionary, id: String) -> Dictionary:
	return rec(db, "gear", "items", id)


## Slots at this level: { moves, spells, perks, ultimateUpgrades }.
static func slots(rules: C2Rules, level: int) -> Dictionary:
	return { "moves": C2Rules.by_level(rules.text("moveSlots"), level), "spells": C2Rules.by_level(rules.text("spellSlots"), level),
		"perks": C2Rules.by_level(rules.text("perkSlots"), level), "ultimateUpgrades": C2Rules.reached(rules.text("ultimateUpgrades"), level) }


## Charges per night: the magnitude's count, +1 for a great craft, -1 per extra
## Vector, then perk changes by Vector. Never under 1.
static func charges_for(db: Dictionary, rules: C2Rules, sp: Dictionary, effects: Array = []) -> int:
	var lever := str(db.get("combat2/rules", {}).get("magnitudes", {}).get(str(sp.get("magnitude", "Standard")), "chargesStandard"))
	var n := rules.count(lever, 3)
	if str(sp.get("grade", "")) == "great":
		n += rules.count("chargesGradeBonus", 1)
	var vectors: Array = sp.get("vectors", [])
	if vectors.size() > 1:
		n -= rules.count("chargesMultiVector", 1) * (vectors.size() - 1)
	for e in effects:
		if str(e.get("kind", "")) == "chargeMod":
			for v in vectors:
				n += int(e.get("mods", {}).get(str(v), 0))
	return maxi(1, n)


## Stats at a level, before perks and gear: base + growth x (level - 1).
static func stats_at(ch: Dictionary, level: int) -> Dictionary:
	var out := {}
	var base: Dictionary = ch.get("stats", {})
	var grow: Dictionary = ch.get("growth", {})
	for k in base:
		out[k] = float(base[k]) + float(grow.get(k, 0.0)) * float(maxi(0, level - 1))
	return out


## Every effect line a kit carries: its perks and its gear.
static func effects_of(db: Dictionary, loadout: Dictionary) -> Array:
	var out: Array = []
	for pid in loadout.get("perks", []):
		var p := perk(db, str(pid))
		if not p.is_empty():
			var e: Dictionary = (p["effect"] as Dictionary).duplicate()
			e["source"] = str(pid)
			out.append(e)
	for slot in loadout.get("gear", {}):
		var g := gear(db, str(loadout["gear"][slot]))
		if g.has("effect"):
			var e: Dictionary = (g["effect"] as Dictionary).duplicate()
			e["source"] = str(g["id"])
			out.append(e)
	return out


## One Ability as the state uses it: the data record plus kind, uid and, for spells, Vector type.
static func ability(base: Dictionary, kind: String) -> Dictionary:
	var a := base.duplicate(true)
	a["kind"] = kind
	a["uid"] = kind + ":" + str(base.get("id", ""))
	if kind == "spell" and not a.has("type"):
		var v: Array = base.get("vectors", [])
		a["type"] = str(v[0]) if not v.is_empty() else ""
	return a


## A fight-ready kit for this character at this level with this loadout.
static func build(db: Dictionary, rules: C2Rules, char_id: String, level: int, loadout: Dictionary) -> Dictionary:
	var ch := character(db, char_id)
	var effects := effects_of(db, loadout)
	var weapon := gear(db, str(loadout.get("gear", {}).get("weapon", "")))
	var armor := gear(db, str(loadout.get("gear", {}).get("armor", "")))
	var moves: Array = []
	var seen := {}
	for mid in loadout.get("moves", []):
		var m := move(db, str(mid))
		if m.is_empty() or seen.has(str(mid)):
			continue
		seen[str(mid)] = true
		var a := ability(m, "move")
		if bool(m.get("weaponType", false)) and not weapon.is_empty():
			a["type"] = str(weapon.get("basicType", a.get("type", "")))
			if weapon.has("basicShape"):
				a["shape"] = str(weapon["basicShape"])
				a["range"] = int(weapon.get("basicRange", 1))
				a["target"] = "enemy" if str(weapon["basicShape"]) != "line" else "tile"
		for e in effects:
			if str(e.get("kind", "")) == "cooldownCut" and str(e.get("move", "")) == str(mid):
				a["cooldown"] = maxi(0, int(a.get("cooldown", 0)) - int(e.get("value", 1)))
		moves.append(a)
	if weapon.has("weaponMove") and not seen.has(str(weapon["weaponMove"])):
		var wm := move(db, str(weapon["weaponMove"]))
		if not wm.is_empty():
			var a := ability(wm, "move")
			a["fromWeapon"] = true
			moves.append(a)
	var spells: Array = []
	for sid in loadout.get("spells", []):
		var s := spell(db, str(sid))
		if s.is_empty():
			continue
		var a := ability(s, "spell")
		a["maxCharges"] = charges_for(db, rules, s, effects)
		spells.append(a)
	var ult := ultimate(db, str(loadout.get("ultimate", "")))
	var ult_ab := {}
	if not ult.is_empty():
		ult_ab = ability(ult, "ultimate")
		var ups: Array = ult.get("upgrades", [])
		for i in mini(slots(rules, level)["ultimateUpgrades"], ups.size()):
			var up: Dictionary = ups[i]
			if up.has("power"):
				for k in ["power", "shield", "heal"]:
					if ult_ab.has(k):
						ult_ab[k] = float(ult_ab[k]) * float(up["power"])
			if up.has("radius"):
				ult_ab["range"] = int(ult_ab.get("range", 1)) + int(up["radius"])
				ult_ab["radius"] = int(ult_ab.get("radius", 1)) + int(up["radius"])
			if up.has("heal"):
				ult_ab["heal"] = float(ult_ab.get("heal", 0)) + float(up["heal"])
	var stats := stats_at(ch, level)
	stats["movement"] = float(stats.get("movement", 3)) + float(armor.get("movement", 0)) + _sum(effects, "movementPlus")
	stats["agility"] = float(stats.get("agility", 5)) + _sum(effects, "initiativePlus")
	stats["hp"] = float(stats.get("hp", 20)) + _sum(effects, "maxHpPlus")
	var weak: Array = (ch.get("weak", []) as Array).duplicate()
	var resist: Array = (ch.get("resist", []) as Array).duplicate()
	for w in armor.get("weak", []):
		if not weak.has(w):
			weak.append(w)
		resist.erase(w)
	for r in armor.get("resist", []):
		if not resist.has(r):
			resist.append(r)
		weak.erase(r)
	return { "char": char_id, "name": str(ch.get("name", char_id)), "class": str(ch.get("class", "")), "level": level, "sprite": str(ch.get("sprite", "")),
		"moves": moves, "spells": spells, "ultimate": ult_ab, "effects": effects, "stats": stats, "weak": weak, "resist": resist,
		"loadout": loadout.duplicate(true) }


static func _sum(effects: Array, kind: String) -> float:
	var n := 0.0
	for e in effects:
		if str(e.get("kind", "")) == kind:
			n += float(e.get("value", 0))
	return n

## Gear (docs/TOWN_LIFE.md Part 4, data/gear.json, data/gear_recipes.json):
## slots (a second trinket at level 6), what each piece adds (armor type,
## weapon type, upgrades, infusions, durability), comparing, equipping, and
## the blacksmith's services: forge, upgrade, infuse, repair, commissions.
## Per-item state lives in run["gear"][item id]; each character caches its
## totals in ch["gearStats"] (refresh after any change) for derived stats and combat.
extends RefCounted

const DT := preload("res://src/core/data_tables.gd")
const Fx := preload("res://src/core/run/effects.gd")
const RM := preload("res://src/core/run/run_model.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("gear", {})


static func item(db: Dictionary, id: String) -> Dictionary:
	return DT.record(db, "items", id)


static func slots(db: Dictionary, ch: Dictionary) -> Array:
	var out: Array = ["weapon", "armor", "trinket"]
	if int(ch.get("level", 1)) >= int(cfg(db).get("secondTrinketLevel", 6)):
		out.append("trinket2")
	return out


static func state(run: Dictionary, id: String) -> Dictionary:
	var g: Dictionary = run.get("gear", {})
	if not g.has(id):
		g[id] = { "level": 0, "infusion": "", "resist": {}, "durability": -1 }
		run["gear"] = g
	return g[id]


static func max_durability(db: Dictionary) -> int:
	return int(cfg(db).get("durability", {}).get("max", 3))


static func broken(db: Dictionary, run: Dictionary, id: String) -> bool:
	var d := int(state(run, id).get("durability", -1))
	return d == 0


## What one piece adds: defense, magicResist, movement, initiative,
## strikePower, guardShield, resist { vector: pct }, and for weapons
## reach, push, mul, tags, infusion. Broken pieces give half.
static func piece(db: Dictionary, run: Dictionary, ch: Dictionary, id: String) -> Dictionary:
	var it := item(db, id)
	var s := state(run, id)
	var out := { "defense": int(it.get("defense", 0)), "magicResist": int(it.get("magicResist", 0)), "movement": 0, "initiative": 0,
		"strikePower": 0, "guardShield": 0, "resist": it.get("resist", {}).duplicate() }
	var lvl := int(s.get("level", 0))
	var up: Dictionary = cfg(db).get("upgrade", {})
	if it.has("armorType"):
		var at: Dictionary = cfg(db).get("armorTypes", {}).get(str(it["armorType"]), {})
		for k in ["movement", "initiative", "guardShield"]:
			out[k] = int(out[k]) + int(at.get(k, 0))
		out["defense"] = int(out["defense"]) + lvl * int(up.get("armorDefense", 1))
		if str(cfg(db).get("classArmor", {}).get(str(ch.get("class", "")), "")) == str(it["armorType"]):
			out["defense"] = int(out["defense"]) + int(cfg(db).get("classArmorBonus", 1))
		for v in s.get("resist", {}):
			out["resist"][v] = int(out["resist"].get(v, 0)) + int(s["resist"][v])
	if it.has("weaponType"):
		var wt: Dictionary = cfg(db).get("weaponTypes", {}).get(str(it["weaponType"]), {})
		out["reach"] = int(wt.get("reach", 1))
		out["push"] = int(wt.get("push", 0))
		out["mul"] = float(wt.get("mul", 1.0))
		out["tags"] = wt.get("tags", [])
		out["infusion"] = str(s.get("infusion", ""))
		out["strikePower"] = lvl * int(up.get("weaponPower", 2))
	if broken(db, run, id):
		for k in ["defense", "magicResist", "strikePower"]:
			out[k] = int(out[k]) / 2
	return out


## Totals over everything a character wears (cached into ch["gearStats"]).
static func refresh(db: Dictionary, run: Dictionary, ch: Dictionary) -> Dictionary:
	var tot := { "defense": 0, "magicResist": 0, "movement": 0, "initiative": 0, "strikePower": 0, "guardShield": 0, "resist": {}, "weapon": {} }
	for slot in ch.get("equipment", {}):
		var id: Variant = ch["equipment"][slot]
		if id == null or str(id) == "":
			continue
		var p := piece(db, run, ch, str(id))
		for k in ["defense", "magicResist", "movement", "initiative", "strikePower", "guardShield"]:
			tot[k] = int(tot[k]) + int(p[k])
		for v in p["resist"]:
			tot["resist"][v] = int(tot["resist"].get(v, 0)) + int(p["resist"][v])
		if p.has("reach"):
			tot["weapon"] = { "reach": p["reach"], "push": p["push"], "mul": p["mul"], "tags": p["tags"], "infusion": p["infusion"] }
	ch["gearStats"] = tot
	return tot


## How equipping an item would change a character's numbers (vs that slot now).
static func compare(db: Dictionary, run: Dictionary, ch: Dictionary, id: String, slot: String = "") -> Dictionary:
	var sl := slot if slot != "" else str(item(db, id).get("slot", ""))
	var now: Variant = ch.get("equipment", {}).get(sl)
	var a := piece(db, run, ch, id)
	var b := piece(db, run, ch, str(now)) if now != null and str(now) != "" else {}
	var out := {}
	for k in ["defense", "magicResist", "movement", "strikePower"]:
		out[k] = int(a.get(k, 0)) - int(b.get(k, 0))
	out["reach"] = int(a.get("reach", 0))
	return out


## Put an owned piece on a character (slot "" = its own; trinkets may go to trinket2).
static func equip(db: Dictionary, run: Dictionary, ch: Dictionary, id: String, slot: String = "") -> String:
	var it := item(db, id)
	if str(it.get("kind", "")) != "equipment":
		return "not_gear"
	if int(run.get("inventory", {}).get(id, 0)) <= 0:
		return "not_owned"
	var sl := slot if slot != "" else str(it.get("slot", ""))
	if sl == "trinket2" and str(it.get("slot", "")) != "trinket":
		return "wrong_slot"
	if not slots(db, ch).has(sl):
		return "no_slot"
	var eq: Dictionary = ch.get("equipment", {})
	var old: Variant = eq.get(sl)
	Fx.add_item(run, id, -1)
	if old != null and str(old) != "":
		Fx.add_item(run, str(old), 1)
	eq[sl] = id
	ch["equipment"] = eq
	refresh(db, run, ch)
	return ""


static func unequip(db: Dictionary, run: Dictionary, ch: Dictionary, slot: String) -> void:
	var old: Variant = ch.get("equipment", {}).get(slot)
	if old != null and str(old) != "":
		Fx.add_item(run, str(old), 1)
	ch["equipment"][slot] = null
	refresh(db, run, ch)


static func _has_ores(run: Dictionary, ores: Dictionary) -> bool:
	for o in ores:
		if int(run.get("inventory", {}).get(str(o), 0)) < int(ores[o]):
			return false
	return true


static func _pay(run: Dictionary, money: int, ores: Dictionary) -> void:
	run["money"] = int(run.get("money", 0)) - money
	for o in ores:
		Fx.add_item(run, str(o), -int(ores[o]))


## Recipes the blacksmith will make now (week and Bond).
static func recipes(db: Dictionary, run: Dictionary, week: int) -> Array:
	return db.get("gear_recipes", {}).get("recipes", []).filter(func(r: Dictionary) -> bool:
		return week >= int(r.get("fromWeek", 1)) and RM.bond(run, "blacksmith") >= float(r.get("minBlacksmithBond", 0)))


## Forge a recipe: money and ore, then the hammer score (perf) decides the
## quality: forgeGood or better starts it at +1. Returns "" or why not.
static func forge(db: Dictionary, run: Dictionary, recipe: Dictionary, perf: float) -> String:
	if int(run.get("money", 0)) < int(recipe.get("money", 0)) or not _has_ores(run, recipe.get("ores", {})):
		return "cost"
	_pay(run, int(recipe.get("money", 0)), recipe.get("ores", {}))
	var id := str(recipe["item"])
	Fx.add_item(run, id, 1)
	if perf >= float(cfg(db).get("forgeGood", 0.8)):
		state(run, id)["level"] = maxi(1, int(state(run, id).get("level", 0)))
	return ""


static func upgrade_cost(db: Dictionary, run: Dictionary, id: String) -> int:
	return int(cfg(db).get("upgrade", {}).get("baseCost", 15)) * (int(state(run, id).get("level", 0)) + 1)


static func upgrade(db: Dictionary, run: Dictionary, id: String) -> String:
	var up: Dictionary = cfg(db).get("upgrade", {})
	var s := state(run, id)
	if int(s["level"]) >= int(up.get("max", 3)):
		return "max"
	var ores := { str(up.get("ore", "ore_iron")): 1 }
	var cost := upgrade_cost(db, run, id)
	if int(run.get("money", 0)) < cost or not _has_ores(run, ores):
		return "cost"
	_pay(run, cost, ores)
	s["level"] = int(s["level"]) + 1
	return ""


## Infuse a weapon with a Vector (or give armor that Vector's resistance)
## using an ore that carries it. Returns "" or why not.
static func infuse(db: Dictionary, run: Dictionary, id: String, vector: String, ore: String) -> String:
	var inf: Dictionary = cfg(db).get("infuse", {})
	if not inf.get("ores", {}).get(ore, []).has(vector):
		return "ore"
	if int(run.get("money", 0)) < int(inf.get("cost", 20)) or not _has_ores(run, { ore: 1 }):
		return "cost"
	_pay(run, int(inf.get("cost", 20)), { ore: 1 })
	var it := item(db, id)
	if it.has("weaponType"):
		state(run, id)["infusion"] = vector
	else:
		var r: Dictionary = state(run, id).get("resist", {})
		r[vector] = int(inf.get("resistPct", 25))
		state(run, id)["resist"] = r
	return ""


static func durability_on(db: Dictionary, difficulty: String) -> bool:
	return bool(cfg(db).get("durability", {}).get("difficulties", {}).get(difficulty, true))


## A character went down: each piece they wear loses 1 durability.
static func wear_down(db: Dictionary, run: Dictionary, ch: Dictionary) -> void:
	for slot in ch.get("equipment", {}):
		var id: Variant = ch["equipment"][slot]
		if id == null or str(id) == "":
			continue
		var s := state(run, str(id))
		var d := int(s.get("durability", -1))
		if d < 0:
			d = max_durability(db)
		s["durability"] = maxi(0, d - 1)
	refresh(db, run, ch)


static func repair_cost(db: Dictionary, run: Dictionary) -> int:
	var r: Dictionary = cfg(db).get("repair", {})
	return 0 if RM.bond(run, "blacksmith") >= float(r.get("freeBond", 41)) else int(r.get("cost", 8))


static func repair(db: Dictionary, run: Dictionary, id: String) -> String:
	var cost := repair_cost(db, run)
	if int(run.get("money", 0)) < cost:
		return "cost"
	run["money"] = int(run.get("money", 0)) - cost
	state(run, id)["durability"] = max_durability(db)
	return ""


## Commissions: a unique piece, ready commissionDays days later.
static func commissions(db: Dictionary, run: Dictionary) -> Array:
	return db.get("gear_recipes", {}).get("commissions", []).filter(func(c: Dictionary) -> bool:
		if RM.bond(run, "blacksmith") < float(c.get("minBlacksmithBond", 0)):
			return false
		for npc in c.get("needBond", {}):
			if RM.bond(run, str(npc)) < float(c["needBond"][npc]):
				return false
		if c.has("needFlag") and not RM.flag(run, str(c["needFlag"])):
			return false
		return not run.get("commissioned", []).has(str(c["id"])))


static func commission(db: Dictionary, run: Dictionary, c: Dictionary, day_count: int) -> String:
	if int(run.get("money", 0)) < int(c.get("money", 0)) or not _has_ores(run, c.get("ores", {})):
		return "cost"
	_pay(run, int(c.get("money", 0)), c.get("ores", {}))
	var orders: Array = run.get("orders", [])
	orders.append({ "item": str(c["item"]), "ready": day_count + int(cfg(db).get("commissionDays", 2)) })
	run["orders"] = orders
	var done: Array = run.get("commissioned", [])
	done.append(str(c["id"]))
	run["commissioned"] = done
	return ""


## Orders ready by today: handed over (into the inventory). Returns item ids.
static func collect(run: Dictionary, day_count: int) -> Array:
	var out: Array = []
	var keep: Array = []
	for o in run.get("orders", []):
		if int(o["ready"]) <= day_count:
			Fx.add_item(run, str(o["item"]), 1)
			out.append(str(o["item"]))
		else:
			keep.append(o)
	run["orders"] = keep
	return out


## Ore after a won fight (or "").
static func ore_drop(db: Dictionary, week: int, rng: RandomNumberGenerator) -> String:
	var od: Dictionary = cfg(db).get("oreDrops", {})
	if rng.randf() >= float(od.get("chance", 0.35)):
		return ""
	var pool: Array = od.get("byWeek", {}).get(str(clampi(week, 1, 5)), ["ore_iron"])
	return str(pool[rng.randi_range(0, pool.size() - 1)])

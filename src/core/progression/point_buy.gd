## Point-buy stats at run start (docs/PATCH_1.md Part 9). Every stat starts at
## data/point_buy.json "base"; you spend "points" (1 per point up to 8, 2 per
## point from 9 to 10, nothing above "max"), and the class adds its small bonus.
extends RefCounted

const Str := preload("res://src/core/strings.gd")
const Char := preload("res://src/core/character.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("point_buy", {})


static func stat_order(db: Dictionary) -> Array:
	return db.get("spaces", {}).get("stats", {}).get("axes", ["str", "dex", "con", "int", "per", "wil", "cha"])


## Starting allocation: every stat at the base.
static func blank(db: Dictionary) -> Dictionary:
	var out := {}
	for s in stat_order(db):
		out[s] = int(cfg(db).get("base", 3))
	return out


## Points one stat value costs above the base.
static func stat_cost(db: Dictionary, value: int) -> int:
	var base := int(cfg(db).get("base", 3))
	var total := 0
	var prev := base
	for tier in cfg(db).get("costs", [{ "upTo": 8, "cost": 1 }, { "upTo": 10, "cost": 2 }]):
		var top := mini(value, int(tier["upTo"]))
		if top > prev:
			total += (top - prev) * int(tier["cost"])
			prev = top
	return total


static func spent(db: Dictionary, stats: Dictionary) -> int:
	var n := 0
	for s in stat_order(db):
		n += stat_cost(db, int(stats.get(s, cfg(db).get("base", 3))))
	return n


static func left(db: Dictionary, stats: Dictionary) -> int:
	return int(cfg(db).get("points", 20)) - spent(db, stats)


## Why an allocation isn't allowed, or "".
static func error(db: Dictionary, stats: Dictionary) -> String:
	for s in stat_order(db):
		var v := int(stats.get(s, 0))
		if v < int(cfg(db).get("base", 3)) or v > int(cfg(db).get("max", 10)):
			return Str.t(db, "point_buy.out_of_range") % str(s).to_upper()
	if left(db, stats) < 0:
		return Str.t(db, "point_buy.over_budget")
	return ""


## One more (or less) point in a stat, if allowed. Returns the new allocation.
static func step(db: Dictionary, stats: Dictionary, stat: String, delta: int) -> Dictionary:
	var out := stats.duplicate()
	out[stat] = int(out.get(stat, 3)) + delta
	return out if error(db, out) == "" else stats


static func recommended(db: Dictionary, class_id: String) -> Dictionary:
	var rec: Dictionary = cfg(db).get("recommended", {}).get(class_id, {})
	var out := blank(db)
	for s in rec:
		out[s] = int(rec[s])
	return out if error(db, out) == "" else blank(db)


## A random legal allocation that spends the whole budget.
static func random(db: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := blank(db)
	var order := stat_order(db)
	var guard := 0
	while left(db, out) > 0 and guard < 500:
		guard += 1
		var s := str(order[rng.randi_range(0, order.size() - 1)])
		out = step(db, out, s, 1)
	return out


## The final starting stats: the allocation plus the class bonus.
static func final_stats(db: Dictionary, class_id: String, stats: Dictionary) -> Dictionary:
	var out := stats.duplicate()
	var bonus: Dictionary = cfg(db).get("classBonus", {}).get(class_id, {})
	for s in bonus:
		out[s] = int(out.get(s, 3)) + int(bonus[s])
	return out


## Re-base an existing character (arena presets, already levelled) on a point-buy
## allocation: the change from its class's starting stats is applied, so level-up
## gains are kept. HP and MP refill.
static func apply_to(db: Dictionary, ch: Dictionary, alloc: Dictionary) -> void:
	var cls_id := str(ch.get("class", "mage"))
	var start: Dictionary = {}
	for c in db.get("classes", {}).get("classes", []):
		if str(c.get("id", "")) == cls_id:
			start = c.get("startStats", {})
	var final := final_stats(db, cls_id, alloc)
	for s in stat_order(db):
		ch["stats"][s] = maxi(1, int(ch["stats"].get(s, 3)) + int(final.get(s, 3)) - int(start.get(s, 3)))
	Char.full_restore(db, ch)

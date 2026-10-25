## The run as one Dictionary (DESIGN.md Section 16, "One source of truth").
## GameState holds it; saving serializes it. These functions build a fresh run
## and look things up in it. Everything else in src/core/run/ edits it.
class_name RunModel
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const Char := preload("res://src/core/character.gd")
const VO := preload("res://src/core/vector_ops.gd")

const VERSION := 3


## A fresh run. opts: name, traits.
static func new_run(db: Dictionary, seed_value: int, class_id: String, rng: RandomNumberGenerator, opts: Dictionary = {}) -> Dictionary:
	var player := Char.create(db, class_id, rng, {
		"id": "player", "name": str(opts.get("name", Str.t(db, "run_model.new_kid"))), "isPlayer": true, "traits": opts.get("traits", []) })
	player["sprite"] = str(opts.get("sprite", db.get("assets/roles", {}).get("player", "")))
	var collection := {}
	for id in player["deck"]:
		collection[id] = int(collection.get(id, 0)) + 1
	var run := {
		"version": VERSION,
		"seed": seed_value,
		"player": player,
		"roster": [],
		"party_ids": [],
		"cards": {},
		"collection": collection,
		"money": int(db.get("economy", {}).get("startMoney", 20)),
		"inventory": {},
		"flags": {},
		"bonds": {},
		"npcs": {},
		"schedule": db.get("school_classes", {}).get("defaultSchedule", []).duplicate(),
		"schedule_week": 0,
		"attendance": {},
		"attendance_week": {},
		"attended_today": [],
		"grades": {},
		"skips_week": 0,
		"skips_total": 0,
		"detentions": 0,
		"detention_pending": false,
		"shifts": {},
		"signature": {},
		"encounter_log": [],
		"kelly_risk": 0,
		"events_seen": {},
		"crafted": 0,
		"log": [],
		"day_count": 0,
	}
	for key in db:
		if str(key).begins_with("npcs/"):
			var rec: Dictionary = db[key]
			var id := str(rec.get("id", str(key).get_file()))
			run["bonds"][id] = float(rec.get("startBond", 0))
			run["npcs"][id] = { "disposition": rec.get("disposition", {}).duplicate(), "topics": {}, "met": false, "gifts": 0 }
	return run


## A character in the run by id ("player" or a roster member).
static func character(run: Dictionary, id: String) -> Dictionary:
	if id == "player":
		return run.get("player", {})
	for m in run.get("roster", []):
		if str(m.get("id", "")) == id:
			return m
	for g in run.get("guests", []):
		if str(g.get("id", "")) == id:
			return g
	return {}


static func flag(run: Dictionary, key: String) -> bool:
	return bool(run.get("flags", {}).get(key, false))


static func set_flag(run: Dictionary, key: String, value: Variant = true) -> void:
	run["flags"][key] = value


static func bond(run: Dictionary, npc: String) -> float:
	return float(run.get("bonds", {}).get(npc, 0.0))


## Grow a stat's experience bar. A stat point arrives every few bars, and the
## bar gets longer as the stat rises (data/stats.json "training").
static func train_stat(db: Dictionary, ch: Dictionary, stat: String, bars: float) -> Dictionary:
	var cfg: Dictionary = db.get("stats", {}).get("training", {})
	var xp: Dictionary = ch.get("statXp", {})
	var hi := int(db.get("stats", {}).get("statMax", 20))
	var gained := 0
	xp[stat] = float(xp.get(stat, 0.0)) + bars
	while true:
		var cur := int(ch["stats"].get(stat, 1))
		var need := bars_for(cfg, cur)
		if cur >= hi or float(xp[stat]) < need:
			break
		xp[stat] = float(xp[stat]) - need
		ch["stats"][stat] = cur + 1
		gained += 1
	ch["statXp"] = xp
	return { "stat": stat, "gained": gained, "bar": float(xp[stat]), "need": bars_for(cfg, int(ch["stats"].get(stat, 1))) }


## Bars per stat point at a given stat value: 3 at low stats, rising to 5.
static func bars_for(cfg: Dictionary, stat_value: int) -> float:
	var base := float(cfg.get("barsBase", 3))
	var step := float(cfg.get("barsStatStep", 6))
	return minf(float(cfg.get("barsMax", 5)), base + floorf(float(maxi(0, stat_value - 1)) / step))


## Nudge a character's Vector affinity (+raw weight; normalize only on read).
static func nudge_affinity(db: Dictionary, ch: Dictionary, delta: Dictionary) -> void:
	var allowed := {}
	var tiers: Dictionary = db.get("spaces", {}).get("arcane", {}).get("tiers", {})
	for axis in delta:
		if int(tiers.get(axis, 1)) <= int(ch.get("knowledgeTier", 1)):
			allowed[axis] = delta[axis]
	if not allowed.is_empty():
		ch["vectorAffinity"] = VO.shift(ch.get("vectorAffinity", {}), allowed)


static func add_log(run: Dictionary, text: String) -> void:
	var log: Array = run.get("log", [])
	log.append(text)
	if log.size() > 60:
		log.remove_at(0)
	run["log"] = log

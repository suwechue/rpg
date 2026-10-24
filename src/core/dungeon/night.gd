## What happens in each room of a night's floor: resting, treasure and Vector
## shards, the aftermath of a fight (encounter log, loot) and the boss reward.
class_name DungeonNight
extends RefCounted

const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Char := preload("res://src/core/character.gd")
const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const Sig := preload("res://src/core/dungeon/signature.gd")
const VO := preload("res://src/core/vector_ops.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("dungeon", {})


## Enemy records for a room's fight, scaled for the party's size: smaller
## parties face fewer, weaker enemies (data/dungeon.json "partyScale").
## The first enemy (an elite or the boss) always stays.
static func fight_enemies(db: Dictionary, room: Dictionary, party_size: int) -> Array:
	var ps: Dictionary = cfg(db).get("partyScale", {}).get(str(clampi(party_size, 1, 4)), {})
	var ids: Array = room.get("enemies", [])
	var t := str(room.get("type", ""))
	var keep := ids.size()
	if t != "boss":
		keep = maxi(1, ceili(float(ids.size()) * float(ps.get("count", 1.0))))
	var idx := {}
	for e in preload("res://src/core/data_tables.gd").records_under(db, "enemies/", "enemies"):
		idx[str(e["id"])] = e
	var out: Array = []
	for i in keep:
		var rec: Dictionary = idx.get(str(ids[i]), {}).duplicate(true)
		if rec.is_empty():
			continue
		var base := 1.0 if t == "boss" else float(room.get("scale", 1.0))
		rec["scale"] = base * float(ps.get("power", 1.0))
		out.append(rec)
	return out


static func party_size(run: Dictionary) -> int:
	return party_chars(run).size()


static func start(db: Dictionary, run: Dictionary, week: int, day: String) -> Dictionary:
	var f := Gen.generate(db, run, week, day)
	run["floor"] = f
	run["floor_room"] = 0
	return f


## Rest room: everyone in the party back to full HP and MP.
static func rest(db: Dictionary, run: Dictionary, room: Dictionary) -> Array:
	var lines: Array = []
	for ch in party_chars(run):
		var d := Char.derived(db, ch)
		ch["hp"] = int(d["maxHp"]) if not bool(ch.get("downed", false)) else maxi(1, int(ch.get("hp", 1)))
		ch["mp"] = int(d["maxMp"])
	room["cleared"] = true
	lines.append("You rest by a fire that burns without wood. HP and MP restored.")
	return lines


## Catch your breath after a won fight: everyone standing regains a share of max HP.
static func recover(db: Dictionary, run: Dictionary, share: float) -> void:
	if share <= 0.0:
		return
	for ch in party_chars(run):
		var d := Char.derived(db, ch)
		if int(ch.get("hp", 0)) > 0:
			ch["hp"] = mini(int(d["maxHp"]), int(ch.get("hp", 0)) + roundi(float(d["maxHp"]) * share))


static func party_chars(run: Dictionary) -> Array:
	var out: Array = [run["player"]]
	for id in run.get("party_ids", []):
		var m := RM.character(run, str(id))
		if not m.is_empty() and int(m.get("injured", 0)) <= 0:
			out.append(m)
	for g in run.get("guests", []):
		out.append(g)
	return out


## A Vector shard: three of an axis teach it (if the Knowledge Tier allows).
static func add_shard(db: Dictionary, run: Dictionary, axis: String) -> Array:
	var lines: Array = ["A %s shard hums in your hand." % axis.capitalize()]
	var shards: Dictionary = run.get("shards", {})
	shards[axis] = int(shards.get(axis, 0)) + 1
	run["shards"] = shards
	var p: Dictionary = run["player"]
	var tier := int(db.get("spaces", {}).get("arcane", {}).get("tiers", {}).get(axis, 1))
	if int(shards[axis]) >= int(cfg(db).get("shardsToLearn", 3)) and not p["knownVectors"].has(axis) and tier <= int(p.get("knowledgeTier", 1)):
		shards[axis] = 0
		p["knownVectors"].append(axis)
		lines.append("The shards fuse. You know the %s Vector now." % axis.capitalize())
	return lines


## The week's dominant axis, or a Sampled axis of its signature, for shards.
static func shard_axis(db: Dictionary, run: Dictionary, week: int, rng: RandomNumberGenerator) -> String:
	var sig := Sig.current(db, run, week)
	return VO.sample(sig, rng, db.get("spaces", {}).get("arcane", {}).get("axes", []))


static func open_treasure(db: Dictionary, run: Dictionary, room: Dictionary, week: int, rng: RandomNumberGenerator) -> Array:
	var t: Dictionary = cfg(db).get("treasure", {})
	var lines: Array = ["The chest opens with a sound like a locker slamming."]
	var span: Array = t.get("money", [5, 15])
	var fx := { "money": rng.randi_range(int(span[0]), int(span[1])) * week }
	if rng.randf() < float(t.get("itemChance", 0.5)):
		var items: Array = t.get("items", [])
		fx["item"] = { str(items[rng.randi_range(0, items.size() - 1)]): 1 }
	if rng.randf() < float(t.get("cardChance", 0.3)):
		var cards: Array = t.get("cards", [])
		fx["card"] = str(cards[rng.randi_range(0, cards.size() - 1)])
	lines.append_array(Fx.apply(db, run, fx, rng, {}))
	if rng.randf() < float(t.get("shardChance", 0.4)):
		lines.append_array(add_shard(db, run, shard_axis(db, run, week, rng)))
	room["cleared"] = true
	return lines


## After a fight in a room: log it for Friday, clear the room, a chance at a shard.
static func after_combat(db: Dictionary, run: Dictionary, room: Dictionary, summary: Dictionary, week: int, day: String, rng: RandomNumberGenerator) -> Array:
	var lines: Array = []
	var result := str(summary.get("result", ""))
	if not bool(room.get("returning", false)) and str(room.get("type", "")) != "boss":
		Gen.log_encounter(run, week, day, room, result)
	if result == "win":
		room["cleared"] = true
		recover(db, run, float(cfg(db).get("afterFightHpPct", 0.0)))
		if rng.randf() < float(cfg(db).get("combatLoot", {}).get("shardChance", 0.15)):
			lines.append_array(add_shard(db, run, shard_axis(db, run, week, rng)))
	elif result == "flee":
		room["cleared"] = true
		room["fled"] = true
		lines.append("You got away. They'll remember you on Friday.")
	return lines


## Clearing the week: XP and money, a new Form or a Knowledge Tier, items, flags.
static func boss_reward(db: Dictionary, run: Dictionary, week: int, rng: RandomNumberGenerator) -> Array:
	var rw: Dictionary = Sig.week_rec(db, week).get("reward", {})
	var lines: Array = []
	if rw.has("narrate"):
		lines.append(str(rw["narrate"]))
	var p: Dictionary = run["player"]
	var fx := {}
	for k in ["money", "item", "flag"]:
		if rw.has(k):
			fx[k] = rw[k]
	if int(rw.get("xp", 0)) > 0:
		fx["xp"] = int(rw["xp"])
	if rw.has("learnFormChoice"):
		var unknown: Array = []
		for f in rw["learnFormChoice"]:
			if not p["knownForms"].has(f):
				unknown.append(f)
		if not unknown.is_empty():
			fx["learnForm"] = str(unknown[rng.randi_range(0, unknown.size() - 1)])
	lines.append_array(Fx.apply(db, run, fx, rng, {}))
	if rw.has("knowledgeTier") and int(p.get("knowledgeTier", 1)) < int(rw["knowledgeTier"]):
		p["knowledgeTier"] = int(rw["knowledgeTier"])
		for m in run.get("roster", []):
			m["knowledgeTier"] = maxi(int(m.get("knowledgeTier", 1)), int(rw["knowledgeTier"]))
		lines.append("Your Knowledge Tier rises to %d." % int(rw["knowledgeTier"]))
	for m in run.get("roster", []):
		if run.get("party_ids", []).has(m["id"]) and int(rw.get("xp", 0)) > 0:
			preload("res://src/core/progression/leveling.gd").add_xp(db, m, int(rw["xp"]), rng)
	return lines


## Members who sat tonight out catch up a little (DESIGN.md Section 11).
static func catch_up(db: Dictionary, run: Dictionary, xp: int, rng: RandomNumberGenerator) -> void:
	var share := float(db.get("leveling", {}).get("catchUpXpShare", 0.5))
	var lv := preload("res://src/core/progression/leveling.gd")
	for m in run.get("roster", []):
		if not run.get("party_ids", []).has(m["id"]):
			lv.add_xp(db, m, roundi(float(xp) * share), rng)
			lv.auto_perks(db, m)


static func end_night(run: Dictionary) -> void:
	run["floor"] = {}
	run["floor_room"] = 0

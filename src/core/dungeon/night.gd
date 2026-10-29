## What happens in each room of a night's floor: resting, treasure and Vector
## shards, the aftermath of a fight (encounter log, loot) and the boss reward.
class_name DungeonNight
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Char := preload("res://src/core/character.gd")
const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const Sig := preload("res://src/core/dungeon/signature.gd")
const VO := preload("res://src/core/vector_ops.gd")
const Enc := preload("res://src/core/dungeon/encounters.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("dungeon", {})


## Enemy records for a room's fight, scaled for the party's size
## (data/encounters.json "partyScale"): fewer, weaker enemies for a small
## party, never below 2, one more for a full party. Elite affixes are applied.
static func fight_enemies(db: Dictionary, room: Dictionary, party_size: int) -> Array:
	return fight_setup(db, room, party_size)["enemies"]


## Everything a room's fight needs: { "enemies": [records], "roles", "formation", "reinforcements" }.
static func fight_setup(db: Dictionary, room: Dictionary, party_size: int) -> Dictionary:
	var ids: Array = room.get("enemies", [])
	var t := str(room.get("type", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("party_scale:%s:%s" % [room.get("id", 0), str(ids)])
	var picks: Array = range(ids.size())
	var power := 1.0
	if t != "boss":
		var sc := Enc.scale_for_party(db, ids, party_size, rng)
		picks = sc["indices"]
		power = float(sc["power"])
	var idx := preload("res://src/core/data_tables.gd").index_under(db, "enemies/", "enemies")
	var roles_in: Array = room.get("roles", [])
	var affixes: Dictionary = room.get("affixes", {})
	var out: Array = []
	var roles: Array = []
	for i in picks:
		var rec: Dictionary = idx.get(str(ids[i]), {}).duplicate(true)
		if rec.is_empty():
			continue
		var base := 1.0 if t == "boss" else float(room.get("scale", 1.0))
		rec["scale"] = base * (1.0 if t == "boss" else power)
		var ax: Variant = affixes.get(i, affixes.get(str(i), []))
		if ax is Array and not (ax as Array).is_empty():
			rec["affixes"] = ax
		out.append(rec)
		roles.append(str(roles_in[i]) if i < roles_in.size() else "fighter")
	var reinf: Dictionary = room.get("reinforcements", {})
	var extra: Array = []
	for id in reinf.get("enemies", []):
		var rec: Dictionary = idx.get(str(id), {}).duplicate(true)
		if not rec.is_empty():
			rec["scale"] = float(room.get("scale", 1.0)) * power
			extra.append(rec)
	return { "enemies": out, "roles": roles, "formation": str(room.get("formation", "default")),
		"reinforcements": { "round": int(reinf.get("round", 3)), "enemies": extra } if not extra.is_empty() else {} }


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
		ch["mp"] = int(d["maxMp"]) + int(Char.collect_mods(db, ch).get("rest", {}).get("mpBonus", 0))
	room["cleared"] = true
	lines.append(Str.t(db, "night.you_rest_by_a_fire"))
	return lines


## Catch your breath after a won fight: everyone standing regains a share of max HP.
static func recover(db: Dictionary, run: Dictionary, share: float) -> void:
	if share <= 0.0:
		return
	for ch in party_chars(run):
		var d := Char.derived(db, ch)
		if int(ch.get("hp", 0)) > 0:
			ch["hp"] = mini(int(d["maxHp"]), int(ch.get("hp", 0)) + roundi(float(d["maxHp"]) * share))


## Fight rooms (combat, elite, boss) on the floor not won yet. The exit stays
## sealed until this is 0 (CT Part 6).
static func fights_left(floor_data: Dictionary) -> int:
	var n := 0
	for r in floor_data.get("rooms", []):
		if str(r.get("type", "")) in ["combat", "elite", "boss"] and not bool(r.get("cleared", false)):
			n += 1
	return n


## Fights that keep the exit shut: every fight room when data/dungeon.json
## "sealExitUntilCleared" is on, otherwise only the boss (the user's rule:
## you may leave a floor early, but not skip the week's boss).
static func exit_blockers(db: Dictionary, floor_data: Dictionary) -> int:
	if bool(db.get("dungeon", {}).get("sealExitUntilCleared", false)):
		return fights_left(floor_data)
	var n := 0
	for r in floor_data.get("rooms", []):
		if str(r.get("type", "")) == "boss" and not bool(r.get("cleared", false)):
			n += 1
	return n


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
	var lines: Array = [Str.t(db, "night.a_shard_hums_in_your") % axis.capitalize()]
	var shards: Dictionary = run.get("shards", {})
	shards[axis] = int(shards.get(axis, 0)) + 1
	run["shards"] = shards
	var p: Dictionary = run["player"]
	var tier := int(db.get("spaces", {}).get("arcane", {}).get("tiers", {}).get(axis, 1))
	if int(shards[axis]) >= int(cfg(db).get("shardsToLearn", 3)) and not p["knownVectors"].has(axis) and tier <= int(p.get("knowledgeTier", 1)):
		shards[axis] = 0
		p["knownVectors"].append(axis)
		lines.append(Str.t(db, "night.the_shards_fuse_you_know") % axis.capitalize())
	return lines


## The week's dominant axis, or a Sampled axis of its signature, for shards.
static func shard_axis(db: Dictionary, run: Dictionary, week: int, rng: RandomNumberGenerator) -> String:
	var sig := Sig.current(db, run, week)
	return VO.sample(sig, rng, db.get("spaces", {}).get("arcane", {}).get("axes", []))


static func open_treasure(db: Dictionary, run: Dictionary, room: Dictionary, week: int, rng: RandomNumberGenerator) -> Array:
	var t: Dictionary = cfg(db).get("treasure", {})
	var lines: Array = [Str.t(db, "night.the_chest_opens_with_a")]
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
		lines.append(Str.t(db, "night.you_got_away_they_ll"))
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
		lines.append(Str.t(db, "night.your_knowledge_tier_rises_to") % int(rw["knowledgeTier"]))
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

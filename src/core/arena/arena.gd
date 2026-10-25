## The Endless Arena (docs/ARENA.md Part 5): seeded waves of growing size from
## encounter templates, a new layout and hazard set every wave, elite waves
## every 5th and remixed bosses every 10th, checkpoints with Arena AP and
## mutators, rewards banked at checkpoints, and a score. Pure: an arena run is
## one Dictionary (in the run as run["arena"] or run["rift"]).
extends RefCounted

const DT := preload("res://src/core/data_tables.gd")
const VO := preload("res://src/core/vector_ops.gd")
const Enc := preload("res://src/core/dungeon/encounters.gd")
const EnemyMods := preload("res://src/core/combat/enemy_mods.gd")
const Char := preload("res://src/core/character.gd")


static func waves(db: Dictionary) -> Dictionary:
	return db.get("arena/waves", {})


static func new_arena(seed_value: int, story: bool) -> Dictionary:
	return { "seed": seed_value, "wave": 0, "ap": 0, "score": 0, "mutators": [], "offered": [], "story": story,
		"pending": { "xp": 0, "money": 0, "shards": 0, "cards": [] }, "banked": { "xp": 0, "money": 0, "shards": 0, "cards": [] },
		"over": false, "cleared": 0 }


## A stable rng per arena run, wave and purpose (same seed, same waves).
static func rng_for(arena: Dictionary, wave: int, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("arena:%d:%d:%s" % [int(arena.get("seed", 0)), wave, salt])
	return rng


## Which week's enemies a wave draws from.
static func week_for_wave(db: Dictionary, wave: int) -> int:
	var week := 1
	for pair in waves(db).get("waveForWeek", [[1, 1]]):
		if wave >= int(pair[0]):
			week = int(pair[1])
	return week


static func is_boss(db: Dictionary, wave: int) -> bool:
	return wave > 0 and wave % int(waves(db).get("bossEvery", 10)) == 0


static func is_elite(db: Dictionary, wave: int) -> bool:
	return wave > 0 and wave % int(waves(db).get("eliteEvery", 5)) == 0 and not is_boss(db, wave)


static func budget(db: Dictionary, wave: int) -> float:
	var w := waves(db)
	return minf(float(w.get("maxCount", 10)), float(w.get("baseCount", 3)) + float(w.get("perWave", 0.4)) * float(wave - 1))


## The hazard set for a wave: the sets in order, so every hazard comes up.
static func hazard_set(db: Dictionary, wave: int) -> Dictionary:
	var sets: Array = db.get("arena/layouts", {}).get("hazardSets", [])
	if sets.is_empty():
		return {}
	return sets[(wave - 1) % sets.size()]


## A layout for the wave: a base map with the wave's hazards scattered over
## the middle (seeded), as a combat layout record.
static func layout_for(db: Dictionary, arena: Dictionary, wave: int) -> Dictionary:
	var rng := rng_for(arena, wave, "layout")
	var bases: Array = db.get("arena/layouts", {}).get("layouts", [])
	var base: Dictionary = bases[rng.randi_range(0, bases.size() - 1)] if not bases.is_empty() else { "map": ["P.......E"] }
	var rows: Array = []
	for line in base["map"]:
		rows.append(str(line))
	var hz := hazard_set(db, wave)
	var cols := str(rows[0]).length()
	var middle: Array = []
	for r in rows.size():
		for c in range(2, cols - 2):
			if str(rows[r])[c] == ".":
				middle.append(Vector2i(c, r))
	if hz.has("row"):
		var r := rows.size() / 2
		var line := str(rows[r])
		for c in range(2, cols - 2):
			if line[c] == ".":
				line = line.substr(0, c) + str(hz["row"]) + line.substr(c + 1)
		rows[r] = line
	var place := func(letter: String, n: int) -> void:
		for i in mini(n, middle.size()):
			var cell: Vector2i = middle.pop_at(rng.randi_range(0, middle.size() - 1))
			var line := str(rows[cell.y])
			rows[cell.y] = line.substr(0, cell.x) + letter + line.substr(cell.x + 1)
	if hz.has("letter"):
		place.call(str(hz["letter"]), int(hz.get("sprinkle", 4)))
	if hz.has("extra"):
		place.call(str(hz["extra"]["letter"]), int(hz["extra"].get("count", 1)))
	return { "id": "arena_%d" % wave, "theme": "arena", "map": rows, "hazard": str(hz.get("id", "")) }


## The wave's enemies: { "enemies": [records], "roles", "formation", "boss" }.
static func wave_enemies(db: Dictionary, arena: Dictionary, wave: int) -> Dictionary:
	var rng := rng_for(arena, wave, "enemies")
	var w := waves(db)
	var week := week_for_wave(db, wave)
	var idx := DT.index_under(db, "enemies/", "enemies")
	var hp_mul := 1.0 + float(w.get("hpPerWave", 0.05)) * float(wave - 1)
	var power := 1.0 + float(w.get("powerPerWave", 0.04)) * float(wave - 1)
	if is_boss(db, wave):
		var bosses: Array = w.get("bosses", [])
		var cycle := wave / int(w.get("bossEvery", 10))
		var rec: Dictionary = idx.get(str(bosses[(cycle - 1) % bosses.size()]), {}).duplicate(true)
		rec["affixes"] = EnemyMods.roll(db, mini(6, int(w.get("bossAffixesPerCycle", 1)) * cycle), rng)
		rec["hp"] = roundi(float(rec.get("hp", 50)) * hp_mul)
		rec["scale"] = power
		return { "enemies": [rec], "roles": ["boss"], "formation": "default", "boss": true }
	var room := "elite" if is_elite(db, wave) else "combat"
	var mixed := wave > int(w.get("mixedAfter", 10))
	var enc := Enc.build(db, {}, week, room, rng, budget(db, wave), rng.randi_range(1, 5) if mixed else week)
	var recs: Array = []
	for i in enc["enemies"].size():
		var rec: Dictionary = idx.get(str(enc["enemies"][i]), {}).duplicate(true)
		if rec.is_empty():
			continue
		var ax: Variant = enc["affixes"].get(i, [])
		if ax is Array and not (ax as Array).is_empty():
			rec["affixes"] = ax
		rec["hp"] = roundi(float(rec.get("hp", 10)) * hp_mul)
		rec["scale"] = power
		recs.append(rec)
	return { "enemies": recs, "roles": enc["roles"], "formation": enc["formation"], "boss": false, "template": enc["template"] }


## Combat setup for a wave (the scene adds the party).
static func setup_for_wave(db: Dictionary, arena: Dictionary, wave: int) -> Dictionary:
	var we := wave_enemies(db, arena, wave)
	return { "layout": layout_for(db, arena, wave), "enemies": we["enemies"], "roles": we["roles"], "formation": we["formation"],
		"boss": bool(we["boss"]), "fleeAllowed": false, "context": "arena", "mutators": arena.get("mutators", []) }


## Merged mutator effects (same rules as in combat).
static func mutator_effect(arena: Dictionary, key: String, fallback: Variant) -> Variant:
	var out: Variant = fallback
	for m in arena.get("mutators", []):
		var v: Variant = m.get("effects", {}).get(key, null)
		if v == null:
			continue
		if v is bool:
			out = bool(out) or v
		elif key.ends_with("Mul"):
			out = float(out) * float(v)
		else:
			out = float(out) + float(v)
	return out


## A wave is won: score and pending rewards. `stats` = { rounds, damageTaken, multiVector }.
static func wave_won(db: Dictionary, arena: Dictionary, stats: Dictionary) -> Array:
	var w := waves(db)
	var sc: Dictionary = w.get("score", {})
	var lines: Array = []
	var wave := int(arena["wave"])
	var points := int(sc.get("perWave", 10))
	if int(stats.get("damageTaken", 1)) == 0:
		points += int(sc.get("noDamage", 5))
		lines.append("No damage taken!")
	if int(stats.get("rounds", 99)) <= int(sc.get("fastRounds", 4)):
		points += int(sc.get("fastClear", 3))
		lines.append("Fast clear!")
	points += int(stats.get("multiVector", 0)) * int(sc.get("multiVector", 2))
	points += arena.get("mutators", []).size() * int(sc.get("perMutator", 3))
	points = roundi(float(points) * float(mutator_effect(arena, "scoreMul", 1.0)))
	arena["score"] = int(arena["score"]) + points
	arena["cleared"] = wave
	var mul := float(mutator_effect(arena, "rewardMul", 1.0))
	var rw: Dictionary = w.get("rewards", {})
	var p: Dictionary = arena["pending"]
	p["xp"] = int(p["xp"]) + roundi(float(rw.get("xpPerWave", 6)) * mul)
	p["money"] = int(p["money"]) + roundi(float(rw.get("moneyPerWave", 3)) * mul)
	if wave % int(rw.get("shardEvery", 5)) == 0:
		p["shards"] = int(p["shards"]) + 1
	if wave % int(rw.get("cardEvery", 5)) == 0:
		var cards: Array = rw.get("cards", [])
		if not cards.is_empty():
			p["cards"].append(cards[rng_for(arena, wave, "card").randi_range(0, cards.size() - 1)])
	lines.push_front("Wave %d cleared: +%d points." % [wave, points])
	return lines


static func checkpoint_cfg(db: Dictionary) -> Dictionary:
	return db.get("arena/checkpoint", {})


static func is_checkpoint(db: Dictionary, wave: int) -> bool:
	return wave > 0 and wave % int(checkpoint_cfg(db).get("every", 5)) == 0


## Reach a checkpoint: Arena AP, rewards banked, old mutators end, new ones offered.
## Returns the rewards banked now (for story mode to apply).
static func checkpoint(db: Dictionary, arena: Dictionary) -> Dictionary:
	arena["ap"] = int(arena["ap"]) + int(checkpoint_cfg(db).get("apPerCheckpoint", 3))
	var banked: Dictionary = arena["pending"].duplicate(true)
	for k in ["xp", "money", "shards"]:
		arena["banked"][k] = int(arena["banked"][k]) + int(banked[k])
	arena["banked"]["cards"].append_array(banked["cards"])
	arena["pending"] = { "xp": 0, "money": 0, "shards": 0, "cards": [] }
	arena["noRest"] = bool(mutator_effect(arena, "noRest", false))
	arena["mutators"] = []
	offer_mutators(db, arena, 0)
	return banked


## Offer `mutatorChoices` mutators, seeded (rerolls get a new salt).
static func offer_mutators(db: Dictionary, arena: Dictionary, reroll: int) -> void:
	var pool: Array = db.get("arena/mutators", {}).get("mutators", []).duplicate()
	var rng := rng_for(arena, int(arena["wave"]), "mutators%d" % reroll)
	var out: Array = []
	for i in mini(int(checkpoint_cfg(db).get("mutatorChoices", 3)), pool.size()):
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	arena["offered"] = out
	arena["rerolls"] = reroll


static func choose_mutator(arena: Dictionary, id: String) -> bool:
	for m in arena.get("offered", []):
		if str(m["id"]) == id:
			arena["mutators"] = [m]
			arena["offered"] = []
			arena["mutatorsTaken"] = int(arena.get("mutatorsTaken", 0)) + 1
			return true
	return false


## Spend Arena AP on a checkpoint action ("rest", "swapCard"...). False if it can't be afforded.
static func spend(db: Dictionary, arena: Dictionary, action: String) -> bool:
	var cost := int(checkpoint_cfg(db).get("costs", {}).get(action, 99))
	if action == "rest" and bool(arena.get("noRest", false)):
		return false
	if int(arena["ap"]) < cost:
		return false
	arena["ap"] = int(arena["ap"]) - cost
	return true


## Rest: everyone back up to restPct of max HP and MP (on top of what they have).
static func rest(db: Dictionary, party: Array) -> void:
	var pct := float(checkpoint_cfg(db).get("restPct", 0.5))
	for ch in party:
		var d := Char.derived(db, ch)
		ch["hp"] = mini(int(d["maxHp"]), int(ch.get("hp", 0)) + roundi(float(d["maxHp"]) * pct))
		ch["mp"] = mini(int(d["maxMp"]), int(ch.get("mp", 0)) + roundi(float(d["maxMp"]) * pct))


## Between waves: MP back a little, no healing.
static func breather(db: Dictionary, party: Array) -> void:
	for ch in party:
		var d := Char.derived(db, ch)
		ch["mp"] = mini(int(d["maxMp"]), int(ch.get("mp", 0)) + int(waves(db).get("breatherMp", 3)))


## Best scores, keyed by party size and mutator count. Returns true for a new best.
static func record_score(scores: Dictionary, arena: Dictionary, party_size: int) -> bool:
	var key := "party%d_mut%d" % [party_size, int(arena.get("mutatorsTaken", 0))]
	var prev: Dictionary = scores.get(key, {})
	if int(arena["score"]) > int(prev.get("score", -1)):
		scores[key] = { "score": int(arena["score"]), "wave": int(arena["cleared"]) }
		return true
	return false

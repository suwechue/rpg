## The Endless Arena (docs/ARENA.md Part 5): seeded waves of growing size from
## encounter templates, a new layout and hazard set every wave, elite waves
## every 5th and remixed bosses every 10th, checkpoints with Arena AP and
## mutators, rewards banked at checkpoints, and a score. Pure: an arena run is
## one Dictionary (in the run as run["arena"] or run["rift"]).
extends RefCounted

const Crafting := preload("res://src/core/progression/crafting.gd")
const CardRules := preload("res://src/core/card.gd")
const Str := preload("res://src/core/strings.gd")

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
static func hazard_set(db: Dictionary, wave: int, arena: Dictionary = {}) -> Dictionary:
	var sets: Array = db.get("arena/layouts", {}).get("hazardSets", [])
	if sets.is_empty():
		return {}
	# Block themes (user request): every wave of a block uses its theme's hazards.
	var th := theme_for(db, arena, wave)
	for s in sets:
		if str(s.get("id", "")) == str(th.get("hazard", "")):
			return s
	return sets[(wave - 1) % sets.size()]


## The theme of a wave's block (waves 1-5, 6-10, ...): seeded per arena run, no
## theme twice in a row. {} if there are no themes in data.
static func theme_for(db: Dictionary, arena: Dictionary, wave: int) -> Dictionary:
	var th: Dictionary = waves(db).get("themes", {})
	var list: Array = th.get("list", [])
	if list.is_empty():
		return {}
	var size := maxi(1, int(th.get("blockSize", 5)))
	var block := (maxi(1, wave) - 1) / size
	var prev := -1
	var pick := 0
	for b in block + 1:
		var rng := rng_for(arena if not arena.is_empty() else { "seed": 1 }, b + 1, "theme")
		pick = rng.randi_range(0, list.size() - 1)
		if pick == prev:
			pick = (pick + 1) % list.size()
		prev = pick
	return list[pick]


## A layout for the wave: a base map with the wave's hazards scattered over
## the middle (seeded), as a combat layout record.
static func layout_for(db: Dictionary, arena: Dictionary, wave: int) -> Dictionary:
	var rng := rng_for(arena, wave, "layout")
	var bases: Array = db.get("arena/layouts", {}).get("layouts", [])
	var base: Dictionary = bases[rng.randi_range(0, bases.size() - 1)] if not bases.is_empty() else { "map": ["P.......E"] }
	var rows: Array = []
	for line in base["map"]:
		rows.append(str(line))
	var hz := hazard_set(db, wave, arena)
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
	# The block's theme leans the enemy pick toward its Vectors.
	var theme := theme_for(db, arena, wave)
	var lean_run := { "signature": {}, "themeLean": float(waves(db).get("themes", {}).get("lean", 3.0)) }
	for axis in theme.get("vectors", {}):
		lean_run["signature"][axis] = float(theme["vectors"][axis]) * 5.0
	var enc := Enc.build(db, lean_run, week, room, rng, budget(db, wave), rng.randi_range(1, 5) if mixed else week)
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
		lines.append(Str.t(db, "arena.no_damage_taken"))
	if int(stats.get("rounds", 99)) <= int(sc.get("fastRounds", 4)):
		points += int(sc.get("fastClear", 3))
		lines.append(Str.t(db, "arena.fast_clear"))
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
	lines.push_front(Str.t(db, "arena.wave_cleared_points") % [wave, points])
	return lines


## PT Part 6: three cards to pick from after a wave, weighted toward the party's
## Vectors, rarer as the waves go up, sometimes a Vector nobody knows yet.
static func card_offer(db: Dictionary, arena: Dictionary, party: Array, wave: int) -> Array:
	var cr: Dictionary = waves(db).get("cardReward", {})
	var rng := rng_for(arena, wave, "offer")
	var known := {}
	for ch in party:
		for v in ch.get("knownVectors", []):
			known[str(v)] = true
	var t := clampf(float(wave) / float(maxi(1, int(cr.get("lateWave", 20)))), 0.0, 1.0)
	var deck_tags := {}
	for ch in party:
		for id in ch.get("deck", []):
			var tg0 := CardRules.tags(db, CardRules.resolve(db, str(id)))
			for k in tg0["setsUp"] + tg0["paysOff"]:
				deck_tags[k] = true
	var early: Dictionary = cr.get("rarityWeights", {}).get("early", {})
	var late: Dictionary = cr.get("rarityWeights", {}).get("late", {})
	var pool: Array = []
	var weights: Array = []
	var fresh: Array = []
	for c in DT.records_under(db, "cards/", "cards"):
		if str(c.get("kind", "")) == "item" or str(c.get("id", "")) in ["card_strike", "card_guard"] or str(c.get("id", "")).begins_with("card_ember") or str(c.get("id", "")).begins_with("card_heat_shield") or str(c.get("id", "")).begins_with("card_frost_line"):
			continue
		var r := str(c.get("rarity", "common"))
		var w := lerpf(float(early.get(r, 1)), float(late.get(r, 1)), t)
		var axes: Array = c.get("vectors", {}).keys()
		var party_axis := axes.is_empty()
		for a in axes:
			party_axis = party_axis or known.has(str(a))
		if not axes.is_empty() and not party_axis:
			fresh.append(str(c["id"]))
			continue
		if not axes.is_empty():
			w *= float(cr.get("partyVectorWeight", 3.0))
		# Lean toward cards that pay off what the party's decks set up (and back).
		var tg := CardRules.tags(db, c)
		for tag in tg["paysOff"] + tg["setsUp"]:
			if deck_tags.has(tag):
				w *= float(cr.get("synergyWeight", 1.5))
				break
		pool.append(str(c["id"]))
		weights.append(w)
	var out: Array = []
	var n := int(cr.get("choices", 3))
	if not fresh.is_empty() and rng.randf() < float(cr.get("newVectorChance", 0.2)):
		out.append(fresh[rng.randi_range(0, fresh.size() - 1)])
	var guard := 0
	while out.size() < n and not pool.is_empty() and guard < 200:
		guard += 1
		var total := 0.0
		for w in weights:
			total += float(w)
		var roll := rng.randf() * total
		for i in pool.size():
			roll -= float(weights[i])
			if roll <= 0.0:
				if not out.has(pool[i]):
					out.append(pool[i])
				break
	return out


## Everyone who could take a card (P2 1.3): [{ id, name, ok, reason, deck, hint }],
## the player first, then the roster.
static func eligible_owners(db: Dictionary, run: Dictionary, card: Dictionary) -> Array:
	var out: Array = []
	for ch in [run.get("player", {})] + run.get("roster", []):
		if (ch as Dictionary).is_empty():
			continue
		var why := Crafting.eligibility(db, ch, card)
		var hint := ""
		if str(card.get("pool", "")) != "":
			hint = Str.t(db, "owner.hint_pool")
		elif CardRules.is_spell(card):
			hint = Str.t(db, "owner.hint_knows") % ", ".join(PackedStringArray(card.get("vectors", {}).keys())).capitalize()
		else:
			hint = Str.t(db, "owner.hint_basic")
		out.append({ "id": str(ch.get("id", "")), "name": str(ch.get("name", "?")), "ok": why == "" and Crafting.copies_ok(db, ch.get("deck", []), str(card.get("id", ""))),
			"reason": why, "deck": ch.get("deck", []).size(), "hint": hint })
	return out


## Take an offered card into the collection (for the score) and, with a member
## id, straight into that member's deck (P2 1.3). "" keeps it in the collection.
static func pick_card(db: Dictionary, arena: Dictionary, run: Dictionary, card_id: String, member_id: String = "") -> bool:
	var card := CardRules.resolve(db, card_id, run.get("cards", {}))
	var owner: Dictionary = {}
	if member_id != "":
		for ch in [run.get("player", {})] + run.get("roster", []):
			if str(ch.get("id", "")) == member_id:
				owner = ch
		if owner.is_empty() or Crafting.eligibility(db, owner, card) != "":
			return false
	var coll: Dictionary = run.get("collection", {})
	coll[card_id] = int(coll.get(card_id, 0)) + 1
	run["collection"] = coll
	if not owner.is_empty():
		var deck: Array = owner.get("deck", [])
		deck.append(card_id)
		owner["deck"] = deck
	arena["picked"] = arena.get("picked", []) + [card_id]
	arena["lastPick"] = { "card": card_id, "member": member_id, "offer": arena.get("offer", []).duplicate() }
	arena["offer"] = []
	return true


## Undo the last pick until the next wave starts: the card goes back to the offer.
static func undo_pick(arena: Dictionary, run: Dictionary) -> bool:
	var lp: Dictionary = arena.get("lastPick", {})
	if lp.is_empty():
		return false
	var cid := str(lp["card"])
	run["collection"][cid] = int(run["collection"].get(cid, 1)) - 1
	if int(run["collection"][cid]) <= 0:
		run["collection"].erase(cid)
	for ch in [run.get("player", {})] + run.get("roster", []):
		if str(ch.get("id", "")) == str(lp["member"]):
			(ch["deck"] as Array).erase(cid)
	arena["picked"].erase(cid)
	arena["offer"] = lp["offer"]
	arena.erase("lastPick")
	return true


## Autoplay's owner: the eligible member with the smallest deck, ties broken by tag fit.
static func auto_owner(db: Dictionary, run: Dictionary, card: Dictionary) -> String:
	var best := ""
	var best_key := 99999.0
	var tg := CardRules.tags(db, card)
	for o in eligible_owners(db, run, card):
		if not bool(o["ok"]):
			continue
		var fit := 0
		for ch in [run.get("player", {})] + run.get("roster", []):
			if str(ch.get("id", "")) == str(o["id"]):
				for id in ch.get("deck", []):
					var t2 := CardRules.tags(db, CardRules.resolve(db, str(id)))
					for k in tg["paysOff"] + tg["setsUp"]:
						if t2["setsUp"].has(k) or t2["paysOff"].has(k):
							fit += 1
		var key := float(o["deck"]) - float(fit) * 0.01
		if key < best_key:
			best_key = key
			best = str(o["id"])
	return best


## Skip the offer for Scraps.
static func skip_offer(db: Dictionary, arena: Dictionary, run: Dictionary) -> Dictionary:
	var gain: Dictionary = waves(db).get("cardReward", {}).get("skipScraps", { "generic": 2 })
	if not run.has("scraps"):
		run["scraps"] = {}
	for k in gain:
		run["scraps"][k] = int(run["scraps"].get(k, 0)) + int(gain[k])
	arena["offer"] = []
	return gain


## Checkpoint pick (PT Parts 6 and 8): Techniques this member could take now.
static func perk_offer(db: Dictionary, arena: Dictionary, ch: Dictionary) -> Array:
	var out: Array = preload("res://src/core/progression/leveling.gd").technique_options(db, ch)
	var rng := rng_for(arena, int(arena.get("wave", 0)), "perk" + str(ch.get("id", "")))
	var n := int(waves(db).get("checkpointPick", {}).get("choices", 2))
	var picked: Array = []
	while picked.size() < n and not out.is_empty():
		picked.append(out.pop_at(rng.randi_range(0, out.size() - 1)))
	return picked


static func take_perk(arena: Dictionary, ch: Dictionary, perk_id: String) -> void:
	ch["techniques"] = ch.get("techniques", []) + [perk_id]
	arena["perksTaken"] = arena.get("perksTaken", []) + [perk_id]
	arena["perkPicked"] = int(arena.get("wave", 0))


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
	arena["mutatorWave"] = int(arena.get("wave", 0))
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
	for ch in party:
		# Meditative Reserve (PT Part 8): +3 MP at checkpoints.
		ch["mp"] = int(ch.get("mp", 0)) + int(Char.collect_mods(db, ch).get("rest", {}).get("mpBonus", 0))
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

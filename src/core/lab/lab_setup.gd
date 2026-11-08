## Builds Lab fights from data/lab/fights.json: a throwaway party (never the
## player's save) and a combat setup that names a preset. Pure: no autoloads.
extends RefCounted

const Char := preload("res://src/core/character.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const DT := preload("res://src/core/data_tables.gd")
const Rules := preload("res://src/core/combat/rules.gd")
const PointBuy := preload("res://src/core/progression/point_buy.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("lab/lab", {})


static func fights(db: Dictionary) -> Array:
	return db.get("lab/fights", {}).get("fights", [])


static func fight(db: Dictionary, id: String) -> Dictionary:
	for f in fights(db):
		if str(f.get("id", "")) == id:
			return f
	return {}


## The picks for a fight: its own party, or the given one, or the default.
static func picks_for(db: Dictionary, f: Dictionary, chosen: Array = []) -> Array:
	if not chosen.is_empty():
		return chosen
	if not f.get("party", []).is_empty():
		return f["party"]
	return cfg(db).get("defaultParty", [])


## The deck a pick uses under these levers.
static func deck_for(db: Dictionary, pick: Dictionary, rules: RefCounted, ch: Dictionary) -> Array:
	var ids: Array = ch.get("deck", [])
	if pick.has("deck"):
		ids = pick["deck"]
	elif rules.text("classDecks", "game") == "lab":
		ids = cfg(db).get("classDecks", {}).get(str(pick.get("class", "")), ids)
	ids = ids.duplicate()
	var pool: Array = cfg(db).get("keywordCards", [])
	for i in mini(rules.count("extraKeywordCards"), pool.size()):
		ids.append(pool[i])
	return ids


## A throwaway run: the first pick is the player, the rest fill the party.
static func make_run(db: Dictionary, seed_value: int, picks: Array, rules: RefCounted) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var first: Dictionary = picks[0] if not picks.is_empty() else { "class": "mage", "level": 1 }
	var run := RM.new_run(db, seed_value, str(first.get("class", "mage")), rng)
	run["mode"] = "lab"
	run["player"]["name"] = str(cfg(db).get("names", {}).get(str(first.get("class", "")), "Lab"))
	var members: Array = [[run["player"], first]]
	for i in range(1, picks.size()):
		var pick: Dictionary = picks[i]
		var cls := str(pick.get("class", "mage"))
		var ch := Char.create(db, cls, rng, { "id": "lab_%d_%s" % [i, cls], "name": str(cfg(db).get("names", {}).get(cls, cls.capitalize())) })
		ch["sprite"] = str(db.get("assets/roles", {}).get("arena_" + cls, db.get("assets/roles", {}).get("debugAlly", "")))
		run["roster"].append(ch)
		run["party_ids"].append(ch["id"])
		run["bonds"][ch["id"]] = 50.0
		members.append([ch, pick])
	for m in members:
		var ch: Dictionary = m[0]
		var pick: Dictionary = m[1]
		PointBuy.apply_to(db, ch, PointBuy.recommended(db, str(ch.get("class", "mage"))))
		while int(ch["level"]) < int(pick.get("level", 1)):
			Lv.add_xp(db, ch, Lv.xp_to_next(db, int(ch["level"])), rng)
		Lv.auto_perks(db, ch)
		Char.full_restore(db, ch)
		ch["deck"] = deck_for(db, pick, rules, ch)
	var all_members: Array = members.map(func(m: Array) -> Dictionary: return m[0])
	if rules.flag("bondInCombat"):
		for a in all_members:
			var bonds: Dictionary = {}
			for b in all_members:
				if a != b:
					bonds[str(b["id"])] = float(db.get("lab/extras", {}).get("labBond", 80))
			a["partyBonds"] = bonds
	if rules.flag("duetCards"):
		for card in db.get("cards/duet_cards", {}).get("cards", []):
			var need: Array = card.get("duet", [])
			var holders: Array = all_members.filter(func(m: Dictionary) -> bool: return need.has(str(m.get("class", ""))))
			if holders.size() >= 2:
				holders[0]["deck"].append(str(card["id"]))
	return run


## A benched member for the reserves lever: a class the party doesn't have.
static func reserve_for(db: Dictionary, f: Dictionary, picks: Array, seed_value: int, rules: RefCounted) -> Array:
	var used: Array = picks.map(func(p: Dictionary) -> String: return str(p.get("class", "")))
	var cls := str(f.get("reserve", ""))
	if cls == "":
		for c in db.get("classes", {}).get("classes", []):
			if int(c.get("tier", 1)) == 1 and not used.has(str(c["id"])):
				cls = str(c["id"])
				break
	if cls == "":
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1
	var pick := { "class": cls, "level": int(picks[0].get("level", 1)) if not picks.is_empty() else 1 }
	var ch := Char.create(db, cls, rng, { "id": "lab_reserve_" + cls, "name": str(cfg(db).get("names", {}).get(cls, cls.capitalize())) })
	ch["sprite"] = str(db.get("assets/roles", {}).get("arena_" + cls, db.get("assets/roles", {}).get("debugAlly", "")))
	PointBuy.apply_to(db, ch, PointBuy.recommended(db, cls))
	while int(ch["level"]) < int(pick["level"]):
		Lv.add_xp(db, ch, Lv.xp_to_next(db, int(ch["level"])), rng)
	Lv.auto_perks(db, ch)
	Char.full_restore(db, ch)
	ch["deck"] = deck_for(db, pick, rules, ch)
	return [ch]


## The fight's enemy records: ids or { "id", "hp", "immovable", ... } overrides.
static func enemies_for(db: Dictionary, f: Dictionary, rules: RefCounted) -> Array:
	var index := DT.index_under(db, "enemies/", "enemies")
	var out: Array = []
	for e in f.get("enemies", []):
		var entry: Dictionary = e if typeof(e) == TYPE_DICTIONARY else { "id": str(e) }
		var rec: Dictionary = index.get(str(entry.get("id", "")), {}).duplicate(true)
		if rec.is_empty():
			continue
		for k in entry:
			if str(k) != "id":
				rec[k] = entry[k]
		out.append(rec)
	var tier: int = rules.count("enemyAbilitiesTier", 3)
	for rec in out:
		var kept: Array = rec.get("actions", []).filter(func(a: Dictionary) -> bool: return int(a.get("abilityTier", 1)) <= tier)
		if not kept.is_empty():
			rec["actions"] = kept
	var cap: int = rules.count("enemyCount")
	if cap > 0 and out.size() > cap:
		out = out.slice(0, cap)
	var base := out.size()
	for i in rules.count("extraEnemies"):
		if base > 0:
			out.append((out[i % base] as Dictionary).duplicate(true))
	return out


## Everything the combat scene needs, plus "run" (the throwaway run to play it in).
static func build(db: Dictionary, fight_id: String, preset_id: String, overrides: Dictionary = {}, chosen: Array = [], seed_override: int = -1, extra: Dictionary = {}) -> Dictionary:
	var f := fight(db, fight_id)
	# A fight's suggested levers, under every preset but today's rules.
	var levers: Dictionary = {} if preset_id == Rules.CURRENT else f.get("levers", {}).duplicate()
	levers.merge(overrides, true)
	var rules: RefCounted = Rules.build(db, preset_id, levers)
	if rules.flag("fightScaled"):
		# This preset's difficulty step for this fight; a change made by hand still wins.
		levers.merge(db.get("lab/fight_scales", {}).get("scales", {}).get(preset_id, {}).get(fight_id, {}), true)
		levers.merge(overrides, true)
		rules = Rules.build(db, preset_id, levers)
	var seed_value: int = seed_override if seed_override >= 0 else int(f.get("seed", 1))
	var picks := picks_for(db, f, chosen)
	var run := make_run(db, seed_value, picks, rules)
	var party: Array = [{ "char": run["player"] }]
	for pid in run["party_ids"]:
		party.append({ "char": RM.character(run, str(pid)) })
	var setup := {
		"layout": { "map": f.get("map", []), "theme": str(f.get("theme", "school")), "props": f.get("props", []), "high": f.get("high", []), "fog": f.get("fog", []) },
		"party": party,
		"enemies": enemies_for(db, f, rules),
		"boss": bool(f.get("boss", false)),
		"library": run.get("cards", {}),
		"difficulty": "normal",
		"ramp": 1.0,
		"backpack": [],
		"preset": preset_id,
		"levers": levers,
		"goal": f.get("goal", { "type": "kill" }),
		"fleeAllowed": false,
		"seed": seed_value,
		"lab": { "fight": fight_id, "preset": preset_id, "picks": picks, "seed": seed_value },
		"intro": str(f.get("intro", "")),
		"context": "lab",
	}
	for k in ["reinforcements", "formation", "roles", "objects", "waves", "timer", "weather", "phaseEvents"]:
		if f.has(k):
			setup[k] = f[k]
	setup.merge(extra, true)
	if rules.flag("reserves"):
		setup["reserves"] = reserve_for(db, f, picks, seed_value, rules)
	return { "setup": setup, "run": run, "rules": rules }

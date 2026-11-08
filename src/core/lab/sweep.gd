## One headless Lab fight for the sweeps (docs/LAB_TUNER.md Part 1): a fight, a
## preset or lever set, a seed, a party and an AI profile in; one log line out,
## with the same fields as a human Lab fight plus the AI's turn records (Part 3).
## A fight that runs past the stall limit ends as "stall". Plain data: no autoloads.
extends RefCounted

const StateScript := preload("res://src/core/combat/combat_state.gd")
const Setup := preload("res://src/core/lab/lab_setup.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const Player := preload("res://src/core/lab/players/player.gd")
const Legal := preload("res://src/core/lab/players/legal.gd")


static func tuner(db: Dictionary) -> Dictionary:
	return db.get("lab/tuner", {})


## A party composition by name (tuner.json "parties"), sized like the fight's own.
static func picks_for(db: Dictionary, fight_id: String, comp: String) -> Array:
	var f := Setup.fight(db, fight_id)
	var own: Array = Setup.picks_for(db, f)
	if comp == "" or comp == "balanced":
		return []
	var classes: Array = tuner(db).get("parties", {}).get(comp, [])
	if classes.is_empty():
		return []
	var out: Array = []
	for i in own.size():
		out.append({ "class": str(classes[i % classes.size()]), "level": int(own[i].get("level", 3)) })
	return out


## A value as text, the same before and after a trip through JSON (2 and 2.0 match).
static func norm(v: Variant) -> String:
	if typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)) and absf(float(v)) < 1e9:
		return str(int(v))
	return str(v)


## A stable id for a cell, so a stopped sweep can skip what it already ran.
static func cell_key(cell: Dictionary) -> String:
	var levers: Dictionary = cell.get("levers", {})
	var keys: Array = levers.keys()
	keys.sort()
	var lv: Array = []
	for k in keys:
		lv.append("%s=%s" % [k, norm(levers[k])])
	return "%s|%s|%s|%d|%s|%s" % [cell.get("fight", ""), cell.get("preset", ""), ",".join(PackedStringArray(lv)), int(cell.get("seed", 1)),
		cell.get("profile", ""), cell.get("party", "balanced")]


## Play one cell. cell: { fight, preset, levers, seed, profile, party }.
static func run_fight(db: Dictionary, cell: Dictionary) -> Dictionary:
	var cfg := tuner(db)
	var fight_id := str(cell.get("fight", ""))
	var seed_value := int(cell.get("seed", 1))
	var prof_id := str(cell.get("profile", "expert"))
	var built := Setup.build(db, fight_id, str(cell.get("preset", "cl_base")), cell.get("levers", {}), picks_for(db, fight_id, str(cell.get("party", ""))), seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st: Object = StateScript.new(db, rng, built["setup"])
	st.no_undo = true
	var prng := RandomNumberGenerator.new()
	prng.seed = hash([seed_value, prof_id, fight_id])
	var prof := Player.profile(db, prof_id)
	var stall_rounds := int(cfg.get("stallRounds", 30))
	var max_steps := int(cfg.get("maxSteps", 2000))
	var steps := 0
	var turns: Array = []
	var m := { "threatened": 0, "minHp": 1.0, "behind": false, "boardKills": 0, "teamwork": 0, "plays": {}, "opening": [] }
	var party_max := 0
	for x in st.units:
		if x.team == "party" and not x.is_prop() and not bool(x.source.get("object", false)):
			party_max += x.max_hp
	var t0 := Time.get_ticks_usec()
	while st.result == "" and st.current != null and st.round_num <= stall_rounds and steps < max_steps:
		steps += 1
		var u: Object = st.current
		if u.team == "party" and not u.ai_controlled:
			_turn_start(st, u, m, party_max)
			var rec: Dictionary = Player.take_turn(st, prof, prng)
			turns.append(rec)
			_count_plays(st, rec, m)
		else:
			AI.take_turn(st, u)
		for e in st.take_events():
			_observe(st, e, m)
	var result: String = st.result if st.result != "" else "stall"
	var line: Dictionary = st.lab_log.line(result, st.round_num) if st.lab_log != null else { "result": result, "rounds": st.round_num }
	line.erase("turns")
	line["kind"] = "sweep"
	line["profile"] = prof_id
	line["party"] = str(cell.get("party", "balanced"))
	line["leverSet"] = cell.get("levers", {})
	line["key"] = cell_key(cell)
	line["group"] = str(cell.get("group", ""))
	line["fight"] = fight_id
	line["usec"] = Time.get_ticks_usec() - t0
	line["boss"] = bool(Setup.fight(db, fight_id).get("boss", false))
	line["ai"] = turns
	line["threatened"] = m["threatened"]
	line["minPartyHp"] = snappedf(float(m["minHp"]), 0.01)
	line["comeback"] = bool(m["behind"]) and result == "win"
	line["kills"] = st.units.filter(func(x: Object) -> bool: return x.team == "enemy" and not x.is_prop() and x.dead).size()
	line["boardKills"] = m["boardKills"]
	line["teamwork"] = m["teamwork"] + int(line.get("combos", 0))
	line["plays"] = m["plays"]
	line["opening"] = "|".join(PackedStringArray(m["opening"]))
	line["partyHpLeft"] = snappedf(float(_party_hp(st)) / float(maxi(1, party_max)), 0.01)
	return line


static func _party_hp(st: Object) -> int:
	var n := 0
	for x in st.units:
		if x.team == "party" and not x.is_prop() and not bool(x.source.get("object", false)) and x.alive():
			n += maxi(0, x.hp)
	return n


static func _enemy_hp(st: Object) -> Array:
	var now := 0
	var full := 0
	for x in st.units:
		if x.team == "enemy" and not x.is_prop():
			full += x.max_hp
			if x.alive():
				now += maxi(0, x.hp)
	return [now, full]


## At each party turn: the damage aimed at this unit, the party's low point, and
## whether the party is behind (for comebacks).
static func _turn_start(st: Object, u: Object, m: Dictionary, party_max: int) -> void:
	var incoming := 0
	for h in st.threats().get(u.cell, []):
		var src: Object = st.unit_by_id(str(h["unit"]))
		if src != null and src.team != "party":
			incoming += int(h["damage"])
	m["threatened"] = int(m["threatened"]) + mini(incoming, u.hp + u.shield)
	var ratio := float(_party_hp(st)) / float(maxi(1, party_max))
	m["minHp"] = minf(float(m["minHp"]), ratio)
	var e := _enemy_hp(st)
	if st.round_num >= 2 and int(e[1]) > 0 and ratio < float(e[0]) / float(e[1]):
		m["behind"] = true


static func _count_plays(st: Object, rec: Dictionary, m: Dictionary) -> void:
	var played := str(rec.get("played", ""))
	if (m["opening"] as Array).size() < 2:
		m["opening"].append(played)
	if played == "":
		return
	var team_ops: Array = tuner(st.db).get("teamworkOps", [])
	for part in played.split("+"):
		var id := part.get_slice("@", 0).get_slice("#", 0)
		m["plays"][id] = int(m["plays"].get(id, 0)) + 1
		if id.begins_with("together") or Legal.has_op(Legal.card_rec(st, { "kind": "card", "id": id }), team_ops):
			m["teamwork"] = int(m["teamwork"]) + 1


static func _observe(_st: Object, e: Dictionary, m: Dictionary) -> void:
	if str(e.get("t", "")) == "board_kill":
		m["boardKills"] = int(m["boardKills"]) + 1

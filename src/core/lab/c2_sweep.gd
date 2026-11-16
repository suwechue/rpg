## One headless Combat 2.0 fight (or night) for the sweeps (docs/COMBAT_2.md
## Part 5): the same log line fields as a Lab sweep (so LT's metrics read it),
## plus the C2 counts: knockdowns, One Mores, Baton Passes, All-Outs, spells and
## charges, enemy hits and the loadouts used. cell.c2: { level, mix } where mix
## means random valid loadouts per seed (for loadout variety). Plain data.
extends RefCounted

const C2Setup := preload("res://src/core/combat2/c2_setup.gd")
const C2AI := preload("res://src/core/combat2/c2_ai.gd")
const C2Player := preload("res://src/core/lab/players/c2_player.gd")
const Night := preload("res://src/core/combat2/night.gd")
const Kits := preload("res://src/core/combat2/kits.gd")
const Loadout := preload("res://src/core/combat2/loadout.gd")
const C2Rules := preload("res://src/core/combat2/c2_rules.gd")

const STALL_ROUNDS := 30


static func run(db: Dictionary, cell: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var c2: Dictionary = cell.get("c2", {})
	var level := int(c2.get("level", 1))
	var seed_value := int(cell.get("seed", 1))
	var prof_id := str(cell.get("profile", "expert"))
	var prof := C2Player.profile(db, prof_id)
	var rules := C2Rules.build(db, cell.get("levers", {})) as C2Rules
	var prng := RandomNumberGenerator.new()
	prng.seed = hash([seed_value, prof_id, str(cell.get("fight", ""))])
	var los := {}
	for cid in db.get("combat2/fights", {}).get("partyOrder", []):
		los[str(cid)] = Loadout.random(db, rules, str(cid), level, prng) if bool(c2.get("mix", false)) else C2Setup.default_loadout(db, str(cid), level)
	var fid := str(cell.get("fight", ""))
	var steps: Array = C2Setup.night(db, fid).get("steps", []) if not C2Setup.night(db, fid).is_empty() else [fid]
	var kits: Array = []
	for cid in los:
		kits.append(Kits.build(db, rules, str(cid), level, los[cid]))
	var carry := Night.home(kits)
	var start := carry.duplicate(true)
	var known := {}
	var total := { "rounds": 0, "result": "win", "turns": [], "tally": {}, "kills": 0, "boardKills": 0, "minHp": 1.0, "hpLeft": 1.0, "fights": 0, "behind": false }
	for step in steps:
		if str(step) == "rest":
			carry = Night.rest_room(carry, kits, rules)
			continue
		var setup := C2Setup.build(db, str(step), { "level": level, "loadouts": los, "c2Levers": cell.get("levers", {}), "seed": seed_value + 97 * int(total["fights"]),
			"carry": carry if steps.size() > 1 else {}, "known": known })
		var st: Object = C2Setup.state(db, setup)
		var r := _play(st, prof, prng)
		total["fights"] = int(total["fights"]) + 1
		total["rounds"] = int(total["rounds"]) + st.round_num
		(total["turns"] as Array).append_array(r["turns"])
		total["kills"] = int(total["kills"]) + int(r["kills"])
		total["boardKills"] = int(total["boardKills"]) + int(r["boardKills"])
		total["minHp"] = minf(float(total["minHp"]), float(r["minHp"]))
		total["hpLeft"] = float(r["hpLeft"])
		total["behind"] = bool(total["behind"]) or bool(r["behind"])
		for k in st.tally:
			if typeof(st.tally[k]) == TYPE_DICTIONARY:
				var m: Dictionary = total["tally"].get(k, {})
				for kk in st.tally[k]:
					m[kk] = int(m.get(kk, 0)) + int(st.tally[k][kk])
				total["tally"][k] = m
			else:
				total["tally"][k] = int(total["tally"].get(k, 0)) + int(st.tally[k])
		carry = st.carry_out()
		known = st.known_marks
		var res: String = st.result if st.result != "" else "stall"
		if res != "win":
			total["result"] = res
			break
	var use := Night.charge_use(start, carry)
	var plays := {}
	for uid in total["tally"].get("moves", {}):
		plays[str(uid).get_slice(":", 1)] = int(total["tally"]["moves"][uid])
	var tal: Dictionary = total["tally"]
	var opening: Array = (total["turns"] as Array).slice(0, 2).map(func(t: Dictionary) -> String: return str(t.get("played", "")))
	var sig := {}
	for cid in los:
		sig[cid] = _sig(los[cid])
	return {
		"kind": "sweep", "c2": true, "fight": fid, "profile": prof_id, "party": str(cell.get("party", "balanced")), "group": str(cell.get("group", "")),
		"preset": str(cell.get("preset", "c2")), "seed": seed_value, "level": level, "leverSet": cell.get("levers", {}), "key": cell_key(cell),
		"result": str(total["result"]), "rounds": int(total["rounds"]), "fights": int(total["fights"]), "boss": steps.has("c2_hollow_mascot"),
		"ai": total["turns"], "threatened": 0, "telegraphedDamage": 0, "kills": int(total["kills"]), "boardKills": int(total["boardKills"]),
		"teamwork": int(tal.get("batons", 0)) + int(tal.get("followUps", 0)) + int(tal.get("allOuts", 0)) + int(tal.get("protects", 0)),
		"plays": plays, "opening": "|".join(PackedStringArray(opening)), "minPartyHp": snappedf(float(total["minHp"]), 0.01),
		"partyHpLeft": snappedf(float(total["hpLeft"]), 0.01), "comeback": bool(total["behind"]) and str(total["result"]) == "win",
		"knockdowns": int(tal.get("knockdowns", 0)), "oneMores": int(tal.get("oneMores", 0)), "batons": int(tal.get("batons", 0)), "allOuts": int(tal.get("allOuts", 0)),
		"spells": int(tal.get("spells", 0)), "chargesSpent": int(use["spent"]), "chargesMax": int(use["max"]), "enemyAttacks": int(tal.get("enemyAttacks", 0)),
		"enemyHits": int(tal.get("enemyHits", 0)), "enemyDamage": int(tal.get("enemyDamage", 0)), "partyKnocked": int(tal.get("partyKnocked", 0)),
		"weakHits": int(tal.get("weakHits", 0)), "ultimates": int(tal.get("ultimates", 0)), "braces": int(tal.get("braces", 0)),
		"loadouts": sig, "usec": Time.get_ticks_usec() - t0,
	}


static func cell_key(cell: Dictionary) -> String:
	var c2: Dictionary = cell.get("c2", {})
	var levers: Dictionary = cell.get("levers", {})
	var keys: Array = levers.keys()
	keys.sort()
	var lv: Array = []
	for k in keys:
		lv.append("%s=%s" % [k, str(levers[k])])
	return "c2|%s|L%d%s|%s|%d|%s" % [cell.get("fight", ""), int(c2.get("level", 1)), "mix" if bool(c2.get("mix", false)) else "", ",".join(PackedStringArray(lv)), int(cell.get("seed", 1)), cell.get("profile", "")]


static func _sig(lo: Dictionary) -> String:
	var parts: Array = []
	for k in ["moves", "spells", "perks"]:
		var l: Array = (lo.get(k, []) as Array).duplicate()
		l.sort()
		parts.append(",".join(PackedStringArray(l)))
	parts.append(str(lo.get("ultimate", "")))
	var g: Dictionary = lo.get("gear", {})
	parts.append("%s,%s,%s,%s" % [g.get("weapon", ""), g.get("armor", ""), g.get("trinket1", ""), g.get("trinket2", "")])
	return "/".join(PackedStringArray(parts))


static func _play(st: Object, prof: Dictionary, prng: RandomNumberGenerator) -> Dictionary:
	var turns: Array = []
	var steps := 0
	var party_max := 0
	for x in st.units:
		if x.team == "party":
			party_max += x.max_hp
	var min_hp := 1.0
	var behind := false
	var board := 0
	while st.result == "" and st.current != null and st.round_num <= STALL_ROUNDS and steps < 4000:
		steps += 1
		var u: Object = st.current
		if u.team == "party":
			var ratio := float(_party_hp(st)) / float(maxi(1, party_max))
			min_hp = minf(min_hp, ratio)
			var e := _enemy_hp(st)
			if st.round_num >= 2 and int(e[1]) > 0 and ratio < float(e[0]) / float(e[1]):
				behind = true
			turns.append(C2Player.take_turn(st, prof, prng))
		else:
			C2AI.take_turn(st, u)
		for ev in st.take_events():
			if str(ev.get("t", "")) == "board_kill":
				board += 1
	var kills := 0
	for x in st.units:
		if x.team == "enemy" and x.dead:
			kills += 1
	return { "turns": turns, "kills": kills, "boardKills": board, "minHp": min_hp, "hpLeft": float(_party_hp(st)) / float(maxi(1, party_max)), "behind": behind }


static func _party_hp(st: Object) -> int:
	var n := 0
	for x in st.units:
		if x.team == "party" and x.alive() and not x.downed:
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

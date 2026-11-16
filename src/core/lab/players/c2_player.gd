## The Lab players for Combat 2.0 (docs/COMBAT_2.md Part 5): the expert tries
## every reachable tile, ready Ability and target on a saved copy of the fight,
## then the best One More, Baton Pass or All-Out after it, and plays the line that
## leaves the best position. Novice adds noise and skips some options; greedy
## counts damage only; random plays any legal step. Profiles and weights:
## data/combat2/players.json. Returns a turn record for the metrics.
extends RefCounted

const Sim := preload("res://src/core/lab/players/sim.gd")
const Shapes := preload("res://src/core/combat2/shapes.gd")
const C2AI := preload("res://src/core/combat2/c2_ai.gd")
const GridScript := preload("res://src/core/combat/grid.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("combat2/players", {})


static func profile(db: Dictionary, id: String) -> Dictionary:
	return cfg(db).get("profiles", {}).get(id, {})


static func weights(db: Dictionary, prof: Dictionary) -> Dictionary:
	var w: Dictionary = (cfg(db).get("weights", {}) as Dictionary).duplicate()
	w.merge(prof.get("weights", {}), true)
	return w


## Take the current party unit's whole turn. Returns { unit, round, values, load, played }.
static func take_turn(st: Object, prof: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var u: Object = st.current
	var rec := { "unit": u.id, "round": st.round_num, "values": [], "load": 0, "played": "" }
	if st.must_skip(u) or not u.alive():
		st.end_turn()
		return rec
	if bool(prof.get("random", false)):
		_random_turn(st, u, rng, rec)
		return rec
	var w := weights(st.db, prof)
	var played: Array = []
	for step in 4:
		if st.result != "" or st.current != u:
			break
		var options := _options(st, u, prof, rng, step == 0)
		if step == 0:
			rec["load"] = options.size()
		var scored: Array = []
		for o in options:
			var v := _value(st, u, o, w, prof, rng)
			if float(prof.get("noise", 0.0)) > 0.0:
				v += (rng.randf() * 2.0 - 1.0) * float(prof["noise"]) * maxf(4.0, absf(v) * 0.1)
			scored.append({ "o": o, "v": v })
		if scored.is_empty():
			break
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["v"]) > float(b["v"]))
		if step == 0:
			rec["values"] = scored.slice(0, 12).map(func(s: Dictionary) -> float: return snappedf(float(s["v"]), 0.01))
		var best: Dictionary = scored[0]["o"]
		played.append(_key(best))
		_apply(st, u, best)
		if str(best["kind"]) == "end":
			break
	if st.result == "" and st.current == u:
		st.end_turn()
	rec["played"] = "+".join(PackedStringArray(played))
	return rec


static func _key(o: Dictionary) -> String:
	match str(o["kind"]):
		"act":
			return "%s@%d,%d" % [str(o["uid"]).get_slice(":", 1), o["target"].x, o["target"].y]
		"baton":
			return "baton>" + str(o["ally"])
	return str(o["kind"])


## Every step this unit could take now: { kind: act (spot, uid, target), baton (ally), allOut, end }.
static func _options(st: Object, u: Object, prof: Dictionary, rng: RandomNumberGenerator, first: bool) -> Array:
	var out: Array = []
	var ignore: Array = prof.get("ignoreKinds", [])
	var skip := func(kind: String) -> bool: return ignore.has(kind) and rng.randf() < float(prof.get("ignoreChance", 0.0))
	if st.all_out_ready and not skip.call("allOut"):
		out.append({ "kind": "allOut" })
	if not st.one_more.is_empty() and not skip.call("baton"):
		for a in st.allies_of(u):
			if a != u and st.baton_block(u, a) == "":
				out.append({ "kind": "baton", "ally": a.id })
	var spots: Array = [u.cell]
	if u.move_left > 0 and st.can_move(u):
		var reach: Array = st.reachable_cells(u).keys()
		reach.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _near_foe(st, u, a) < _near_foe(st, u, b))
		spots.append_array(reach.slice(0, int(prof.get("moveCells", 99))))
	var saved: Vector2i = u.cell
	var skip_spell: bool = skip.call("spell")
	var skip_scan: bool = skip.call("scan")
	for spot in spots:
		u.cell = spot
		for ab in st.abilities(u):
			if str(ab.get("kind", "")) == "spell" and skip_spell:
				continue
			if bool(ab.get("scan", false)) and skip_scan:
				continue
			if C2AI._blocked(st, u, ab) or (u.action_used and st.one_more.is_empty()):
				continue
			for tgt in Shapes.targets(st, u, ab, spot):
				out.append({ "kind": "act", "spot": spot, "uid": str(ab["uid"]), "target": tgt })
	u.cell = saved
	out.append({ "kind": "end" })
	return out


static func _near_foe(st: Object, u: Object, c: Vector2i) -> int:
	var best := 99
	for f in st.opponents_of(u):
		best = mini(best, GridScript.manhattan(c, f.cell))
	return best


static func _apply(st: Object, u: Object, o: Dictionary) -> void:
	match str(o["kind"]):
		"act":
			if o["spot"] != u.cell:
				st.move(u, o["spot"])
			if st.result == "" and st.current == u:
				st.use_ability(u, str(o["uid"]), o["target"])
		"baton":
			st.baton_pass(u, st.unit_by_id(str(o["ally"])))
		"allOut":
			st.all_out(u)
		"end":
			st.end_turn()


## The position after this step (and, for the expert, the best follow-up after it).
static func _value(st: Object, u: Object, o: Dictionary, w: Dictionary, prof: Dictionary, rng: RandomNumberGenerator) -> float:
	var snap: Dictionary = Sim.save(st)
	var v := 0.0
	if str(o["kind"]) == "act" and o["spot"] != u.cell:
		st.move(u, o["spot"])
	if str(o["kind"]) == "act":
		if st.result == "" and st.current == u:
			st.use_ability(u, str(o["uid"]), o["target"])
	else:
		_apply(st, u, o)
	if bool(prof.get("followUp", false)) and st.result == "" and st.current == u and (not st.one_more.is_empty() or st.all_out_ready):
		var best := -INF
		for o2 in _options(st, u, prof, rng, false):
			if str(o2["kind"]) == "end":
				continue
			var s2: Dictionary = Sim.save(st)
			_apply(st, u, o2)
			best = maxf(best, score(st, w))
			Sim.restore(st, s2)
		v = best if best > -INF else score(st, w)
	elif str(o["kind"]) == "baton" and st.result == "":
		var ally: Object = st.current
		var b := C2AI.best_action(st, ally, ally.move_left)
		v = score(st, w) + float(b.get("score", 0.0)) * 0.8
	else:
		v = score(st, w)
	Sim.restore(st, snap)
	return v


## A position from the party's side (data/combat2/players.json weights).
static func score(st: Object, w: Dictionary) -> float:
	if st.result == "win":
		return float(w.get("win", 200.0))
	if st.result == "lose":
		return -float(w.get("loss", 200.0))
	var s := 0.0
	var foes: Array = []
	for x in st.units:
		if x.is_prop():
			continue
		if x.team == "party":
			if not x.alive() or x.downed:
				s -= float(w.get("downed", 10.0))
				continue
			s += float(w.get("partyHp", 1.0)) * float(x.hp + x.shield)
			if x.statuses.has("knocked"):
				s -= float(w.get("partyKnocked", 4.0))
			for uid in st.charges_left.get(x.id, {}):
				s += float(w.get("charge", 1.5)) * float(st.charges_left[x.id][uid])
			s += float(w.get("meter", 0.05)) * float(st.meter.get(x.id, 0))
		elif x.team == "enemy" and x.alive():
			foes.append(x)
			s -= float(w.get("enemyHp", 1.0)) * float(x.hp + x.shield)
			s -= float(w.get("enemyAlive", 6.0))
			if x.statuses.has("knocked"):
				s += float(w.get("knocked", 4.0))
	if float(w.get("danger", 0.0)) > 0.0:
		s -= float(w.get("danger", 0.5)) * danger(st, foes)
	return s


## Roughly what the enemies can deal next turn: each standing enemy's best hit on
## the party members it can reach (Movement + range).
static func danger(st: Object, foes: Array) -> float:
	var total := 0.0
	for e in foes:
		if e.statuses.has("knocked") or e.statuses.has("stun"):
			continue
		var best := 0.0
		for ab in st.abilities(e):
			var reach: int = e.movement + int(ab.get("range", 1)) + (1 if str(ab.get("shape", "")) in ["cone", "burst"] else 0)
			for x in st.units:
				if x.team != "party" or not x.alive() or x.downed or GridScript.manhattan(x.cell, e.cell) > reach:
					continue
				best = maxf(best, float(st.hit_result(e, x, ab)["amount"]))
		total += best
	return total


static func _random_turn(st: Object, u: Object, rng: RandomNumberGenerator, rec: Dictionary) -> void:
	for step in 3:
		if st.result != "" or st.current != u:
			return
		var opts := _options(st, u, {}, rng, step == 0)
		if step == 0:
			rec["load"] = opts.size()
		var o: Dictionary = opts[rng.randi_range(0, opts.size() - 1)]
		_apply(st, u, o)
		if str(o["kind"]) == "end":
			return
	if st.result == "" and st.current == u:
		st.end_turn()

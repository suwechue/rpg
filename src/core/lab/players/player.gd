## The Lab's AI players (docs/LAB_TUNER.md Part 2): one turn search shared by
## every profile in data/lab/players.json. expert, novice and greedy search
## their whole turn as lines of steps (move, card, Strike...) with a beam, scored
## by evaluator.gd; random plays any legal step. They see what a player sees:
## the search runs on a masked copy (sim.gd), so deck order and dice stay hidden.
extends RefCounted

const Sim := preload("res://src/core/lab/players/sim.gd")
const Legal := preload("res://src/core/lab/players/legal.gd")
const Eval := preload("res://src/core/lab/players/evaluator.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const Extras := preload("res://src/core/combat/extras.gd")

const PROFILES := ["expert", "novice", "greedy", "random"]


static func profile(db: Dictionary, id: String) -> Dictionary:
	return Eval.cfg(db).get("profiles", {}).get(id, {})


## Play the current unit's whole turn. Returns the turn record (Part 3):
## { unit, round, load, values (best first, change in score), played }.
static func take_turn(st: Object, prof: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var u: Object = st.current
	if bool(prof.get("random", false)):
		return _random_turn(st, u, prof, rng)
	if bool(prof.get("orderSearch", false)):
		u = _pick_order(st, u, prof, rng)
	var plan := plan_turn(st, u, prof, rng)
	for s in plan["line"]:
		if st.result != "" or st.current != u or not u.alive():
			break
		if not Legal.apply(st, u, s):
			break
	if st.result == "" and st.current == u:
		st.end_turn()
	return plan["record"]


## The best line for this turn, without playing it.
static func plan_turn(st: Object, u: Object, prof: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var w := Eval.weights(st.db, prof)
	var beam_n := int(prof.get("beam", 3))
	var move_n := int(prof.get("moveBeam", 2))
	var depth := int(prof.get("depth", 4))
	var noise := float(prof.get("noise", 0.0))
	var filt := _filters(prof, rng)
	var ctx := Sim.begin(st)
	var root: Dictionary = ctx["root"]
	var base := Eval.score(st, w)
	var load := 0
	var best_by_key := { "": base }
	var best_line: Array = []
	var best_value := base
	var beam: Array = [{ "snap": root, "line": [] }]
	var seen := {}
	for d in depth:
		var cands: Array = []
		for node in beam:
			Sim.restore(st, node["snap"])
			var options := _options(st, u, prof, filt, d)
			if d == 0:
				load = options.filter(func(s: Dictionary) -> bool: return str(s["kind"]) != "move").size()
			for s in options:
				Sim.restore(st, node["snap"])
				var before := _sig(st, u)
				if not Legal.apply(st, u, s) or _sig(st, u) == before:
					continue
				var line: Array = node["line"] + [s]
				var value := Eval.score(st, w)
				if noise > 0.0:
					value += (rng.randf() * 2.0 - 1.0) * noise * maxf(1.0, absf(value - base))
				var key := Legal.line_key(line)
				if value > float(best_by_key.get(key, -INF)):
					best_by_key[key] = value
				if value > best_value:
					best_value = value
					best_line = line
				var open: bool = st.result == "" and st.current == u and u.alive()
				if open:
					# The same position reached two ways is one line.
					var at := _state_key(st, u)
					if not seen.has(at):
						seen[at] = true
						cands.append({ "line": line, "value": value, "move": str(s["kind"]) == "move" })
		if cands.is_empty():
			break
		cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["value"]) > float(b["value"]))
		var keep: Array = cands.slice(0, beam_n)
		var moves := 0
		for c in cands:
			if moves >= move_n:
				break
			if bool(c["move"]) and not keep.has(c):
				keep.append(c)
				moves += 1
		beam = []
		for c in keep:
			Sim.restore(st, root)
			var ok := true
			for s in c["line"]:
				ok = ok and Legal.apply(st, u, s)
			if ok:
				beam.append({ "snap": Sim.save(st), "line": c["line"] })
	Sim.finish(st, ctx)
	var values: Array = []
	for k in best_by_key:
		values.append(snappedf(float(best_by_key[k]) - base, 0.01))
	values.sort()
	values.reverse()
	return { "line": best_line, "record": { "unit": u.id, "round": st.round_num, "load": load, "values": values.slice(0, 8),
		"played": Legal.line_key(best_line) } }


## What changes when a step works (a refused step changes nothing).
static func _sig(st: Object, u: Object) -> Array:
	return [u.cell, u.mp, u.actions_left, u.action_used, u.quick_used, u.move_left, u.deck.hand.size() if u.deck != null else 0, st.current, st.events.size(), st.result]


## Where everyone stands and what they have left: two lines that end here are the same.
static func _state_key(st: Object, u: Object) -> int:
	var parts: Array = [u.mp, u.actions_left, u.action_used, u.quick_used, u.quicks_taken, u.move_left, u.deck.hand if u.deck != null else [], st.surge]
	for x in st.units:
		parts.append([x.cell, x.hp, x.shield, x.statuses.size(), x.intent.get("kind", "")])
	return hash(parts)


## This turn's ignore rules (the novice skips some things some turns).
static func _filters(prof: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := { "kinds": [], "ops": [], "board": [] }
	if prof.has("ignoreChance") and rng.randf() < float(prof["ignoreChance"]):
		out["kinds"] = prof.get("ignoreKinds", [])
		out["ops"] = prof.get("ignoreOps", [])
		out["levers"] = prof.get("ignoreLevers", [])
	if prof.has("boardBlindChance") and rng.randf() < float(prof["boardBlindChance"]):
		out["board"] = prof.get("boardOps", [])
	return out


## The steps worth trying: no end, no hold or reserve, and only the best few tiles to move to.
static func _options(st: Object, u: Object, prof: Dictionary, filt: Dictionary, d: int = 0) -> Array:
	var out: Array = []
	var moves: Array = []
	for s in Legal.steps(st, u):
		var kind := str(s["kind"])
		if kind in ["end", "hold", "reserve", "pick", "delay"] or (filt["kinds"] as Array).has(kind):
			continue
		if kind == "move":
			moves.append(s)
			continue
		if kind == "card":
			var card := Legal.card_rec(st, s)
			if Legal.has_op(card, filt["ops"]) or Legal.has_op(card, filt["board"]):
				continue
			if not filt.get("levers", []).is_empty() and _lever_card(st, card, filt["levers"]):
				continue
		out.append(s)
	out.append_array(_best_moves(st, u, moves, int(prof.get("moveCells", 8)) if d == 0 else int(prof.get("moveCellsLate", 4))))
	return out


static func _lever_card(_st: Object, card: Dictionary, levers: Array) -> bool:
	if levers.has("chargeSpells") and bool(card.get("charge", false)):
		return true
	if levers.has("duetCards") and card.has("duet"):
		return true
	if levers.has("signatureCard") and bool(card.get("signature", false)):
		return true
	return false


## Tiles ranked by a quick look: out of telegraphs, next to a foe, not far.
static func _best_moves(st: Object, u: Object, moves: Array, n: int) -> Array:
	if moves.size() <= n:
		return moves
	var threats: Dictionary = st.threats()
	var foes: Array = st.opponents_of(u)
	var scored: Array = []
	for s in moves:
		var c: Vector2i = s["cell"]
		var danger := 0
		for h in threats.get(c, []):
			danger += int(h["damage"])
		var near := 99
		for o in foes:
			near = mini(near, GridScript.manhattan(o.cell, c))
		var v := -float(danger) * 2.0 - float(absi(near - 1)) + (1.5 if near == 1 else 0.0)
		scored.append([v, s])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: Array = []
	for i in n:
		out.append(scored[i][1])
	return out


## Choose your order: the ally whose best turn now gains the most goes first.
static func _pick_order(st: Object, u: Object, prof: Dictionary, rng: RandomNumberGenerator) -> Object:
	var picks: Array = []
	for a in st.units:
		if Extras.can_pick_turn(st, a):
			picks.append(a)
	if picks.is_empty():
		return u
	var quick := prof.duplicate()
	quick["beam"] = 1
	quick["moveBeam"] = 1
	quick["depth"] = 2
	var best: Object = u
	var best_gain := _gain(st, u, quick, rng)
	for a in picks:
		var ctx := Sim.begin(st)
		Extras.pick_turn(st, a)
		var g := _gain(st, a, quick, rng)
		Sim.finish(st, ctx)
		if g > best_gain:
			best_gain = g
			best = a
	if best != u:
		Extras.pick_turn(st, best)
	return best


static func _gain(st: Object, u: Object, prof: Dictionary, rng: RandomNumberGenerator) -> float:
	var rec: Dictionary = plan_turn(st, u, prof, rng)["record"]
	return float(rec["values"][0]) if not rec["values"].is_empty() else 0.0


## A random legal step at a time, until it ends the turn.
static func _random_turn(st: Object, u: Object, prof: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var played: Array = []
	for i in int(prof.get("maxSteps", 6)):
		if st.result != "" or st.current != u or not u.alive():
			break
		if rng.randf() < float(prof.get("endChance", 0.2)):
			break
		var options: Array = Legal.steps(st, u, { "extras": false }).filter(func(s: Dictionary) -> bool: return str(s["kind"]) != "end")
		var done := false
		while not options.is_empty() and not done:
			var k := rng.randi_range(0, options.size() - 1)
			var s: Dictionary = options[k]
			options.remove_at(k)
			done = Legal.apply(st, u, s)
			if done:
				played.append(s)
		if not done:
			break
	if st.result == "" and st.current == u:
		st.end_turn()
	return { "unit": u.id, "round": st.round_num, "played": Legal.line_key(played) }

## Combat 2.0 turn-taker for enemies and for autoplay (docs/COMBAT_2.md Parts 1
## to 3): for each tile it can reach, each ready Ability and each target, score
## the hits (damage, knockdowns, kills; weakness hunters prefer weaknesses), then
## move and act. With One More waiting it acts again (or, on the party side,
## launches an All-Out or passes the baton). Bosses mark their big attacks a turn
## ahead. Reads levers through the state; no randomness of its own.
extends RefCounted

const Shapes := preload("res://src/core/combat2/shapes.gd")
const GridScript := preload("res://src/core/combat/grid.gd")


static func take_turn(st: Object, u: Object) -> void:
	if st.result != "" or st.current != u:
		return
	if st.must_skip(u):
		st.end_turn()
		return
	if st.boss_plans.has(u.id):
		st.land_big(u)
		if st.result != "" or st.current != u:
			return
	if u.boss and st.c2.flag("bossTelegraphs", true) and int(st.big_counter.get(u.id, 0)) >= st.c2.count("bossBigEvery", 2):
		var big := best_action(st, u, 0, true)
		if not big.is_empty():
			st.plan_big(u, st.ability_of(u, str(big["uid"])), big["target"])
	for i in 4:
		if st.result != "" or st.current != u:
			return
		if u.team == "party" and st.all_out_ready:
			st.all_out(u)
			return
		if u.team == "party" and not st.one_more.is_empty():
			var pass_to := baton_target(st, u)
			if pass_to != null:
				st.baton_pass(u, pass_to)
				return
		var best := best_action(st, u, u.move_left)
		if best.is_empty():
			if i == 0:
				_approach(st, u)
			break
		if best["spot"] != u.cell:
			st.move(u, best["spot"])
			if st.result != "" or st.current != u or not u.alive():
				return
		if not st.use_ability(u, str(best["uid"]), best["target"]):
			break
	if st.result == "" and st.current == u:
		st.end_turn()


## The best { spot, uid, target, score } this unit can do (big = only a boss's big moves).
static func best_action(st: Object, u: Object, budget: int, big: bool = false) -> Dictionary:
	var spots: Array = [u.cell]
	if budget > 0 and not big:
		var reach: Dictionary = st.grid.reachable(u.cell, budget, st.occupied(u))
		reach.erase(u.cell)
		spots.append_array(reach.keys())
	var saved: Vector2i = u.cell
	var best := {}
	var best_score := 0.0
	for spot in spots:
		u.cell = spot
		for ab in st.abilities(u):
			if bool(ab.get("big", false)) != big and st.c2.flag("bossTelegraphs", true) and u.boss:
				continue
			if not big and _blocked(st, u, ab):
				continue
			for tgt in Shapes.targets(st, u, ab, spot):
				var sc := score(st, u, ab, tgt, spot)
				sc -= 0.05 * float(GridScript.manhattan(spot, saved))
				if sc > best_score:
					best_score = sc
					best = { "spot": spot, "uid": str(ab["uid"]), "target": tgt, "score": sc }
	u.cell = saved
	return best


static func _blocked(st: Object, u: Object, ab: Dictionary) -> bool:
	var uid := str(ab["uid"])
	if int(st.cooldowns.get(u.id, {}).get(uid, 0)) > 0:
		return true
	match str(ab.get("kind", "")):
		"spell":
			return int(st.charges_left.get(u.id, {}).get(uid, 0)) <= 0 and not st._free_spell(u)
		"ultimate":
			return int(st.meter.get(u.id, 0)) < st.c2.count("ultMax", 100)
	return false


## What an Ability aimed here is worth to this unit (no changes to the fight).
static func score(st: Object, u: Object, ab: Dictionary, tgt: Vector2i, spot: Vector2i) -> float:
	var cells: Array = Shapes.cells(st, u, ab, tgt, spot)
	var total := 0.0
	var hunts := bool(u.source.get("huntsWeakness", false))
	var supports := str(ab.get("target", "")) == "ally" or str(ab.get("affects", "")) == "allies"
	if supports:
		for c in cells + ([spot] if str(ab.get("shape", "")) in ["burst", "self"] else []):
			var a: Object = st.unit_at(c)
			if a == null or a.team != u.team or not a.alive():
				continue
			var missing := float(a.max_hp - a.hp)
			total += minf(missing, float(ab.get("heal", 0))) * 1.0
			total += float(ab.get("shield", 0)) * (0.6 if a.hp < a.max_hp else 0.25)
		if bool(ab.get("actNow", false)) or bool(ab.get("allAlliesAct", false)):
			total += 6.0
		return total
	for c in cells:
		var t: Object = st.unit_at(c)
		if t == null or t == u or not t.alive():
			continue
		if t.is_prop():
			total += 1.0
			continue
		if not st.is_hostile(u, t):
			continue
		var res: Dictionary = st.hit_result(u, t, ab)
		var amt := float(res["amount"])
		total += minf(amt, float(t.hp + t.shield))
		if bool(res["knock"]):
			total += 8.0
		if amt >= float(t.hp + t.shield):
			total += 12.0
		if hunts and bool(res["weak"]):
			total += 6.0
		if int(ab.get("push", 0)) > 0 or int(ab.get("pull", 0)) > 0:
			total += 1.0
		if bool(ab.get("scan", false)) and st.known_of(t).size() < (t.source.get("marks", {}) as Dictionary).size():
			total += 4.0
		var s: Dictionary = ab.get("status", {})
		if not s.is_empty() and not t.statuses.has(str(s["id"])):
			total += 2.0
	if str(ab.get("kind", "")) == "spell":
		total *= 0.85
	return total


## The ally best placed to use a passed One More (a weakness hit or a kill they can reach), or null.
static func baton_target(st: Object, u: Object) -> Object:
	var mine := best_action(st, u, u.move_left)
	var mine_score := float(mine.get("score", 0.0))
	var pick: Object = null
	var pick_score := mine_score + 4.0
	for a in st.allies_of(u):
		if a == u or st.baton_block(u, a) != "":
			continue
		var b := best_action(st, a, a.movement + st.c2.count("batonMove", 1))
		if float(b.get("score", 0.0)) > pick_score:
			pick = a
			pick_score = float(b["score"])
	return pick


## Nothing to hit: walk toward the nearest opponent.
static func _approach(st: Object, u: Object) -> void:
	var reach: Dictionary = st.reachable_cells(u)
	if reach.is_empty():
		return
	var foes: Array = st.opponents_of(u)
	if foes.is_empty():
		return
	var best: Vector2i = u.cell
	var best_d := 999
	for c in reach:
		for f in foes:
			var d := GridScript.manhattan(c, f.cell)
			if d < best_d:
				best_d = d
				best = c
	if best != u.cell:
		st.move(u, best)

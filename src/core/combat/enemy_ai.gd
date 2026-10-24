## Disposition AI (DESIGN.md Section 9, "Enemy AI"). Every reachable option
## (move somewhere, then use an action on a target) is scored by
## expected value x Match(disposition, the action's profile), and the AI picks
## one with Sample. A cowardly unit retreats and a proud one duels the
## strongest opponent without per-unit scripts. Guest allies use the same
## code with their hand of cards. Profiles and weights: data/ai.json.
class_name EnemyAI
extends RefCounted

const VO := preload("res://src/core/vector_ops.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const Forms := preload("res://src/core/combat/forms.gd")


static func cfg(state: StateScript) -> Dictionary:
	return state.db.get("ai", {})


## Profile weight: Match on the signed disposition, mapped to 0..1 and sharpened.
static func profile_weight(state: StateScript, disposition: Dictionary, profile: Dictionary) -> float:
	if disposition.is_empty():
		disposition = cfg(state).get("defaultDisposition", {})
	var sim := VO.similarity(disposition, profile)
	var w := maxf(float(cfg(state).get("minWeight", 0.05)), (sim + 1.0) / 2.0)
	return pow(w, float(cfg(state).get("sharpness", 2.0)))


## Every option for this unit this turn: [{ kind, move, target, action|hand, ev, profile }].
static func options(state: StateScript, u: UnitScript) -> Array:
	var out: Array = []
	var c := cfg(state)
	var reach := state.reachable_cells(u)
	reach[u.cell] = 0
	var opponents := state.opponents_of(u)
	if opponents.is_empty():
		return out
	var acts := _actions(state, u)
	for act in acts:
		var spec: Dictionary = act["spec"]
		var best := {}
		for m in reach:
			var targets := _candidate_targets(state, u, act, m, opponents)
			for t in targets:
				var ev := _ev_at(state, u, spec, m, t)
				if ev <= 0.0:
					continue
				ev -= float(reach[m]) * float(c.get("moveCostPerStep", 0.05))
				if best.is_empty() or ev > float(best["ev"]):
					best = { "kind": act["kind"], "move": m, "target": t, "ev": ev, "profile": act["profile"],
						"action": act.get("action", {}), "hand": act.get("hand", -1), "card": act.get("card", {}) }
		if not best.is_empty():
			out.append(best)
	var nearest_dist := 999
	for o in opponents:
		nearest_dist = mini(nearest_dist, GridScript.manhattan(o.cell, u.cell))
	# Retreat: the reachable cell farthest from every opponent.
	var far_cell := u.cell
	var far_score := -1
	for m in reach:
		var d := 999
		for o in opponents:
			d = mini(d, GridScript.manhattan(o.cell, m))
		if d > far_score:
			far_score = d
			far_cell = m
	if far_cell != u.cell:
		out.append({ "kind": "move", "move": far_cell, "target": far_cell, "profile": c.get("retreat", { "courage": -1.0 }),
			"ev": float(c.get("retreatBase", 2.0)) + float(c.get("retreatHurt", 10.0)) * (1.0 - u.hp_ratio()) })
	# Advance: the reachable cell closest to the nearest opponent.
	var near_cell := u.cell
	var near_score := 999
	for m in reach:
		for o in opponents:
			var d := GridScript.manhattan(o.cell, m)
			if d < near_score:
				near_score = d
				near_cell = m
	if near_cell != u.cell:
		out.append({ "kind": "move", "move": near_cell, "target": near_cell, "profile": c.get("advance", { "courage": 1.0 }),
			"ev": float(c.get("advanceBase", 3.0)) + (2.0 if nearest_dist > 3 else 0.0) })
	out.append({ "kind": "guard", "move": u.cell, "target": u.cell, "profile": c.get("guard", { "loyalty": 0.5, "courage": -0.3 }),
		"ev": float(c.get("guardBase", 1.0)) })
	return out


## Pick one option with Sample over EV x profile weight.
static func choose(state: StateScript, u: UnitScript) -> Dictionary:
	var opts := options(state, u)
	if opts.is_empty():
		return {}
	var weights := {}
	var keys: Array = []
	for i in opts.size():
		var o: Dictionary = opts[i]
		var key := "o%03d" % i
		keys.append(key)
		weights[key] = maxf(0.0001, float(o["ev"])) * profile_weight(state, u.disposition, o["profile"])
	var pick := VO.sample(weights, state.rng, keys)
	return opts[keys.find(pick)]


## Run a whole AI turn: choose, move, act, end turn.
static func take_turn(state: StateScript, u: UnitScript) -> Dictionary:
	var plan := choose(state, u)
	if plan.is_empty():
		state.end_turn()
		return plan
	if plan["move"] != u.cell:
		state.move(u, plan["move"])
	if state.result == "" and u.alive():
		match str(plan["kind"]):
			"action":
				state.perform_action(u, plan["action"], plan["target"])
			"card":
				var idx := _find_hand(u, plan["card"])
				if idx >= 0:
					state.play_card(u, idx, plan["target"])
			"strike":
				state.strike(u, plan["target"])
			"guard":
				state.guard(u)
	if state.result == "" and state.current == u:
		state.end_turn()
	return plan


static func _find_hand(u: UnitScript, card: Dictionary) -> int:
	if u.deck == null:
		return -1
	for i in u.deck.hand.size():
		if str(u.deck.hand[i]) == str(card.get("id", "")):
			return i
	return -1


## Actions this unit could use: data actions for enemies; affordable hand
## cards and the free Strike for AI-controlled party members.
static func _actions(state: StateScript, u: UnitScript) -> Array:
	var out: Array = []
	var c := cfg(state)
	if u.team == "enemy":
		for a in u.actions:
			out.append({ "kind": "action", "action": a, "spec": state.action_spec(u, a),
				"profile": a.get("profile", c.get("attack", { "courage": 0.6 })), "strongest": str(a.get("target", "")) == "strongest" })
		return out
	if u.deck != null:
		var seen := {}
		for i in u.deck.hand.size():
			var id := str(u.deck.hand[i])
			if seen.has(id):
				continue
			seen[id] = true
			var card := CardRules.resolve(state.db, id, state.library)
			if card.is_empty() or state.card_cost(u, card) > u.mp:
				continue
			if CardRules.is_spell(card):
				var fid := str(card.get("form", ""))
				if fid in ["weapon_infusion", "construct", "glyph", "aura"]:
					continue
				out.append({ "kind": "card", "card": card, "spec": state._spell_spec(u, card), "profile": c.get("attack", { "courage": 0.6 }) })
			elif str(card.get("action", "")) == "strike":
				var base := float(u.stats.get(str(card.get("stat", "str")), 5)) * float(card.get("mult", 1.0))
				out.append({ "kind": "card", "card": card, "spec": { "kind": "strike", "base": base, "vectors": {}, "form": state.form_rec("touch"), "power": 0.0, "mult": 1.0, "heal": false, "ranged": false },
					"profile": c.get("attack", { "courage": 0.6 }) })
	if not u.free_action_used:
		var base := float(u.stats.get("str", 5))
		out.append({ "kind": "strike", "spec": { "kind": "strike", "base": base, "vectors": {}, "form": state.form_rec("touch"), "power": 0.0, "mult": 1.0, "heal": false, "ranged": false },
			"profile": c.get("attack", { "courage": 0.6 }) })
	return out


## Target cells worth scoring from `m` (pruned: cells with or next to opponents).
static func _candidate_targets(state: StateScript, u: UnitScript, act: Dictionary, m: Vector2i, opponents: Array) -> Array:
	var spec: Dictionary = act["spec"]
	var valid: Array
	var saved := u.cell
	u.cell = m
	if str(spec["kind"]) == "strike":
		valid = []
		for o in opponents:
			if GridScript.manhattan(o.cell, m) == 1:
				valid.append(o.cell)
	elif bool(spec["heal"]):
		valid = state._spell_targets(u, spec["form"], true)
	else:
		valid = state._spell_targets(u, spec["form"], false)
	u.cell = saved
	if bool(act.get("strongest", false)):
		var strongest: UnitScript = null
		for o in opponents:
			if strongest == null or o.max_hp > strongest.max_hp or (o.is_player and o.max_hp == strongest.max_hp):
				strongest = o
		var keep: Array = []
		for t in valid:
			if GridScript.manhattan(t, strongest.cell) <= 1:
				keep.append(t)
		return keep
	var out: Array = []
	var aoe := str(spec["form"].get("footprint", "")) in ["square_3x3", "line", "diamond_r2_self", "zone_r1_self_3_turns"]
	for t in valid:
		for o in opponents:
			var d := GridScript.manhattan(o.cell, t)
			if d == 0 or (aoe and d <= 1):
				out.append(t)
				break
	if bool(spec["heal"]):
		out = valid
	return out


## Expected value of using a spec from cell m at target t.
static func _ev_at(state: StateScript, u: UnitScript, spec: Dictionary, m: Vector2i, t: Vector2i) -> float:
	var saved := u.cell
	u.cell = m
	var occ := state.occupied(u)
	occ[m] = u
	var cells: Array
	if str(spec["kind"]) == "strike":
		cells = [t]
	else:
		cells = Forms.footprint(state.grid, spec["form"], m, t, occ)
	var ev := 0.0
	var kill_bonus := float(cfg(state).get("killBonus", 8.0))
	for c in cells:
		var o: UnitScript = occ.get(c, null)
		if o == null or o == u or o.is_prop():
			continue
		if bool(spec["heal"]):
			if o.team == u.team and o.alive():
				ev += minf(float(o.max_hp - o.hp), float(spec["power"]))
			continue
		if not state.is_hostile(u, o) or not o.alive():
			continue
		var dmg := state.expected_damage(u, o, spec)
		ev += minf(dmg, float(o.hp))
		if dmg >= float(o.hp):
			ev += kill_bonus
		if o.is_player:
			ev *= float(cfg(state).get("playerFocus", 1.1))
	u.cell = saved
	return ev

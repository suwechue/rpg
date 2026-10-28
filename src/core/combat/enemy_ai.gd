## Disposition AI (DESIGN.md Section 9, "Enemy AI"). Every reachable option
## (move somewhere, then use an action on a target) is scored by
## expected value x Match(disposition, the action's profile), and the AI picks
## one with Sample. A cowardly unit retreats and a proud one duels the
## strongest opponent without per-unit scripts. Guest allies use the same
## code with their hand of cards. Profiles and weights: data/ai.json.
class_name EnemyAI
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const VO := preload("res://src/core/vector_ops.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const Forms := preload("res://src/core/combat/forms.gd")


static func cfg(state: StateScript) -> Dictionary:
	if state.ai_overrides.is_empty():
		return state.db.get("ai", {})
	var out: Dictionary = state.db.get("ai", {}).duplicate()
	out.merge(state.ai_overrides, true)
	return out


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
	var reach := state.reachable_cells(u) if state.can_move(u) else {}
	reach[u.cell] = 0
	# Under move_or_act a unit either moves or acts: actions only from where it stands.
	var act_reach := reach
	if state.turn_mode == "move_or_act" and not state._moves_and_acts(u):
		act_reach = { u.cell: 0 }
	elif state.uses_actions(u) and u.actions_left < 2:
		# Two Actions (PT Part 1): with one left, it's a move or an act, not both.
		act_reach = { u.cell: 0 }
	if state.act_block(u) != "":
		act_reach = {}
	var opponents := state.opponents_of(u)
	var taunter := state.unit_by_id(str(u.links.get("taunted_by", "")))
	if taunter != null and taunter.alive():
		opponents = [taunter]
	if opponents.is_empty():
		return out
	var acts := _actions(state, u)
	# Party AI steps out of telegraphed tiles (CU); enemies ignore their own.
	var danger := {}
	if u.team == "party":
		for m in reach:
			var cell: Vector2i = m
			var d := float(state.threat_at(cell, u.team))
			if cell != u.cell:
				# Moving doesn't dodge a tracking attack unless it gets out of reach.
				d += float(state.tracking_threat(u, cell))
			danger[m] = d * float(c.get("dodgeWeight", 1.2))
	# Teamwork (AR): enemies stay out of each other's telegraphs and spread their
	# own over different tiles, so the safe ground keeps shrinking.
	var claimed := {}
	if u.team == "enemy":
		for o in state.units:
			if o != u and o.team == "enemy" and o.alive():
				for cell in state.intent_cells(o):
					claimed[cell] = int(claimed.get(cell, 0)) + 1
		for m in reach:
			if claimed.has(m):
				danger[m] = float(c.get("avoidOwnTelegraphs", 3.0))
	var keep_back: bool = u.team == "enemy" and str(u.source.get("behavior", "")) in ["healer", "summoner", "sniper"]
	for act in acts:
		var spec: Dictionary = act["spec"]
		var best := {}
		for m in act_reach:
			var targets := _candidate_targets(state, u, act, m, opponents)
			for t in targets:
				var ev := _ev_at(state, u, spec, m, t)
				if ev <= 0.0:
					continue
				ev -= float(reach[m]) * float(c.get("moveCostPerStep", 0.05))
				ev -= float(danger.get(m, 0.0))
				if claimed.has(t):
					ev -= float(claimed[t]) * float(c.get("staggerPenalty", 1.5))
				if u.team == "enemy" and (bool(spec.get("ranged", false)) or keep_back):
					# Ranged enemies keep their distance.
					var gap := 99
					var nearest: UnitScript = null
					for o in opponents:
						if GridScript.manhattan(o.cell, m) < gap:
							gap = GridScript.manhattan(o.cell, m)
							nearest = o
					ev += float(mini(gap, 4)) * float(c.get("rangedSpacing", 0.6))
					# Snipers and casters like to shoot from behind cover (CT Part 3).
					if nearest != null:
						ev += (1.0 - state.cover_mul(nearest.cell, m, true)) * float(c.get("coverSeek", 1.5))
				if best.is_empty() or ev > float(best["ev"]):
					best = { "kind": act["kind"], "move": m, "target": t, "ev": ev, "profile": act["profile"],
						"action": act.get("action", {}), "hand": act.get("hand", -1), "card": act.get("card", {}) }
		if not best.is_empty():
			out.append(best)
		# Move OR act: moving into position for next turn's attack, valued by that attack.
		if act_reach.size() == 1 and reach.size() > 1 and str(act["kind"]) != "strike_free":
			var setup := {}
			for m in reach:
				if m == u.cell:
					continue
				for t in _candidate_targets(state, u, act, m, opponents):
					var ev := _ev_at(state, u, spec, m, t) * float(c.get("approachFactor", 0.6)) - float(danger.get(m, 0.0))
					ev -= float(reach[m]) * float(c.get("moveCostPerStep", 0.05))
					if ev > 0.0 and (setup.is_empty() or ev > float(setup["ev"])):
						setup = { "kind": "move", "move": m, "target": m, "ev": ev, "profile": act["profile"] }
			if not setup.is_empty():
				out.append(setup)
	# Long fights: running away stops looking like a plan (no endless kiting).
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
			"ev": (float(c.get("retreatBase", 2.0)) + float(c.get("retreatHurt", 10.0)) * (1.0 - u.hp_ratio()))
				* maxf(0.05, 1.0 - float(state.round_num) / float(c.get("retreatFadeRounds", 12))) })
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
			"ev": float(c.get("advanceBase", 3.0)) + (2.0 if nearest_dist > 3 else 0.0) - float(danger.get(near_cell, 0.0)) })
	# Dodge: standing in a telegraph, step to the nearest safe tile.
	if float(danger.get(u.cell, 0.0)) > 0.0:
		var safe := u.cell
		var safe_d := 999
		for m in reach:
			if float(danger.get(m, 0.0)) <= 0.0 and int(reach[m]) < safe_d:
				safe_d = int(reach[m])
				safe = m
		if safe != u.cell:
			out.append({ "kind": "move", "move": safe, "target": safe, "profile": c.get("retreat", { "courage": -1.0 }),
				"ev": float(danger[u.cell]) })
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


## An enemy's telegraphed next action (CU), chosen like a normal turn and
## then frozen: the tiles it will hit, where it will stand, any charge-up.
static func plan_intent(state: StateScript, u: UnitScript) -> Dictionary:
	var special := _behavior_intent(state, u)
	if not special.is_empty():
		return special
	# Planned during someone else's turn: score moves with next turn's Movement.
	# Its own last turn's flags don't apply to the turn being planned.
	var turn_flags := [u.move_left, u.action_used, u.quick_used, u.moved_steps]
	u.move_left = 0 if u.statuses.has("root") else maxi(0, u.movement - (1 if u.statuses.has("slow") else 0))
	u.action_used = false
	u.quick_used = false
	u.moved_steps = 0
	var plan := choose(state, u)
	u.move_left = turn_flags[0]
	u.action_used = turn_flags[1]
	u.quick_used = turn_flags[2]
	u.moved_steps = turn_flags[3]
	if plan.is_empty():
		return {}
	match str(plan["kind"]):
		"move":
			if state.turn_mode == "two_actions":
				# Nothing in reach: both Actions are moves.
				return { "kind": "move", "move": _far_move(state, u, plan["move"]), "cells": [], "double_move": true }
			return { "kind": "move", "move": plan["move"], "cells": [] }
		"guard":
			return { "kind": "defend", "move": u.cell, "cells": [] }
	var action: Dictionary = plan.get("action", {})
	var spec := state.action_spec(u, action)
	var m: Vector2i = plan["move"]
	var target: Vector2i = plan["target"]
	if bool(spec["heal"]):
		return { "kind": "buff", "action": action, "move": m, "target": target, "cells": [target] }
	var charge := int(action.get("charge", 0)) + int(state.mutator_rules().get("chargeAll", 0))
	if charge > 0:
		# Charging attacks are aimed from where the unit stands now.
		m = u.cell
	var cells := attack_cells(state, u, action, m, target)
	var tracked := state.unit_at(target)
	# Attacks lock their tiles (dodge by stepping off them). Tracking attacks,
	# which follow their target, are rare and marked in data ("intent": "tracking").
	var mode := str(action.get("intent", u.source.get("intent", "locked")))
	var it := { "kind": "special" if charge > 0 or action.has("pattern") else "attack", "action": action, "move": m, "target": target,
		"cells": cells, "mode": mode, "unit": tracked.id if tracked != null else "", "charge": charge }
	if u.double_attack and m == u.cell and charge == 0 and not action.has("pattern") and not bool(action.get("summon", false)):
		# Already in reach: both Actions are this attack (PT Part 1).
		it["repeat"] = 2
	return it


## A move + move plan: carry on in the planned direction with double Movement.
static func _far_move(state: StateScript, u: UnitScript, first: Vector2i) -> Vector2i:
	if first == u.cell:
		return first
	var aim := first + (first - u.cell)
	var reach := state.grid.reachable(u.cell, u.movement * 2, state.occupied(u))
	var best := first
	for c in reach:
		var cell: Vector2i = c
		if state.unit_at(cell) == null and GridScript.manhattan(cell, aim) < GridScript.manhattan(best, aim):
			best = cell
	return best


## The tiles an action hits when used from cell m at target.
static func attack_cells(state: StateScript, u: UnitScript, action: Dictionary, m: Vector2i, target: Vector2i) -> Array:
	var spec := state.action_spec(u, action)
	if action.has("pattern"):
		var saved := u.cell
		u.cell = m
		var cells := state.pattern_cells(u, str(action["pattern"]), target)
		u.cell = saved
		return cells
	if str(spec["kind"]) == "strike":
		return [target]
	var occ := state.occupied(u)
	occ[m] = u
	return Forms.footprint(state.grid, spec["form"], m, target, occ)


## Behaviors that plan differently from "pick the best action" (docs/ARENA.md Part 4).
static func _behavior_intent(state: StateScript, u: UnitScript) -> Dictionary:
	var src: Dictionary = u.source
	match str(src.get("behavior", "")):
		"summoner":
			var every := maxi(1, int(src.get("summonEvery", 2)))
			if u.turns_taken % every == 0:
				var spot := Vector2i(-1, -1)
				for d in GridScript.DIRS:
					var c: Vector2i = u.cell + d
					if state.grid.walkable_terrain(c) and state.unit_at(c) == null:
						spot = c
						break
				if spot.x >= 0:
					return { "kind": "special", "action": { "id": "summon", "name": "Summon", "summon": true, "form": "touch" }, "move": u.cell,
						"target": spot, "cells": [spot], "mode": "locked", "charge": 0, "summon": true }
		"burrower":
			if not u.statuses.has("burrowed"):
				var near := false
				for o in state.opponents_of(u):
					near = near or GridScript.manhattan(o.cell, u.cell) == 1
				if not near:
					return { "kind": "special", "action": { "id": "burrow", "name": "Burrow", "burrow": true, "form": "touch" }, "move": u.cell,
						"target": u.cell, "cells": [], "mode": "locked", "charge": 0 }
	return {}


## Run a whole AI turn: carry out the intent (enemies) or choose, move, act, end turn.
static func take_turn(state: StateScript, u: UnitScript) -> Dictionary:
	if u.team == "enemy" and not u.intent.is_empty():
		var it: Dictionary = u.intent
		if state.execute_intent(u):
			if state.result == "" and state.current == u:
				state.end_turn()
			return it
	if state.uses_actions(u):
		return _party_turn(state, u)
	var plan := choose(state, u)
	if plan.is_empty():
		u.intent = {}
		state.end_turn()
		return plan
	u.intent = {}
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


## A party turn under two Actions: pick and carry out plans until the Actions
## run out (a plan can be move + act), then Strike with the Quick if a foe is
## adjacent, then end the turn.
static func _party_turn(state: StateScript, u: UnitScript) -> Dictionary:
	var last := {}
	for i in 4:
		if state.result != "" or not u.alive() or state.current != u:
			break
		var before := [u.actions_left, u.quick_used, u.cell, u.mp]
		var plan := choose(state, u)
		if plan.is_empty():
			break
		last = plan
		if str(plan["kind"]) == "guard":
			# Guard is a Quick: take it, then keep using the Actions (P2 fix).
			if not state.guard(u) or u.actions_left <= 0:
				break
			continue
		if plan["move"] != u.cell:
			state.move(u, plan["move"])
		if state.result == "" and u.alive():
			match str(plan["kind"]):
				"card":
					var idx := _find_hand(u, plan["card"])
					if idx >= 0:
						state.play_card(u, idx, plan["target"])
				"strike":
					state.strike(u, plan["target"])
				"cantrip":
					state.cast_cantrip(u, plan["target"])
		if [u.actions_left, u.quick_used, u.cell, u.mp] == before:
			break
	if state.result == "" and state.current == u and u.alive() and state.quick_block(u) == "":
		var adj := state._adjacent_hostiles(u, 1)
		if not adj.is_empty():
			state.strike(u, adj[0])
	if state.result == "" and state.current == u:
		state.end_turn()
	return last


## An effect's number on a card ("heal" amount, "lunge" tiles), or 0.
static func _effect_amount(card: Dictionary, op: String, key: String) -> int:
	for e in card.get("effects", []):
		if str(e.get("op", "")) == op:
			return int(e.get(key, 1))
	return 0


static func _has_op(card: Dictionary, op: String) -> bool:
	for e in card.get("effects", []):
		if str(e.get("op", "")) == op:
			return true
	return false


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
		var actions: Array = u.actions.duplicate()
		# Mirrors copy the last card the party played.
		if str(u.source.get("behavior", "")) == "mirror" and not state.last_party_card.is_empty():
			var card: Dictionary = state.last_party_card
			actions.append({ "id": "mirror", "name": Str.t(state.db, "enemy_ai.mirror") % card.get("name", "?"), "form": str(card.get("form", "bolt")),
				"vectors": card.get("vectors", {}), "power": CardRules.power(state.db, card), "magnitude": str(card.get("magnitude", "standard")),
				"profile": { "curiosity": 1.0 } })
		for a in actions:
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
			if card.is_empty() or state.card_block(u, card) != "":
				continue
			if CardRules.is_spell(card):
				var fid := str(card.get("form", ""))
				if fid in ["weapon_infusion", "construct", "glyph", "aura"]:
					continue
				# Effect-only and no-damage cards aren't damage casts; the AI uses the ones it understands below.
				if bool(card.get("effectsOnly", false)) or bool(card.get("noDamage", false)):
					var heal := _effect_amount(card, "heal", "amount") + _effect_amount(card, "ward", "amount")
					if heal > 0:
						out.append({ "kind": "card", "card": card, "spec": { "kind": "spell", "heal": true, "power": float(heal), "vectors": {}, "form": { "footprint": "single_los", "target": "ally", "range": int(card.get("targeting", {}).get("range", 3)) }, "mult": 1.0, "ranged": true },
							"profile": c.get("guard", { "loyalty": 0.5 }), "targets": "card" })
					continue
				out.append({ "kind": "card", "card": card, "spec": state._spell_spec(u, card), "profile": c.get("attack", { "courage": 0.6 }) })
			elif str(card.get("action", "")) == "effects" and (_effect_amount(card, "hit_and_run", "tiles") > 0 or _has_op(card, "shadow_step")):
				# Hit and Run, Shadow Step: a DEX strike (Shadow Step from range 3).
				var eff: Dictionary = card["effects"][0]
				var hb := float(u.stats.get(str(eff.get("stat", "dex")), 5)) * float(eff.get("mult", 1.0))
				out.append({ "kind": "card", "card": card, "spec": { "kind": "strike", "base": hb, "vectors": {}, "form": state.form_rec("touch"), "power": 0.0, "mult": 1.0, "heal": false, "ranged": false },
					"profile": c.get("attack", { "courage": 0.6 }), "targets": "card" })
			elif str(card.get("action", "")) == "effects" and _effect_amount(card, "lunge", "tiles") > 0:
				# Lunge: closes in and strikes in one action.
				var lb := float(u.stats.get("str", 5)) * float(card["effects"][0].get("mult", 1.0))
				out.append({ "kind": "card", "card": card, "spec": { "kind": "strike", "base": lb, "vectors": {}, "form": state.form_rec("touch"), "power": 0.0, "mult": 1.0, "heal": false, "ranged": false },
					"profile": c.get("attack", { "courage": 0.6 }), "targets": "card" })
			elif str(card.get("action", "")) == "strike":
				var base := float(u.stats.get(str(card.get("stat", "str")), 5)) * float(card.get("mult", 1.0))
				out.append({ "kind": "card", "card": card, "spec": { "kind": "strike", "base": base, "vectors": {}, "form": state.form_rec("touch"), "power": 0.0, "mult": 1.0, "heal": false, "ranged": false },
					"profile": c.get("attack", { "courage": 0.6 }) })
	if u.team == "party" and state.turn_mode == "two_actions" and not state.cantrip_spec(u).is_empty() and state.act_block(u) == "":
		out.append({ "kind": "cantrip", "spec": state.cantrip_spec(u), "profile": c.get("attack", { "courage": 0.6 }) })
	if (state.quick_block(u) == "") if (u.team == "party" and state.turn_mode == "two_actions") else not u.action_used:
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
	if str(act.get("targets", "")) == "card":
		valid = state.card_targets(u, act["card"])
		u.cell = saved
		return valid
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
		if u.team == "enemy":
			# Focus fire, weighted: the wounded and the isolated draw more attacks.
			if o.hp_ratio() < 0.5:
				ev *= float(cfg(state).get("focusWounded", 1.2))
			var alone := true
			for a in state.allies_of(o):
				if a != o and GridScript.manhattan(a.cell, o.cell) <= 2:
					alone = false
			if alone:
				ev *= float(cfg(state).get("focusIsolated", 1.15))
			if o.statuses.has("taunting"):
				ev *= float(cfg(state).get("tauntPull", 2.0))
	u.cell = saved
	return ev

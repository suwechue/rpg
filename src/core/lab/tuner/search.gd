## Searching the lever space (docs/LAB_TUNER.md Part 4): an evolutionary search
## over a few levers and their values, run one generation at a time so the sweep
## tool can play each generation's fights in parallel. Also the effect sizes
## from screening, the pairs, and a shortlist that differs from itself.
## Pure data.
extends RefCounted

const Metrics := preload("res://src/core/lab/tuner/metrics.gd")
const Sweep := preload("res://src/core/lab/sweep.gd")


## A lever set as a stable string (for caching and telling sets apart).
static func set_key(levers: Dictionary) -> String:
	var keys: Array = levers.keys()
	keys.sort()
	var parts: Array = []
	for k in keys:
		parts.append("%s=%s" % [k, Sweep.norm(levers[k])])
	return ",".join(PackedStringArray(parts))


## How many levers two sets set differently (a lever left out = the base value).
static func distance(a: Dictionary, b: Dictionary, base: Dictionary = {}) -> int:
	var keys := {}
	for k in a:
		keys[k] = true
	for k in b:
		keys[k] = true
	var n := 0
	for k in keys:
		if Sweep.norm(a.get(k, base.get(k))) != Sweep.norm(b.get(k, base.get(k))):
			n += 1
	return n


# --- Screening and pairs -------------------------------------------------------

## Each lever's effect on every metric and the fun score, against its base.
## variants: from Plan.screen_variants; metrics_by_group: group -> metrics row.
## Returns [{ base, lever, value, delta: { metric: change }, score, base_score, verdict }].
static func effects(variants: Array, metrics_by_group: Dictionary, scores: Dictionary, t: Dictionary) -> Array:
	var out: Array = []
	var eps := float(t.get("effectEpsilon", 0.02))
	for v in variants:
		if str(v["lever"]) == "":
			continue
		var g := str(v["group"])
		var bg := "screen:%s" % v["base"]
		if not metrics_by_group.has(g) or not metrics_by_group.has(bg):
			continue
		var m: Dictionary = metrics_by_group[g]
		var bm: Dictionary = metrics_by_group[bg]
		var delta := {}
		for k in t.get("metrics", {}):
			if float(m.get(k, -1.0)) >= 0.0 and float(bm.get(k, -1.0)) >= 0.0:
				delta[k] = snappedf(float(m[k]) - float(bm[k]), 0.001)
		var s := float(scores[g]["score"])
		var bs := float(scores[bg]["score"])
		var verdict := "neutral"
		if bool(scores[g]["dq"]) and not bool(scores[bg]["dq"]):
			verdict = "hurts"
		elif s - bs > eps:
			verdict = "helps"
		elif s - bs < -eps:
			verdict = "hurts"
		out.append({ "base": v["base"], "lever": v["lever"], "value": v["value"], "delta": delta, "score": s, "base_score": bs, "verdict": verdict,
			"dq": scores[g]["dq"], "reasons": scores[g]["reasons"] })
	return out


## The best value per lever and its gain, best first (one row per lever and base).
static func top_levers(effect_rows: Array, n: int, base: String = "") -> Array:
	var best := {}
	for r in effect_rows:
		if base != "" and str(r["base"]) != base:
			continue
		var gain := float(r["score"]) - float(r["base_score"])
		var k := str(r["lever"])
		if not best.has(k) or gain > float(best[k]["gain"]):
			best[k] = { "lever": k, "value": r["value"], "gain": gain, "base": r["base"] }
	var rows: Array = best.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["gain"]) > float(b["gain"]))
	return rows.slice(0, n)


## Every pair of the top levers, each at its best value.
static func pair_sets(top: Array, base: String) -> Array:
	var out: Array = []
	for i in top.size():
		for j in range(i + 1, top.size()):
			var a: Dictionary = top[i]
			var b: Dictionary = top[j]
			var lv := { str(a["lever"]): a["value"], str(b["lever"]): b["value"] }
			out.append({ "group": "pair:%s|%s" % [base, set_key(lv)], "base": base, "levers": lv, "a": a["lever"], "b": b["lever"] })
	return out


## A pair against its levers alone: "good together" when the pair beats the
## better single by more than epsilon, "bad together" when it falls under the worse.
static func pair_verdict(pair_score: float, a_score: float, b_score: float, eps: float) -> String:
	if pair_score > maxf(a_score, b_score) + eps:
		return "good together"
	if pair_score < minf(a_score, b_score) - eps:
		return "bad together"
	return "adds up"


# --- The search ----------------------------------------------------------------

## space: [{ lever, values: [...] }]. A fresh search state.
static func start(space: Array, base: String, seeds: Array = []) -> Dictionary:
	return { "space": space, "base": base, "pop": [], "seen": {}, "gen": 0, "seeds": seeds }


static func random_set(space: Array, rng: RandomNumberGenerator, on_share: float = 0.3) -> Dictionary:
	var out := {}
	for s in space:
		if rng.randf() < on_share:
			var vals: Array = s["values"]
			out[str(s["lever"])] = vals[rng.randi_range(0, vals.size() - 1)]
	return out


static func mutate(levers: Dictionary, space: Array, rng: RandomNumberGenerator) -> Dictionary:
	var out := levers.duplicate()
	for i in rng.randi_range(1, 2):
		var s: Dictionary = space[rng.randi_range(0, space.size() - 1)]
		var id := str(s["lever"])
		if out.has(id) and rng.randf() < 0.4:
			out.erase(id)
		else:
			var vals: Array = s["values"]
			out[id] = vals[rng.randi_range(0, vals.size() - 1)]
	return out


static func crossover(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for k in a:
		if rng.randf() < 0.5:
			out[k] = a[k]
	for k in b:
		if not out.has(k) and rng.randf() < 0.5:
			out[k] = b[k]
	return out


## The next n lever sets to try: the seeds first, then children of the best
## (mutation and crossover) and a share of random restarts. Never a set already tried.
static func propose(state: Dictionary, n: int, rng: RandomNumberGenerator, restart_share: float = 0.2) -> Array:
	var out: Array = []
	var space: Array = state["space"]
	var tries := 0
	var queue: Array = (state["seeds"] as Array).duplicate()
	state["seeds"] = []
	while out.size() < n and tries < n * 50:
		tries += 1
		var cand: Dictionary
		if not queue.is_empty():
			cand = queue.pop_front()
		elif state["pop"].is_empty() or rng.randf() < restart_share:
			cand = random_set(space, rng)
		else:
			var pop: Array = state["pop"]
			var a: Dictionary = pop[mini(pop.size() - 1, rng.randi_range(0, mini(3, pop.size() - 1)))]["levers"]
			if pop.size() > 1 and rng.randf() < 0.3:
				var b: Dictionary = pop[rng.randi_range(0, pop.size() - 1)]["levers"]
				cand = mutate(crossover(a, b, rng), space, rng) if rng.randf() < 0.5 else crossover(a, b, rng)
			else:
				cand = mutate(a, space, rng)
		var k := set_key(cand)
		if state["seen"].has(k) or out.any(func(o: Dictionary) -> bool: return set_key(o) == k):
			continue
		out.append(cand)
	return out


## Add scored sets ([{ levers, score, dq, ... }]) and keep the best `keep`.
## Disqualified sets rank under every allowed one.
static func absorb(state: Dictionary, scored: Array, keep: int = 24) -> void:
	for s in scored:
		state["seen"][set_key(s["levers"])] = true
		state["pop"].append(s)
	state["pop"].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return rank(a) > rank(b))
	state["pop"] = (state["pop"] as Array).slice(0, keep)
	state["gen"] = int(state["gen"]) + 1


static func rank(s: Dictionary) -> float:
	return float(s.get("score", 0.0)) - (10.0 if bool(s.get("dq", false)) else 0.0)


## The best sets that differ from each other by at least min_distance levers.
static func shortlist(scored: Array, n: int, min_distance: int, base: Dictionary = {}) -> Array:
	var sorted := scored.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return rank(a) > rank(b))
	var out: Array = []
	for s in sorted:
		var ok := true
		for o in out:
			if distance(s["levers"], o["levers"], base) < min_distance:
				ok = false
				break
		if ok:
			out.append(s)
		if out.size() >= n:
			break
	return out

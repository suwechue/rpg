## The Vector system operations (see docs/vector_system.md).
## A vector is a Dictionary { axis_name: number }, stored raw. A missing axis is 0.
## Every function is pure: inputs are never modified, and randomness only comes
## from the RandomNumberGenerator passed in, so results are reproducible in tests.
## Note: the design doc calls cosine similarity "Match"; it is named `similarity`
## here because `match` is a reserved word in GDScript.
class_name VectorOps
extends RefCounted


static func total(v: Dictionary) -> float:
	var t := 0.0
	for axis in v:
		t += float(v[axis])
	return t


## Number of axes with weight above zero.
static func spread(v: Dictionary) -> int:
	var n := 0
	for axis in v:
		if float(v[axis]) > 0.0:
			n += 1
	return n


## Complexity = total / 10 + (spread - 1) x 3 (invention / card crafting).
static func complexity(v: Dictionary) -> float:
	return total(v) / 10.0 + float(spread(v) - 1) * 3.0


static func length(v: Dictionary) -> float:
	var s := 0.0
	for axis in v:
		var x := float(v[axis])
		s += x * x
	return sqrt(s)


## Scale so the weights sum to 1 (odds). A zero vector has no direction and returns {}.
static func normalize_sum(v: Dictionary) -> Dictionary:
	var t := total(v)
	if t <= 0.0:
		return {}
	var out := {}
	for axis in v:
		out[axis] = float(v[axis]) / t
	return out


## Scale to length 1 (direction only). A zero vector returns {}.
static func normalize_len(v: Dictionary) -> Dictionary:
	var l := length(v)
	if l <= 0.0:
		return {}
	var out := {}
	for axis in v:
		out[axis] = float(v[axis]) / l
	return out


## Match: cosine similarity, 0 (nothing in common) to 1 (same proportions).
## Ignores size. A zero vector matches nothing (0).
static func similarity(a: Dictionary, b: Dictionary) -> float:
	var la := length(a)
	var lb := length(b)
	if la <= 0.0 or lb <= 0.0:
		return 0.0
	var dot := 0.0
	for axis in a:
		if b.has(axis):
			dot += float(a[axis]) * float(b[axis])
	return dot / (la * lb)


## Blend: weighted sum of vectors. Missing weights default to 1.0.
## Normalize the result yourself if it will be used as odds.
static func blend(vs: Array, weights: Array = []) -> Dictionary:
	var out := {}
	for i in vs.size():
		var w := 1.0
		if i < weights.size():
			w = float(weights[i])
		var v: Dictionary = vs[i]
		for axis in v:
			out[axis] = float(out.get(axis, 0.0)) + w * float(v[axis])
	return out


## Shift: add delta, then apply caps (per-axis maximum) and a floor.
## Use min_value = -100.0 for signed spaces such as Bond and disposition.
static func shift(v: Dictionary, delta: Dictionary, caps: Dictionary = {}, min_value: float = 0.0) -> Dictionary:
	var out := v.duplicate()
	for axis in delta:
		var x := float(out.get(axis, 0.0)) + float(delta[axis])
		if caps.has(axis):
			x = minf(x, float(caps[axis]))
		x = maxf(x, min_value)
		out[axis] = x
	return out


## Sample: pick one axis by weight. axis_order fixes the walk order so results are
## deterministic; axes not listed in it are appended alphabetically.
## A zero vector falls back to equal odds over the known axes.
static func sample(p: Dictionary, rng: RandomNumberGenerator, axis_order: Array = []) -> String:
	var order := ordered_axes(p, axis_order)
	var t := 0.0
	for axis in order:
		t += maxf(float(p.get(axis, 0.0)), 0.0)
	if t <= 0.0:
		if order.is_empty():
			return ""
		return str(order[rng.randi_range(0, order.size() - 1)])
	var r := rng.randf() * t
	var acc := 0.0
	var last_positive := ""
	for axis in order:
		var w := maxf(float(p.get(axis, 0.0)), 0.0)
		if w <= 0.0:
			continue
		acc += w
		last_positive = str(axis)
		if r < acc:
			return str(axis)
	return last_positive


## Sample several axes without repeats. Stops early when nothing with weight is left.
static func sample_unique(p: Dictionary, rng: RandomNumberGenerator, count: int, axis_order: Array = []) -> Array:
	var pool := p.duplicate()
	var picks: Array = []
	while picks.size() < count:
		if total(pool) <= 0.0:
			break
		var axis := sample(pool, rng, axis_order)
		if axis == "":
			break
		picks.append(axis)
		pool.erase(axis)
	return picks


## Contest: sum of attack axes, each multiplied by its matchup against the defender.
## defense = { "weakTo": [...], "strongAgainst": [...] }
## matchups = { "weak": 1.5, "neutral": 1.0, "strong": 0.6 } (data/matchups.json)
static func contest(attack: Dictionary, defense: Dictionary, matchups: Dictionary) -> float:
	var weak: Array = defense.get("weakTo", [])
	var strong: Array = defense.get("strongAgainst", [])
	var result := 0.0
	for axis in attack:
		var m := float(matchups.get("neutral", 1.0))
		if weak.has(axis):
			m = float(matchups.get("weak", 1.5))
		elif strong.has(axis):
			m = float(matchups.get("strong", 0.6))
		result += float(attack[axis]) * m
	return result


## Gate: true only if every threshold axis is reached.
static func gate(v: Dictionary, thresholds: Dictionary) -> bool:
	for axis in thresholds:
		if float(v.get(axis, 0.0)) < float(thresholds[axis]):
			return false
	return true


## Tiered gate. lines = [{ "min": number, "name": String }, ...] in any order.
## Returns the name of the highest line reached, or "" if none.
static func gate_tier(value: float, lines: Array) -> String:
	var best := ""
	var best_min := -INF
	for line in lines:
		var m := float(line["min"])
		if value >= m and m >= best_min:
			best = str(line["name"])
			best_min = m
	return best


## Decay: move each axis a fraction `rate` of the way toward its resting value.
static func decay(v: Dictionary, rate: float, rest: Dictionary = {}) -> Dictionary:
	var axes: Array = v.keys()
	for axis in rest:
		if not axes.has(axis):
			axes.append(axis)
	var out := {}
	for axis in axes:
		var x := float(v.get(axis, 0.0))
		var r := float(rest.get(axis, 0.0))
		out[axis] = x + rate * (r - x)
	return out


## The axis with the largest weight. Ties go to the earliest axis in axis_order.
## Returns "" for a zero vector.
static func dominant_axis(v: Dictionary, axis_order: Array = []) -> String:
	var best := ""
	var best_w := 0.0
	for axis in ordered_axes(v, axis_order):
		var w := float(v.get(axis, 0.0))
		if w > best_w:
			best = str(axis)
			best_w = w
	return best


## axis_order first, then any other axes of v alphabetically.
static func ordered_axes(v: Dictionary, axis_order: Array = []) -> Array:
	var order: Array = axis_order.duplicate()
	var extra: Array = []
	for axis in v:
		if not order.has(axis):
			extra.append(axis)
	extra.sort()
	order.append_array(extra)
	return order

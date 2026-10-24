## Conversation rules (DESIGN.md Section 12): which topics are available,
## how a line is received (Match of the listener's disposition and the line's
## tone, adjusted by mood and Bond), and misinterpretation (a misheard version
## is Sampled from the line's alternates and scored instead).
class_name DialogueCheck
extends RefCounted

const VO := preload("res://src/core/vector_ops.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Char := preload("res://src/core/character.gd")

const MOODS := ["good", "neutral", "bad"]


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("social", {})


static func npc(db: Dictionary, id: String) -> Dictionary:
	return db.get("npcs/" + id, {})


static func bond_tier(db: Dictionary, value: float) -> String:
	return VO.gate_tier(value, db.get("bonds", {}).get("tiers", []))


static func tier_rank(db: Dictionary, tier: String) -> int:
	var names: Array = []
	for t in db.get("bonds", {}).get("tiers", []):
		names.append(str(t["name"]))
	return names.find(tier)


## Today's mood for an NPC: a seeded draw per NPC per day (good, neutral, bad).
static func mood(db: Dictionary, run: Dictionary, id: String, day_count: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mood:%d:%d:%s" % [int(run.get("seed", 0)), day_count, id])
	var w: Dictionary = cfg(db).get("moodWeights", { "good": 3, "neutral": 5, "bad": 2 })
	return VO.sample(w, rng, MOODS)


## The listener's current disposition (run state, falling back to data).
static func disposition(db: Dictionary, run: Dictionary, id: String) -> Dictionary:
	var st: Dictionary = run.get("npcs", {}).get(id, {})
	if st.has("disposition") and not st["disposition"].is_empty():
		return st["disposition"]
	return npc(db, id).get("disposition", {})


## Why a topic is locked, or "" if you can bring it up. Locked topics show greyed.
static func topic_lock(db: Dictionary, run: Dictionary, id: String, topic: Dictionary, ctx: Dictionary) -> String:
	var gate: Dictionary = topic.get("gate", {})
	if not gate.is_empty():
		var st := Char.effective_stats(db, run["player"])
		for s in gate:
			if int(st.get(s, 0)) < int(gate[s]):
				return "%s %d" % [str(s).to_upper(), int(gate[s])]
	if topic.has("minTier"):
		var have := tier_rank(db, bond_tier(db, RM.bond(run, id)))
		if have < tier_rank(db, str(topic["minTier"])):
			return "Bond: %s" % topic["minTier"]
	if topic.has("needItem") and int(run.get("inventory", {}).get(str(topic["needItem"]), 0)) <= 0:
		return "Needs an item"
	if not Fx.conditions_met(db, run, topic.get("cond", {}), ctx):
		return str(topic.get("lockedHint", "Not yet"))
	return ""


## Topics to list now: unlocked ones, plus locked ones that show a hint.
## Topics used this week (or ever, if "once") are hidden.
static func topics(db: Dictionary, run: Dictionary, id: String, ctx: Dictionary) -> Array:
	var out: Array = []
	var used: Dictionary = run.get("npcs", {}).get(id, {}).get("topics", {})
	for t in npc(db, id).get("topics", []):
		var tid := str(t["id"])
		if used.has(tid) and (bool(t.get("once", false)) or int(used[tid]) == int(ctx.get("week", 0))):
			continue
		if bool(t.get("hidden", false)) and topic_lock(db, run, id, t, ctx) != "":
			continue
		out.append(t)
	return out


## Chance the line is misheard: base x (1 - CHA / 25) x mood x traits, min 2%.
static func misheard_chance(db: Dictionary, run: Dictionary, base_risk: float, mood_name: String) -> float:
	var m: Dictionary = db.get("stats", {}).get("misinterpretation", {})
	var cha := float(Char.effective_stats(db, run["player"]).get("cha", 5))
	var c := base_risk * (1.0 - cha / float(m.get("chaDivisor", 25)))
	if mood_name == "bad":
		c *= float(m.get("badMoodMultiplier", 1.5))
	c *= float(Char.collect_mods(db, run["player"]).get("social", {}).get("misinterpretMul", 1.0))
	return maxf(c, float(m.get("minimum", 0.02)))


## Reception score -1..1: Match(disposition, tone) + mood + Bond.
static func reception(db: Dictionary, run: Dictionary, id: String, tone: Dictionary, mood_name: String) -> float:
	var c := cfg(db)
	var score := VO.similarity(disposition(db, run, id), tone)
	score += float(c.get("moodShift", {}).get(mood_name, 0.0))
	score += RM.bond(run, id) / float(c.get("bondDivisor", 400))
	return clampf(score, -1.0, 1.0)


## Say a topic. Returns { "misheard": bool, "said", "heard", "score", "bond",
## "outcome": "good" | "neutral" | "bad", "text", "lines" }. Applies effects.
static func say(db: Dictionary, run: Dictionary, id: String, topic: Dictionary, rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	var c := cfg(db)
	var day_count := int(run.get("day_count", 0))
	var mood_name := mood(db, run, id, day_count)
	var base := float(topic.get("baseRisk", c.get("defaultRisk", 0.05)))
	var tone: Dictionary = topic.get("tone", {})
	var said := str(topic.get("line", topic.get("label", "")))
	var heard := said
	var misheard := rng.randf() < misheard_chance(db, run, base, mood_name)
	if misheard:
		var alts: Array = topic.get("misheard", [])
		if alts.is_empty():
			alts = c.get("genericMisheard", [])
		var pick: Variant = alts[rng.randi_range(0, alts.size() - 1)]
		if typeof(pick) == TYPE_DICTIONARY:
			heard = str(pick.get("line", said)).replace("{line}", said)
			tone = pick.get("tone", _flip(tone))
		else:
			heard = str(pick).replace("{line}", said)
			tone = _flip(tone)
	var score := reception(db, run, id, tone, mood_name)
	var upside := 1.0 + base * float(c.get("riskUpside", 1.5))
	var delta := clampf(score * 10.0 * (upside if score > 0.0 else 1.0), -10.0, 10.0)
	var outcome := "neutral"
	if score >= float(c.get("goodAt", 0.2)):
		outcome = "good"
	elif score <= float(c.get("badAt", -0.05)):
		outcome = "bad"
	if outcome == "neutral":
		delta = float(c.get("neutralBond", 1))
	if misheard and outcome == "good":
		outcome = "neutral"
		delta = minf(delta, 2.0)
	var lines: Array = []
	var after := Fx.change_bond(db, run, id, delta, lines)
	var fx: Dictionary = topic.get("outcomes", {}).get("onGood" if outcome == "good" else ("onBad" if outcome == "bad" else "onNeutral"), {})
	var fx_lines := Fx.apply(db, run, fx, rng, ctx)
	var st: Dictionary = Fx.npc_state(run, id)
	st["topics"][str(topic.get("id", ""))] = int(ctx.get("week", 0))
	st["met"] = true
	var text := str(topic.get("goodText" if outcome == "good" else ("badText" if outcome == "bad" else "neutralText"), ""))
	if text == "":
		text = str(c.get("defaultReaction", {}).get(outcome, "..."))
	return { "misheard": misheard, "said": said, "heard": heard, "score": score, "bond": after, "delta": delta,
		"outcome": outcome, "text": text, "lines": lines + fx_lines, "mood": mood_name }


## A misheard line reads as the opposite of what you meant.
static func _flip(tone: Dictionary) -> Dictionary:
	var out := {}
	for k in tone:
		out[k] = -float(tone[k])
	return out

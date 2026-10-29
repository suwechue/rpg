## Kill-time measurements for balancing (docs/COMBAT_TUNING.md Part 1): how
## many player actions kill each enemy tier, and how much of a party member's
## HP each kind of enemy hit takes. Expected values from the real formulas
## (no crits, neutral matchups, no flanking or cover). Used by
## tools/sim_balance.gd and the balance test.
extends RefCounted

const DT := preload("res://src/core/data_tables.gd")
const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const EnemyMods := preload("res://src/core/combat/enemy_mods.gd")

const CLASSES := ["mage", "fighter", "rogue", "healer", "bard"]


static func _party(db: Dictionary, level: int) -> Array:
	var out: Array = []
	for i in CLASSES.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = 77 + i
		var ch := Char.create(db, CLASSES[i], rng, { "id": "b_" + CLASSES[i] })
		while int(ch["level"]) < level:
			Lv.add_xp(db, ch, Lv.xp_to_next(db, int(ch["level"])), rng)
		Char.full_restore(db, ch)
		out.append(ch)
	return out


## A fight with one party member and one enemy side by side (no back attack).
static func _duel(db: Dictionary, ch: Dictionary, rec: Dictionary, diff: String, week: int = 1) -> StateScript:
	# Measured where the week sits on the difficulty ramp (week 1 = the gentle start).
	var st := StateScript.new(db, RandomNumberGenerator.new(), { "layout": { "map": [".PE......"] }, "party": [{ "char": ch.duplicate(true) }],
		"enemies": [rec], "difficulty": diff, "turnMode": "move_and_act", "ramp": StateScript.ramp_for(db, week, 0) })
	st.units[0].facing = 1
	st.units[1].facing = -1
	return st


## The player's best plain option against an enemy: a Standard Bolt of their
## first Vector, or a Strike.
static func player_hit(db: Dictionary, st: StateScript) -> float:
	var p = st.units[0]
	var e = st.units[1]
	var best := 0.0
	var axes: Array = p.known_vectors
	if not axes.is_empty():
		var bolt := CardRules.make_spell(db, { str(axes[0]): 1.0 }, "bolt", "standard")
		best = st._expected_hit(p, e, st._spell_spec(p, bolt))
	best = maxf(best, st._expected_strike(p, e, { "stat": "str", "mult": 1.0 }))
	best = maxf(best, st._expected_strike(p, e, { "stat": "dex", "mult": 1.1 }))
	return maxf(best, 1.0)


## Per-tier numbers for a week: { tiers: { tier: { actions, n } }, hits: { kind: { pct, n } } }.
static func measure(db: Dictionary, week: int, level: int, diff: String) -> Dictionary:
	var party := _party(db, level)
	var scales: Array = db.get("dungeon", {}).get("weekScale", [1.0])
	var scale := float(scales[mini(week, scales.size() - 1)])
	var tiers := {}
	var hits := {}
	for e in DT.records_under(db, "enemies/", "enemies"):
		var weeks: Array = e.get("weeks", [])
		var tier := str(e.get("tier", "normal"))
		if tier != "boss" and not weeks.has(float(week)) and not weeks.has(week):
			continue
		if tier == "boss" and str(e.get("id", "")) != str(db.get("weeks", {}).get("weeks", [])[week - 1].get("boss", "")):
			continue
		var rec: Dictionary = EnemyMods.apply(db, e)
		rec["scale"] = 1.0 if tier == "boss" else scale
		var acts := 0.0
		for ch in party:
			var st := _duel(db, ch, rec.duplicate(true), diff, week)
			acts += ceilf(float(st.units[1].max_hp) / player_hit(db, st))
			var all_actions: Array = st.units[1].actions.duplicate()
			for ph in st.units[1].phases:
				all_actions.append_array(ph.get("actions", []))
			for a in all_actions:
				var spec := st.intent_spec(st.units[1], a)
				if bool(spec.get("heal", false)):
					continue
				var kind := "%s_heavy" % tier if (int(a.get("charge", 0)) > 0 or a.has("pattern")) else tier
				if str(a.get("intent", e.get("intent", "locked"))) == "tracking":
					# Tracking hits are 60% by design (PT Part 4); reported on their own.
					kind = "%s_tracking" % tier
				var pct := st._expected_hit(st.units[1], st.units[0], spec) / float(st.units[0].max_hp)
				var h: Dictionary = hits.get(kind, { "pct": 0.0, "n": 0 })
				h["pct"] = float(h["pct"]) + pct
				h["n"] = int(h["n"]) + 1
				hits[kind] = h
		var t: Dictionary = tiers.get(tier, { "actions": 0.0, "n": 0 })
		t["actions"] = float(t["actions"]) + acts / float(party.size())
		t["n"] = int(t["n"]) + 1
		tiers[tier] = t
	return { "tiers": tiers, "hits": hits, "week": week, "level": level, "difficulty": diff }


## Average player actions to kill a tier, and average share of max HP per enemy hit kind.
static func averages(r: Dictionary) -> Dictionary:
	var out := { "actions": {}, "hitPct": {} }
	for t in r["tiers"]:
		out["actions"][t] = float(r["tiers"][t]["actions"]) / float(maxi(1, int(r["tiers"][t]["n"])))
	for k in r["hits"]:
		out["hitPct"][k] = float(r["hits"][k]["pct"]) / float(maxi(1, int(r["hits"][k]["n"])))
	return out


## Printable lines with the targets from data/combat_rules.json "balanceTargets".
static func lines(db: Dictionary, r: Dictionary) -> Array:
	var tg: Dictionary = db.get("combat_rules", {}).get("balanceTargets", {})
	var av := averages(r)
	var out: Array = ["Week %d, party level %d, %s difficulty" % [int(r["week"]), int(r["level"]), str(r["difficulty"])], "Player actions to kill:"]
	for t in ["minion", "normal", "elite", "boss"]:
		if av["actions"].has(t):
			var target: Array = tg.get("actionsToKill", {}).get(t, [])
			out.append("  %-8s %5.1f   target %s" % [t, float(av["actions"][t]), str(target)])
	out.append("One enemy hit, share of a party member's max HP:")
	for k in av["hitPct"]:
		var target: Array = tg.get("hitPct", {}).get(str(k), [])
		out.append("  %-14s %4d%%   target %s" % [k, roundi(100.0 * float(av["hitPct"][k])), str(target)])
	return out

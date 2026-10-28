## CT Part 1: the week 1 kill-time targets in data/combat_rules.json
## "balanceTargets" hold (measured from the real formulas).
extends "res://tests/suite.gd"

const Report := preload("res://src/core/combat/balance_report.gd")


func test_kill_time_targets() -> void:
	var tg: Dictionary = db()["combat_rules"]["balanceTargets"]
	var av := Report.averages(Report.measure(db(), 1, 2, "normal"))
	for t in tg["actionsToKill"]:
		var r: Array = tg["actionsToKill"][t]
		var v := float(av["actions"].get(t, -1.0))
		check(v >= float(r[0]) - 0.05 and v <= float(r[1]) + 0.05, "%s: %.1f player actions to kill (target %s)" % [t, v, str(r)])
	for k in av["hitPct"]:
		if not tg["hitPct"].has(k):
			continue
		var r: Array = tg["hitPct"][k]
		var v := float(av["hitPct"][k])
		check(v >= float(r[0]) - 0.01 and v <= float(r[1]) + 0.01, "%s hit: %d%% of a party member's HP (target %s)" % [k, roundi(v * 100.0), str(r)])


func test_one_damage_number_per_enemy_action() -> void:
	for e in DT.records_under(db(), "enemies/", "enemies"):
		var acts: Array = e.get("actions", []).duplicate()
		for ph in e.get("phases", []):
			acts.append_array(ph.get("actions", []))
		for a in acts:
			var heal: bool = str(a.get("form", "")) in ["shield", "aura"] and (a.get("vectors", {}).has("light") or a.get("vectors", {}).has("vitality"))
			if heal or bool(a.get("summon", false)) or bool(a.get("burrow", false)):
				continue
			check(a.has("damage") and not a.has("mult"), "%s %s has one clear damage number" % [e["id"], a.get("id", "")])
	check(not db()["stats"]["combat"].has("telegraphDamageMul"), "no stacked telegraph multiplier")
	check(float(db()["combat_rules"]["enemyHpMul"]) == 1.0, "enemy HP isn't scaled down")

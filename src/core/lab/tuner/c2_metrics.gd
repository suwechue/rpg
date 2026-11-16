## Combat 2.0 metrics for the sweeps (docs/COMBAT_2.md Part 5), next to LT's
## metrics (metrics.gd reads the same lines): knockdowns, One Mores, Baton Passes
## and All-Outs per fight, spell charge use (spent or hoarded), move variety,
## the basic attack's share, the enemy hit rate and loadout variety among wins.
## Pure data.
extends RefCounted

const Metrics := preload("res://src/core/lab/tuner/metrics.gd")


## lines: sweep lines from c2_sweep.gd. profile: whose numbers ("" = every profile).
static func summarize(db: Dictionary, lines: Array, profile: String = "expert") -> Dictionary:
	var n := 0
	var sums := { "knockdowns": 0.0, "oneMores": 0.0, "batons": 0.0, "allOuts": 0.0, "spells": 0.0, "enemyHits": 0.0, "enemyAttacks": 0.0, "enemyDamage": 0.0,
		"partyKnocked": 0.0, "ultimates": 0.0, "braces": 0.0, "chargesSpent": 0.0, "chargesMax": 0.0, "fights": 0.0 }
	var plays := {}
	var basic := 0
	var total_plays := 0
	var wins := 0
	var sigs := {}
	var basics := _basic_ids(db)
	for rec in lines:
		if profile != "" and str(rec.get("profile", "")) != profile:
			continue
		n += 1
		for k in sums:
			sums[k] = float(sums[k]) + float(rec.get(k, 0))
		for p in rec.get("plays", {}):
			var c := int(rec["plays"][p])
			plays[p] = int(plays.get(p, 0)) + c
			total_plays += c
			if basics.has(str(p)):
				basic += c
		if str(rec.get("result", "")) == "win":
			wins += 1
			var s := str(rec.get("loadouts", {}))
			sigs[s] = int(sigs.get(s, 0)) + 1
	var fights := maxf(1.0, float(sums["fights"]))
	var out := { "lines": n }
	for k in ["knockdowns", "oneMores", "batons", "allOuts", "spells", "enemyDamage", "partyKnocked", "ultimates", "braces"]:
		out[k + "PerFight"] = snappedf(float(sums[k]) / fights, 0.01)
	out["enemyHitRate"] = snappedf(float(sums["enemyHits"]) / maxf(1.0, float(sums["enemyAttacks"])), 0.01)
	out["chargeUse"] = snappedf(float(sums["chargesSpent"]) / maxf(1.0, float(sums["chargesMax"])), 0.01)
	out["basicShare"] = snappedf(float(basic) / maxf(1.0, float(total_plays)), 0.01)
	out["moveVariety"] = snappedf(Metrics.entropy(plays), 0.01)
	out["distinctMoves"] = plays.size()
	var top := ""
	var top_n := 0
	for p in plays:
		if int(plays[p]) > top_n:
			top_n = int(plays[p])
			top = str(p)
	out["topMove"] = top
	out["topMoveShare"] = snappedf(float(top_n) / maxf(1.0, float(total_plays)), 0.01)
	out["winningLoadouts"] = sigs.size()
	out["loadoutVariety"] = snappedf(Metrics.entropy(sigs), 0.01)
	out["wins"] = wins
	return out


static func _basic_ids(db: Dictionary) -> Dictionary:
	var out := {}
	for m in db.get("combat2/moves", {}).get("moves", []):
		if bool(m.get("basic", false)):
			out[str(m["id"])] = true
	return out

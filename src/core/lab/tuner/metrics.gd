## The Lab Tuner's fun proxies (docs/LAB_TUNER.md Part 3): sweep log lines in,
## one metrics row per group (a preset or a lever set) out, and the fun score
## with its hard limits. Every target and weight is in data/lab/tuner.json.
## Pure data: no files, no nodes.
extends RefCounted


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("lab/tuner", {})


## Per-turn numbers from one expert turn record: real choices, obvious or not.
## Turns with nothing to decide (no option but passing) return {}.
static func turn_numbers(rec: Dictionary, t: Dictionary) -> Dictionary:
	var values: Array = rec.get("values", [])
	if values.size() <= 1 and int(rec.get("load", 0)) == 0:
		return {}
	var best := float(values[0]) if not values.is_empty() else 0.0
	var unit := maxf(absf(best), float(t.get("valueUnit", 1.0)))
	var real := 0
	for v in values:
		if float(v) >= best - float(t.get("realChoiceBand", 0.1)) * unit:
			real += 1
	var second := float(values[1]) if values.size() > 1 else best - unit * 10.0
	var gap := (best - second) / unit
	return { "real": maxi(1, real), "gap": gap, "obvious": gap > float(t.get("obviousGap", 0.3)), "load": int(rec.get("load", 0)) }


## Shannon entropy of play counts, 0 (one play only) to 1 (all even).
static func entropy(counts: Dictionary) -> float:
	var total := 0.0
	for k in counts:
		total += float(counts[k])
	if total <= 0.0 or counts.size() <= 1:
		return 0.0
	var h := 0.0
	for k in counts:
		var p := float(counts[k]) / total
		if p > 0.0:
			h -= p * log(p)
	return h / log(float(counts.size()))


## One metrics row for a set of lines (any mix of profiles, fights and seeds).
static func summarize(lines: Array, t: Dictionary) -> Dictionary:
	var by_prof := {}
	for p in ["expert", "novice", "greedy", "random"]:
		by_prof[p] = { "n": 0, "wins": 0 }
	var stalls := 0
	var n := 0
	var turns := { "n": 0, "real": 0.0, "obvious": 0, "load": 0.0 }
	var ex := { "wins": 0, "close": 0, "comebacks": 0, "threatened": 0, "taken": 0, "kills": 0, "board": 0, "teamwork": 0.0, "fights": 0,
		"rounds": 0.0, "roundsN": 0, "boss": 0.0, "bossN": 0 }
	var plays := {}             # card -> plays in expert wins
	var per_fight_plays := {}   # fight -> card -> plays (variety)
	var openings := {}          # fight -> opening -> wins
	var ignore: Array = t.get("dominantIgnore", [])
	for rec in lines:
		n += 1
		var prof := str(rec.get("profile", "expert"))
		var res := str(rec.get("result", ""))
		if res == "stall":
			stalls += 1
		if by_prof.has(prof):
			by_prof[prof]["n"] += 1
			by_prof[prof]["wins"] += 1 if res == "win" else 0
		if prof != "expert":
			continue
		ex["fights"] += 1
		var fight := str(rec.get("fight", ""))
		if bool(rec.get("boss", false)):
			ex["boss"] += float(rec.get("rounds", 0))
			ex["bossN"] += 1
		else:
			ex["rounds"] += float(rec.get("rounds", 0))
			ex["roundsN"] += 1
		ex["threatened"] += int(rec.get("threatened", 0))
		ex["taken"] += int(rec.get("telegraphedDamage", 0))
		ex["kills"] += int(rec.get("kills", 0))
		ex["board"] += int(rec.get("boardKills", 0))
		ex["teamwork"] += float(rec.get("teamwork", 0))
		for tr in rec.get("ai", []):
			var tn := turn_numbers(tr, t)
			if tn.is_empty():
				continue
			turns["n"] += 1
			turns["real"] += float(tn["real"])
			turns["obvious"] += 1 if bool(tn["obvious"]) else 0
			turns["load"] += float(tn["load"])
		if not per_fight_plays.has(fight):
			per_fight_plays[fight] = {}
		for card in rec.get("plays", {}):
			if ignore.has(str(card)):
				continue
			per_fight_plays[fight][card] = int(per_fight_plays[fight].get(card, 0)) + int(rec["plays"][card])
		if res == "win":
			ex["wins"] += 1
			if float(rec.get("minPartyHp", 1.0)) < float(t.get("closeWinHp", 0.3)):
				ex["close"] += 1
			if bool(rec.get("comeback", false)):
				ex["comebacks"] += 1
			for card in rec.get("plays", {}):
				if not ignore.has(str(card)):
					plays[card] = int(plays.get(card, 0)) + int(rec["plays"][card])
			if not openings.has(fight):
				openings[fight] = {}
			var op := str(rec.get("opening", ""))
			openings[fight][op] = int(openings[fight].get(op, 0)) + 1
	var out := { "fights": n, "stalls": stalls, "stallShare": float(stalls) / float(maxi(1, n)) }
	for p in by_prof:
		out[p + "Win"] = float(by_prof[p]["wins"]) / float(by_prof[p]["n"]) if int(by_prof[p]["n"]) > 0 else -1.0
		out[p + "N"] = int(by_prof[p]["n"])
	var tn_n := float(maxi(1, int(turns["n"])))
	out["realChoices"] = float(turns["real"]) / tn_n
	out["obviousShare"] = float(turns["obvious"]) / tn_n
	out["optionLoad"] = float(turns["load"]) / tn_n
	var total := 0
	var top := 0
	var top_card := ""
	for c in plays:
		total += int(plays[c])
		if int(plays[c]) > top:
			top = int(plays[c])
			top_card = str(c)
	out["dominantCard"] = float(top) / float(maxi(1, total))
	out["dominantCardId"] = top_card
	var line_share := 0.0
	for f in openings:
		var wins := 0
		var most := 0
		for o in openings[f]:
			wins += int(openings[f][o])
			most = maxi(most, int(openings[f][o]))
		line_share = maxf(line_share, float(most) / float(maxi(1, wins)) if wins >= 3 else 0.0)
	out["dominantLine"] = line_share
	out["closeWins"] = float(ex["close"]) / float(maxi(1, int(ex["wins"])))
	out["comebacks"] = float(ex["comebacks"]) / float(maxi(1, int(ex["wins"])))
	out["rounds"] = float(ex["rounds"]) / float(ex["roundsN"]) if int(ex["roundsN"]) > 0 else -1.0
	out["bossRounds"] = float(ex["boss"]) / float(ex["bossN"]) if int(ex["bossN"]) > 0 else -1.0
	out["agency"] = clampf(1.0 - float(ex["taken"]) / float(ex["threatened"]), 0.0, 1.0) if int(ex["threatened"]) > 0 else -1.0
	out["boardUse"] = float(ex["board"]) / float(ex["kills"]) if int(ex["kills"]) > 0 else 0.0
	out["teamwork"] = float(ex["teamwork"]) / float(maxi(1, int(ex["fights"])))
	var ent := 0.0
	for f in per_fight_plays:
		ent += entropy(per_fight_plays[f])
	out["variety"] = ent / float(per_fight_plays.size()) if not per_fight_plays.is_empty() else 0.0
	return out


## How close a value is to its target: 1 inside, falling to 0 at `scale` outside.
## A value of -1 (not measured) scores -1 and is left out of the score.
static func closeness(value: float, spec: Dictionary) -> float:
	if value < 0.0:
		return -1.0
	var target: Array = spec.get("target", [null, null])
	var lo: Variant = target[0]
	var hi: Variant = target[1]
	var dist := 0.0
	if lo != null and value < float(lo):
		dist = float(lo) - value
	elif hi != null and value > float(hi):
		dist = value - float(hi)
	return maxf(0.0, 1.0 - dist / maxf(0.0001, float(spec.get("scale", 1.0))))


## Sum of learnCost of the levers a set turns on (a lever is "on" when it isn't
## its spec's offValue: false for switches, the cl_base default otherwise).
static func complexity(db: Dictionary, levers: Dictionary) -> float:
	var total := 0.0
	for s in db.get("lab/lab", {}).get("levers", []):
		var cost := float(s.get("learnCost", 0.0))
		if cost <= 0.0:
			continue
		var id := str(s["id"])
		var off: Variant = s.get("offValue", false if str(s.get("type", "")) == "bool" else s.get("default"))
		if levers.has(id) and str(levers[id]) != str(off):
			total += cost
	return total


## The fun score: weighted closeness to every target, minus the complexity cost.
## Returns { score, parts, complexity, dq, reasons }.
static func fun_score(m: Dictionary, t: Dictionary, complexity_cost: float = 0.0) -> Dictionary:
	var parts := {}
	var sum := 0.0
	var wsum := 0.0
	var specs: Dictionary = t.get("metrics", {})
	for k in specs:
		var c := closeness(float(m.get(k, -1.0)), specs[k])
		parts[k] = c
		if c < 0.0:
			continue
		sum += c * float(specs[k].get("weight", 1.0))
		wsum += float(specs[k].get("weight", 1.0))
	var score := sum / wsum if wsum > 0.0 else 0.0
	score -= float(t.get("complexityWeight", 0.0)) * complexity_cost / maxf(0.0001, float(t.get("complexityNorm", 10.0)))
	var reasons: Array = []
	var lim: Dictionary = t.get("hardLimits", {})
	if float(m.get("stallShare", 0.0)) > float(lim.get("maxStallShare", 0.0)):
		reasons.append("stalls")
	if float(m.get("expertWin", 1.0)) >= 0.0 and float(m.get("expertWin", 1.0)) < float(lim.get("minExpertWin", 0.7)):
		reasons.append("expert wins under %d%%" % roundi(float(lim.get("minExpertWin", 0.7)) * 100.0))
	if float(m.get("randomWin", 0.0)) > float(lim.get("maxRandomWin", 0.2)):
		reasons.append("random wins over %d%%" % roundi(float(lim.get("maxRandomWin", 0.2)) * 100.0))
	return { "score": snappedf(score, 0.001), "parts": parts, "complexity": complexity_cost, "dq": not reasons.is_empty(), "reasons": reasons }

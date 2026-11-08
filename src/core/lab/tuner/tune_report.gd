## Writes the Lab Tuner report (docs/LAB_TUNER.md Part 4) as Markdown: the
## baseline table, lever effects with an ASCII chart, pairs, the shortlist with
## every metric, plain-language notes and the agent ratings. Summaries in, text
## out: tools/lab_tune_report.gd reads the files and appends a dated section.
extends RefCounted

const Metrics := preload("res://src/core/lab/tuner/metrics.gd")
const Tuned := preload("res://src/core/lab/tuner/tuned_presets.gd")
const Sweep := preload("res://src/core/lab/sweep.gd")

const TABLE_METRICS := ["expertWin", "noviceWin", "greedyWin", "randomWin", "realChoices", "obviousShare", "optionLoad", "closeWins", "rounds", "bossRounds",
	"agency", "boardUse", "teamwork", "variety", "dominantCard", "dominantLine"]
const SHORT := { "expertWin": "exp", "noviceWin": "nov", "greedyWin": "grd", "randomWin": "rnd", "realChoices": "real", "obviousShare": "obv", "optionLoad": "load",
	"closeWins": "close", "rounds": "rnds", "bossRounds": "boss", "agency": "agcy", "boardUse": "board", "teamwork": "team", "variety": "var", "dominantCard": "dom", "dominantLine": "line" }
const PERCENT := ["expertWin", "noviceWin", "greedyWin", "randomWin", "obviousShare", "closeWins", "agency", "boardUse", "dominantCard", "dominantLine"]


static func fmt(key: String, v: Variant) -> String:
	if v == null or float(v) < 0.0:
		return "-"
	if PERCENT.has(key):
		return "%d%%" % roundi(float(v) * 100.0)
	return "%.1f" % float(v)


## A Markdown table of metric rows: name -> { metrics, score }.
static func metrics_table(rows: Dictionary, order: Array = []) -> String:
	var head := ["", "score", "ok"]
	for k in TABLE_METRICS:
		head.append(SHORT[k])
	var out: Array = ["| " + " | ".join(PackedStringArray(head)) + " |", "|" + "---|".repeat(head.size())]
	var keys: Array = order if not order.is_empty() else rows.keys()
	for k in keys:
		if not rows.has(k):
			continue
		var r: Dictionary = rows[k]
		var sc: Dictionary = r.get("score", {})
		var cells: Array = [str(k), "%.2f" % float(sc.get("score", 0.0)), "no: " + ", ".join(PackedStringArray(sc.get("reasons", []))) if bool(sc.get("dq", false)) else "yes"]
		for m in TABLE_METRICS:
			cells.append(fmt(m, r.get("metrics", {}).get(m, -1.0)))
		out.append("| " + " | ".join(PackedStringArray(cells)) + " |")
	return "\n".join(PackedStringArray(out))


static func legend(t: Dictionary) -> String:
	var parts: Array = []
	for k in TABLE_METRICS:
		var spec: Dictionary = t.get("metrics", {}).get(k, {})
		var target: Array = spec.get("target", [null, null])
		var lo := "" if target[0] == null else fmt(k, target[0])
		var hi := "" if target[1] == null else fmt(k, target[1])
		var want := ("%s to %s" % [lo, hi]) if lo != "" and hi != "" else (("at least " + lo) if lo != "" else ("at most " + hi))
		parts.append("**%s** %s (target %s)" % [SHORT[k], str(spec.get("name", k)), want])
	return "Columns: " + "; ".join(PackedStringArray(parts)) + ". **score** is the fun score (0 to 1, minus complexity); **ok** says whether a hard limit disqualifies it."


## A bar for a signed number, for the ASCII charts.
static func bar(v: float, scale: float, width: int = 20) -> String:
	var n := clampi(roundi(absf(v) / maxf(0.0001, scale) * float(width)), 0, width)
	return ("+" if v >= 0.0 else "-").repeat(n)


## One plain sentence about a lever's biggest effects.
static func note(name: String, delta: Dictionary, t: Dictionary) -> String:
	var ranked: Array = []
	for k in delta:
		var spec: Dictionary = t.get("metrics", {}).get(k, {})
		if spec.is_empty():
			continue
		ranked.append([absf(float(delta[k])) / maxf(0.0001, float(spec.get("scale", 1.0))), k])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var bits: Array = []
	for r in ranked.slice(0, 2):
		if float(r[0]) < 0.05:
			continue
		var k := str(r[1])
		var d := float(delta[k])
		var nm := str(t["metrics"][k].get("name", k)).to_lower()
		if PERCENT.has(k):
			bits.append("%s %s by %d points" % [nm, "goes up" if d > 0.0 else "goes down", roundi(absf(d) * 100.0)])
		else:
			bits.append("%s %s by %.1f" % [nm, "goes up" if d > 0.0 else "goes down", absf(d)])
	if bits.is_empty():
		return "%s changes little." % name
	return "%s: %s." % [name, ", and ".join(PackedStringArray(bits))]


static func baseline_section(summary: Dictionary, t: Dictionary) -> String:
	var rows := {}
	var order: Array = []
	for g in summary.get("groups", {}):
		var nm := str(g).trim_prefix("preset:")
		rows[nm] = summary["groups"][g]
		order.append(nm)
	return "### Baseline (%d fights, %s)\n\n%s\n\n%s\n" % [int(summary.get("fights", 0)), str(summary.get("at", "")), metrics_table(rows, order), legend(t)]


static func effects_section(db: Dictionary, summary: Dictionary, t: Dictionary) -> String:
	var rows: Array = summary.get("effects", [])
	var out: Array = ["### Lever effects, one at a time (%d fights)\n" % int(summary.get("fights", 0))]
	for base in ["cl_base", "cl_puzzle"]:
		var mine: Array = rows.filter(func(r: Dictionary) -> bool: return str(r["base"]) == base)
		if mine.is_empty():
			continue
		mine.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) - float(a["base_score"]) > float(b["score"]) - float(b["base_score"]))
		var base_score := float(mine[0]["base_score"])
		out.append("**From %s** (its fun score: %.2f). Score change, verdict, then the biggest metric moves:\n" % [base, base_score])
		out.append("```")
		var scale := 0.0001
		for r in mine:
			scale = maxf(scale, absf(float(r["score"]) - float(r["base_score"])))
		for r in mine:
			var d := float(r["score"]) - float(r["base_score"])
			var label := "%s = %s" % [Tuned.lever_name(db, str(r["lever"])), Sweep.norm(r["value"])]
			out.append("%-34s %+.3f %-21s %-8s%s" % [label.substr(0, 34), d, bar(d, scale), str(r["verdict"]), "  (disqualified: " + ", ".join(PackedStringArray(r.get("reasons", []))) + ")" if bool(r.get("dq", false)) else ""])
		out.append("```\n")
		out.append("Notes:\n")
		for r in mine.slice(0, 6) + mine.slice(maxi(6, mine.size() - 4)):
			out.append("- " + note("%s = %s" % [Tuned.lever_name(db, str(r["lever"])), Sweep.norm(r["value"])], r["delta"], t))
		out.append("")
	return "\n".join(PackedStringArray(out))


static func pairs_section(db: Dictionary, summary: Dictionary) -> String:
	var out: Array = ["### Pairs (top %d levers on %s, %d fights)\n" % [summary.get("top", []).size(), str(summary.get("base", "")), int(summary.get("fights", 0))]]
	out.append("| pair | score | alone | verdict |")
	out.append("|---|---|---|---|")
	for p in summary.get("pairs", []):
		var nm := " + ".join(PackedStringArray((p["levers"] as Dictionary).keys().map(func(k: String) -> String: return "%s %s" % [Tuned.lever_name(db, k), Sweep.norm(p["levers"][k])])))
		out.append("| %s | %.3f%s | %.3f / %.3f | %s |" % [nm, float(p["score"]), " (dq)" if bool(p.get("dq", false)) else "", float(p["aScore"]), float(p["bScore"]), str(p["verdict"])])
	var good: Array = summary.get("pairs", []).filter(func(p: Dictionary) -> bool: return str(p["verdict"]) == "good together")
	var bad: Array = summary.get("pairs", []).filter(func(p: Dictionary) -> bool: return str(p["verdict"]) == "bad together")
	out.append("\nGood together: %d pairs. Bad together: %d pairs.\n" % [good.size(), bad.size()])
	return "\n".join(PackedStringArray(out))


static func shortlist_section(db: Dictionary, summary: Dictionary, t: Dictionary) -> String:
	var out: Array = ["### The search and the shortlist\n"]
	out.append("Base: %s. %d lever sets tried over %d generations; %d finalists played every fight, 20 seeds, 3 parties. A finalist's score is its worst party's.\n" % [
		str(summary.get("base", "")), int(summary.get("tried", 0)), int(summary.get("generations", 0)), summary.get("finals", []).size()])
	var space: Array = summary.get("space", [])
	out.append("Search space: " + ", ".join(PackedStringArray(space.map(func(s: Dictionary) -> String: return Tuned.lever_name(db, str(s["lever"]))))) + ".\n")
	var short: Array = summary.get("shortlist", [])
	for i in short.size():
		var s: Dictionary = short[i]
		out.append("**tuned_%d** (score %.3f%s): %s.\n" % [i + 1, float(s["score"]), ", disqualified: " + ", ".join(PackedStringArray(s.get("reasons", []))) if bool(s.get("dq", false)) else "",
			Tuned.describe(db, s["levers"])])
		var rows := {}
		var order: Array = []
		for p in s.get("parties", {}):
			rows[p] = s["parties"][p]
			order.append(p)
		if not rows.is_empty():
			out.append(metrics_table(rows, order))
		var fw: Dictionary = s.get("fightWins", {})
		if not fw.is_empty():
			var bits: Array = []
			for f in fw:
				bits.append("%s %d%%" % [f, roundi(float(fw[f]) * 100.0)])
			out.append("\nExpert wins per fight: " + ", ".join(PackedStringArray(bits)) + ".\n")
	return "\n".join(PackedStringArray(out))


## Agent rating cards: [{ persona, preset, fight, fun, options, clever, ... }].
static func agent_table(cards: Array) -> String:
	var by := {}
	for c in cards:
		for key in ["preset:" + str(c.get("preset", "")), "persona:" + str(c.get("persona", ""))]:
			if not by.has(key):
				by[key] = { "n": 0, "fun": 0.0, "options": 0.0, "clever": 0 }
			by[key]["n"] += 1
			by[key]["fun"] += float(c.get("fun", 0))
			by[key]["options"] += float(c.get("options", 0))
			by[key]["clever"] += 1 if bool(c.get("clever", false)) else 0
	var out: Array = ["| | fights | fun | options | felt clever |", "|---|---|---|---|---|"]
	var keys: Array = by.keys()
	keys.sort()
	for k in keys:
		var r: Dictionary = by[k]
		var n := float(maxi(1, int(r["n"])))
		out.append("| %s | %d | %.1f | %.1f | %d%% |" % [str(k).get_slice(":", 1) + (" (preset)" if str(k).begins_with("preset:") else " (persona)"), int(r["n"]), float(r["fun"]) / n, float(r["options"]) / n, roundi(float(r["clever"]) / n * 100.0)])
	return "\n".join(PackedStringArray(out))


## A whole dated section from whichever summaries exist.
static func section(db: Dictionary, sums: Dictionary, cards: Array, date: String) -> String:
	var t := Metrics.cfg(db)
	var out: Array = ["## Tuning run, %s\n" % date]
	if sums.has("baseline"):
		out.append(baseline_section(sums["baseline"], t))
	if sums.has("screening"):
		out.append(effects_section(db, sums["screening"], t))
	if sums.has("pairs"):
		out.append(pairs_section(db, sums["pairs"]))
	if sums.has("search"):
		out.append(shortlist_section(db, sums["search"], t))
	if sums.has("shortlist"):
		var s: Dictionary = sums["shortlist"].duplicate()
		out.append(baseline_section(s, t).replace("### Baseline", "### Shortlist re-run"))
	if not cards.is_empty():
		out.append("### Agent rating cards (%d fights)\n\n%s\n" % [cards.size(), agent_table(cards)])
	return "\n".join(PackedStringArray(out)) + "\n"


## The report file with a new section appended (old runs are never touched).
static func append(existing: String, sec: String) -> String:
	var head := existing
	if head.strip_edges() == "":
		head = "# Lab Tuning\n\nResults of the Lab Tuner (docs/LAB_TUNER.md). Each run adds a dated section below; old sections stay. Machine numbers are proxies for fun, not fun: read them next to the agent notes, and the user's own Lab ratings outrank both.\n"
	return head.rstrip("\n") + "\n\n" + sec

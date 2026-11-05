## Sums up Lab log lines into a table per preset (docs/COMBAT_LAB.md Part 1).
extends RefCounted


## preset id -> { fights, rated, fun, options, clever, rounds, boardKills, combos, decisions, wins, abWins }.
static func summarize(lines: Array) -> Dictionary:
	var out := {}
	for rec in lines:
		if str(rec.get("kind", "")) == "ab":
			var pick := str(rec.get("pick", ""))
			if pick != "":
				_row(out, pick)["abWins"] += 1
			continue
		var r := _row(out, str(rec.get("preset", "?")))
		r["fights"] += 1
		r["wins"] += 1 if str(rec.get("result", "")) == "win" else 0
		r["roundsSum"] += float(rec.get("rounds", 0))
		r["boardSum"] += float(rec.get("boardKills", 0))
		r["comboSum"] += float(rec.get("combos", 0))
		r["decisionSum"] += float(rec.get("decisionsPerTurn", 0))
		var rating: Dictionary = rec.get("rating", {})
		if rating.has("fun"):
			r["funN"] += 1
			r["funSum"] += float(rating["fun"])
		if rating.has("options"):
			r["optionsN"] += 1
			r["optionsSum"] += float(rating["options"])
		if rating.has("clever"):
			r["cleverN"] += 1
			r["cleverYes"] += 1 if bool(rating["clever"]) else 0
	for k in out:
		var r: Dictionary = out[k]
		var n := float(maxi(1, int(r["fights"])))
		r["rounds"] = r["roundsSum"] / n
		r["boardKills"] = r["boardSum"] / n
		r["combos"] = r["comboSum"] / n
		r["decisions"] = r["decisionSum"] / n
		r["fun"] = r["funSum"] / float(r["funN"]) if int(r["funN"]) > 0 else -1.0
		r["options"] = r["optionsSum"] / float(r["optionsN"]) if int(r["optionsN"]) > 0 else -1.0
		r["clever"] = float(r["cleverYes"]) / float(r["cleverN"]) if int(r["cleverN"]) > 0 else -1.0
	return out


static func _row(out: Dictionary, preset: String) -> Dictionary:
	if not out.has(preset):
		out[preset] = { "fights": 0, "wins": 0, "roundsSum": 0.0, "boardSum": 0.0, "comboSum": 0.0, "decisionSum": 0.0, "funN": 0, "funSum": 0.0, "optionsN": 0, "optionsSum": 0.0,
			"cleverN": 0, "cleverYes": 0, "abWins": 0 }
	return out[preset]


## The table as text, one row per preset.
static func table(summary: Dictionary) -> String:
	var rows: Array = ["%-12s %6s %5s %6s %7s %6s %6s %6s %7s %5s" % ["preset", "fights", "wins", "fun", "options", "clever", "rounds", "board", "combos", "A/B"]]
	var keys: Array = summary.keys()
	keys.sort()
	for k in keys:
		var r: Dictionary = summary[k]
		rows.append("%-12s %6d %5d %6s %7s %6s %6.1f %6.1f %7.1f %5d" % [str(k), int(r["fights"]), int(r["wins"]), _num(float(r["fun"])), _num(float(r["options"])),
			_pct(float(r["clever"])), float(r["rounds"]), float(r["boardKills"]), float(r["combos"]), int(r["abWins"])])
	return "\n".join(PackedStringArray(rows))


static func _num(v: float) -> String:
	return "-" if v < 0.0 else "%.1f" % v


static func _pct(v: float) -> String:
	return "-" if v < 0.0 else "%d%%" % roundi(v * 100.0)

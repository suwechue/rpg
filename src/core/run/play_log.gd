## Gameplay log tallies (ROADMAP M9): AP spent per action type, fights won
## and lost, and real time per in-game day. Plain dictionaries; the PlayLog
## autoload writes one finished day record per line to a local JSONL file.
extends RefCounted


static func new_day(week: int, day: String) -> Dictionary:
	return { "type": "day", "week": week, "day": day, "seconds": 0.0, "ap": {}, "won": 0, "lost": 0, "fled": 0 }


## Action kinds can carry a detail after a colon ("shop:deli"); both the full
## kind and its group ("shop") are counted, so totals read either way.
static func add_ap(rec: Dictionary, kind: String, amount: int) -> void:
	var ap: Dictionary = rec["ap"]
	ap[kind] = int(ap.get(kind, 0)) + amount


static func add_fight(rec: Dictionary, result: String, rounds: int = 0, cards: int = 0) -> void:
	var key := "won" if result == "win" else ("lost" if result == "lose" else "fled")
	rec[key] = int(rec.get(key, 0)) + 1
	rec["rounds"] = int(rec.get("rounds", 0)) + rounds
	rec["cards"] = int(rec.get("cards", 0)) + cards


static func group(kind: String) -> String:
	return kind.get_slice(":", 0)


## Totals over many day records: AP per action group, fights, average seconds per day.
static func summarize(records: Array) -> Dictionary:
	var ap := {}
	var won := 0
	var lost := 0
	var seconds := 0.0
	var days := 0
	for r in records:
		var rec: Dictionary = r
		if str(rec.get("type", "")) != "day":
			continue
		days += 1
		seconds += float(rec.get("seconds", 0.0))
		won += int(rec.get("won", 0))
		lost += int(rec.get("lost", 0))
		var day_ap: Dictionary = rec.get("ap", {})
		for k in day_ap:
			var g := group(str(k))
			ap[g] = int(ap.get(g, 0)) + int(day_ap[k])
	return { "days": days, "ap": ap, "won": won, "lost": lost, "avgSeconds": seconds / float(maxi(days, 1)) }

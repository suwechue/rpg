## M19 balance tool (not a test): how much of what a player wants to do fits
## in a day's AP. Two simulated players with wish lists per day part, drawn
## from the real costs (data/calendar.json AP, data/social.json, location
## activities, shop visits): "greedy" (train, work, shop) and "social" (talk,
## gift, hang out). Prints the share of wishes done per part type and overall;
## the target is about 60% (docs/ROADMAP.md M19).
## Run: godot --headless --path . -s res://tools/sim_days.gd [-- --weeks=5]
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")

## What each player wants per day part: [action, how many times]. Costs come from data.
const WISHES := {
	"greedy": { "before_school": [["shop", 1], ["train", 1]], "lunch": [["talk", 1], ["shop", 1]], "after_school": [["work", 1], ["train", 1], ["shop", 1]],
		"night": [["craft", 1]], "morning": [["work", 1], ["train", 1]], "midday": [["train", 1], ["shop", 1]], "afternoon": [["work", 1], ["train", 1]],
		"weekend_evening": [["craft", 1], ["talk", 1]] },
	"social": { "before_school": [["talk", 2]], "lunch": [["talk", 2], ["gift", 1]], "after_school": [["hangout", 1], ["talk", 2]],
		"night": [["talk", 1]], "morning": [["hangout", 1], ["talk", 1]], "midday": [["hangout", 1], ["gift", 1]], "afternoon": [["talk", 2], ["gift", 1]],
		"weekend_evening": [["hangout", 1]] },
	# TL Part 1: skips every class to work, read records and hang out in town.
	"skipper": { "before_school": [["talk", 1]], "period_1": [["work", 1]], "period_2": [["work", 1]], "period_3": [["records", 1], ["talk", 1]],
		"lunch": [["talk", 2]], "after_school": [["work", 1], ["talk", 1]], "night": [["craft", 1]], "morning": [["work", 1], ["talk", 1]],
		"midday": [["hangout", 1]], "afternoon": [["talk", 2]], "weekend_evening": [["hangout", 1]] },
}


func _initialize() -> void:
	var db := DT.tables("res://data")
	var social: Dictionary = db.get("social", {})
	var costs := {
		"talk": int(social.get("topicAp", 1)), "gift": int(social.get("giftAp", 1)), "hangout": int(social.get("hangoutAp", 2)),
		"shop": int(db.get("town/shops", {}).get("rules", {}).get("visitAp", 1)), "train": 2, "work": 2,
		"craft": int(db.get("minigames", {}).get("craftAp", {}).get("night", 1)), "records": 1,
	}
	var cal: Dictionary = db.get("calendar", {})
	var parts := { "weekday": cal.get("weekdayParts", []), "weekend": cal.get("weekendParts", []) }
	var days := { "weekday": 5, "weekend": 2 }
	for who in WISHES:
		var wanted := 0
		var done := 0
		var by_part := {}
		for kind in parts:
			for p in parts[kind]:
				var pid := str(p.get("id", ""))
				var ap := int(p.get("ap", 0))
				# A skipped class gives skipAp to spend in town (TL Part 1).
				if who == "skipper" and cal.get("schoolHours", []).has(pid):
					ap = int(db.get("school_classes", {}).get("rules", {}).get("skipAp", 2))
				var w := 0
				var d := 0
				for wish in WISHES[who].get(pid, []):
					for i in int(wish[1]):
						var c := int(costs[str(wish[0])])
						w += c
						if ap >= c:
							ap -= c
							d += c
				wanted += w * int(days[kind])
				done += d * int(days[kind])
				if w > 0:
					by_part[pid] = "%d%%" % roundi(100.0 * float(d) / float(w))
		print("%-7s  %d%% of wished AP fits  %s" % [who, roundi(100.0 * float(done) / float(maxi(1, wanted))), str(by_part)])
	print("target: about 60%")
	quit(0)

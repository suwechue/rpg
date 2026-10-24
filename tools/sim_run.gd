## Balance tool (not a test): simulates every dungeon night of a 5-week run
## with the AI playing, a growing party, XP from fights and boss rewards.
## Prints where runs die and the levels reached.
## Run: godot --headless --path . -s res://tools/sim_run.gd [-- --runs=10]
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Night := preload("res://src/core/dungeon/night.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const Bonds := preload("res://src/core/social/bonds.gd")
const Char := preload("res://src/core/character.gd")
const CC := preload("res://src/core/progression/class_change.gd")
const SimNights := preload("res://tools/sim_nights.gd")

const ALLY_ORDER := ["mara", "theo", "dex", "priya"]


func _initialize() -> void:
	var db := DT.tables()
	var runs := 10
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--runs="):
			runs = int(str(a).split("=")[1])
	var deaths := {}
	var finished := 0
	var levels: Array = []
	for cls in ["fighter", "mage", "rogue", "healer", "bard"]:
		for r in runs:
			var rng := RandomNumberGenerator.new()
			rng.seed = 9100 + r * 31
			var run := RM.new_run(db, rng.seed, cls, rng)
			var died := ""
			for week in range(1, 6):
				var allies := clampi(week, 1, 3)
				while run["roster"].size() < allies:
					var id: String = ALLY_ORDER[run["roster"].size()]
					run["bonds"][id] = 50.0
					Bonds.recruit(db, run, id, rng)
				for day in ["mon", "tue", "wed", "thu", "fri"]:
					if week == 1 and day == "mon":
						continue
					var res: Dictionary = SimNights.night(db, run, week, day, rng)
					if not res["alive"]:
						died = "w%d %s (%s)" % [week, day, res.get("diedIn", "?")]
						break
					if day == "fri":
						Night.boss_reward(db, run, week, rng)
					for p in [run["player"]] + run["roster"]:
						if p.has("pendingClassChange"):
							var opts := CC.options(db, run, p)
							if p.get("isPlayer", false) and not opts["available"].is_empty():
								CC.apply(db, run, p, str(opts["available"][0]))
							else:
								CC.auto_advance(db, run, p)
						Char.full_restore(db, p)
					# a few stat bars from classes each week day
					for s in Char.class_data(db, str(run["player"]["class"])).get("growth", {}).keys().slice(0, 2):
						RM.train_stat(db, run["player"], str(s), 1.0)
				if died != "":
					break
			if died == "":
				finished += 1
				levels.append(int(run["player"]["level"]))
			else:
				deaths[died] = int(deaths.get(died, 0)) + 1
			print("%-8s run %d: %s, level %d" % [cls, r, "FINISHED" if died == "" else "died " + died, int(run["player"]["level"])])
	print("finished %d / %d" % [finished, runs * 5])
	print("deaths: ", deaths)
	print("levels at the end: ", levels)
	quit()

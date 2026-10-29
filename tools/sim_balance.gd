## Balance tool (not a test): kill-time numbers for a week (docs/COMBAT_TUNING.md
## Part 1), computed from the real damage formulas (expected values, no
## crits, neutral matchups, no flanking) and checked against
## data/combat_rules.json "balanceTargets".
## Run: godot --headless --path . -s res://tools/sim_balance.gd [-- --week=1 --level=2 --difficulty=normal --gear=0]
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const Report := preload("res://src/core/combat/balance_report.gd")


func _initialize() -> void:
	var db := DT.tables()
	var week := 1
	var level := 2
	var diff := "normal"
	var gear := 0
	for a in OS.get_cmdline_user_args():
		var kv := str(a).trim_prefix("--").split("=")
		match kv[0]:
			"week":
				week = int(kv[1])
			"level":
				level = int(kv[1])
			"difficulty":
				diff = kv[1]
			"gear":
				gear = int(kv[1])
	var r := Report.measure(db, week, level, diff, gear)
	for line in Report.lines(db, r):
		print(line)
	quit()

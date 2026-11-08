## Prints a table per preset from the Lab logs (docs/COMBAT_LAB.md Part 1).
## Run: godot --headless --path . -s res://tools/lab_report.gd
## Reads the player's user://lab/ folder; pass -- --dir=path/ to read another.
## Then shows your ratings next to the Lab Tuner's agent ratings and machine scores.
extends SceneTree

const Report := preload("res://src/core/lab/lab_report.gd")
const FightLog := preload("res://src/core/lab/fight_log.gd")
const Plan := preload("res://src/core/lab/tuner/plan.gd")


func _initialize() -> void:
	var folder := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--dir="):
			folder = str(a).trim_prefix("--dir=")
	var lines := FightLog.read_all(folder if folder != "" else "user://lab/")
	if lines.is_empty():
		print("No Lab logs yet. Play a Lab fight first.")
	else:
		print(Report.table(Report.summarize(lines)))
	# The Lab Tuner's numbers next to yours (docs/LAB_TUNER.md Part 6).
	print("")
	print(Report.combined(Report.summarize(lines), Plan.agent_cards(), Plan.machine_scores()))
	quit(0)

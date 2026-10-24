## Reads the local gameplay log and prints totals: AP per action type, fights
## won and lost, average real time per in-game day.
## Run: godot --headless --path . -s res://tools/play_log_report.gd [-- --file=C:/path/gameplay_log.jsonl]
extends SceneTree

const Log := preload("res://src/core/run/play_log.gd")


func _initialize() -> void:
	var file := "user://gameplay_log.jsonl"
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--file="):
			file = str(a).trim_prefix("--file=")
	if not FileAccess.file_exists(file):
		print("No log at %s (play a day in a normal window first)." % ProjectSettings.globalize_path(file))
		quit(1)
		return
	var records: Array = []
	for line in FileAccess.get_file_as_string(file).split("\n", false):
		var rec: Variant = JSON.parse_string(line)
		if rec is Dictionary:
			records.append(rec)
	var s := Log.summarize(records)
	print("Days logged: %d   average %.0f s per day" % [int(s["days"]), float(s["avgSeconds"])])
	print("Fights: %d won, %d lost" % [int(s["won"]), int(s["lost"])])
	var ap: Dictionary = s["ap"]
	var total := 0
	for k in ap:
		total += int(ap[k])
	print("AP spent: %d" % total)
	for k in ap:
		print("  %-10s %4d  (%.0f%%)" % [str(k), int(ap[k]), 100.0 * float(ap[k]) / float(maxi(total, 1))])
	quit(0)

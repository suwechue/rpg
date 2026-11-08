## Adds a dated section to docs/LAB_TUNING.md from the latest finished sweep of
## each Lab Tuner plan and the agent rating cards (docs/LAB_TUNER.md Parts 4 and 5).
## Run: godot --headless --path . -s res://tools/lab_tune_report.gd
## Options: --only=baseline,screening (plans to include; default all five),
## --print (print the section instead of writing the file).
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const Report := preload("res://src/core/lab/tuner/tune_report.gd")
const Plan := preload("res://src/core/lab/tuner/plan.gd")

const PLANS := ["baseline", "screening", "pairs", "search", "shortlist"]


func _initialize() -> void:
	var db: Dictionary = DT.tables("res://data")
	var only: Array = PLANS
	var to_print := false
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--only="):
			only = Array(str(a).trim_prefix("--only=").split(","))
		if str(a) == "--print":
			to_print = true
	var sums := {}
	for p in only:
		var s := latest(str(p))
		if not s.is_empty():
			sums[str(p)] = s
	var sec := Report.section(db, sums, agent_cards(), Time.get_datetime_string_from_system().replace("T", " "))
	if to_print:
		print(sec)
	else:
		var path := ProjectSettings.globalize_path("res://docs/LAB_TUNING.md")
		var old := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(Report.append(old, sec))
		f.close()
		print("lab_tune_report: added a section with %s to docs/LAB_TUNING.md" % ", ".join(PackedStringArray(sums.keys())))
	quit(0)


static func latest(plan_id: String) -> Dictionary:
	return Plan.latest_summary(plan_id)


static func agent_cards() -> Array:
	return Plan.agent_cards()

## One autosave slot per run (roguelike: no save scumming). Writes are atomic:
## write a temp file, then swap it in, so a crash never corrupts the run.
extends Node

const SAVE_PATH := "user://run_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_run(allow_arena: bool = false) -> bool:
	# Arena runs are saved only from the pause menu (PT Part 3), at the start of the current wave.
	if str(GameState.run.get("mode", "")) == "arena" and not allow_arena:
		return false
	var data: Dictionary = GameState.to_dict()
	var tmp_path := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot write %s" % tmp_path)
		EventBus.game_saved.emit(false)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var final_abs := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(final_abs)
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), final_abs)
	EventBus.game_saved.emit(err == OK)
	return err == OK


func load_run() -> bool:
	if not has_save():
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK:
		push_error("SaveSystem: save file is corrupt")
		return false
	GameState.load_dict(json.data)
	return true


## Permadeath: the run is over, the save goes with it.
## What the save holds, without loading it (M22): week, day, part, mode, when.
func peek() -> Dictionary:
	if not has_save():
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (d is Dictionary):
		return {}
	var cal: Dictionary = d.get("calendar", {})
	var run: Dictionary = d.get("run", {})
	return { "week": int(cal.get("week", 1)), "day": int(cal.get("day_index", 0)), "part": int(cal.get("part_index", 0)),
		"mode": str(run.get("runMode", "permadeath")), "arena": str(run.get("mode", "")) == "arena",
		"saved": Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(SAVE_PATH), true) }


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

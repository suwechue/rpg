## One autosave slot per run (roguelike: no save scumming). Writes are atomic:
## write a temp file, then swap it in, so a crash never corrupts the run.
extends Node

const SAVE_PATH := "user://run_save.json"


## Clear stored data (Options and the title's Clear data):
## "meta" - the Narrator's Journal (unlocks, achievements, records, combos seen,
## tutorial and spark unlocks); "settings"; "save" (the current run); "all" -
## those plus the gameplay log and saved feedback zips. Returns what was removed.
func clear_data(what: String) -> Array:
	var gone: Array = []
	if what in ["meta", "all"]:
		_remove("user://journal.json", gone)
		Journal.load_journal()
	if what in ["settings", "all"]:
		_remove("user://settings.cfg", gone)
		Audio.apply_volumes()
	if what in ["save", "all"]:
		if has_save():
			gone.append(SAVE_PATH)
		delete_save()
	if what == "all":
		_remove(PlayLog.path, gone)
		for dir in ["user://feedback", "user://custom_smoke", "user://skin_smoke"]:
			_remove_dir(dir, gone)
	return gone


func _remove(path: String, gone: Array) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		gone.append(path)


func _remove_dir(path: String, gone: Array) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(f)))
	for sub in d.get_directories():
		_remove_dir(path.path_join(sub), gone)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	gone.append(path)


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

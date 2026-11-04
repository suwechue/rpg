## Where the game keeps its files. Test runners and screenshot runs use a
## sandbox folder, because they play the real game: a new run deletes the save
## and fights write to the Journal, and that must never touch a player's data.
extends RefCounted

const ROOT := "user://"
const SANDBOX := "user://test_sandbox/"

static var _base := ""


static func base() -> String:
	if _base == "":
		_base = ROOT
		for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
			var arg := str(a)
			if arg.begins_with("res://tests/") or arg.begins_with("--shot") or arg.begins_with("--seed"):
				_base = SANDBOX
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SANDBOX))
				break
	return _base


## The path of a saved file, e.g. of("settings.cfg").
static func of(file_name: String) -> String:
	return base() + file_name


static func sandboxed() -> bool:
	return base() == SANDBOX

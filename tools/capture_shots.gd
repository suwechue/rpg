## Press kit screenshots (docs/VECTORS_DEMO.md Part 5): runs the game once per
## scripted moment with the F1 dev flags and saves each frame into
## tools/press_kit/. Run from the project folder:
##   Godot_console.exe --headless --path . -s res://tools/capture_shots.gd
## (the moments themselves run windowed, so they render). For video, add
## --write-movie tools/press_kit/<name>.avi to a moment's flags (see docs/PRESS_KIT.md).
extends SceneTree

const MOMENTS := [
	{ "name": "title", "args": [] },
	{ "name": "town_sunset", "args": ["--seed=3", "--jump=1,0,2", "--scene=res://src/scenes/town/town.tscn"] },
	{ "name": "boss_telegraph", "args": ["--seed=3", "--fight=hollow_mascot", "--scene=res://src/scenes/combat/combat.tscn"], "frames": 240 },
	{ "name": "spark_quiz", "args": ["--seed=3", "--modal=res://src/scenes/ui/spark_quiz_screen.gd"] },
	{ "name": "compendium", "args": ["--seed=3", "--modal=res://src/scenes/ui/compendium_screen.gd"] },
	{ "name": "kelly_cutscene", "args": ["--seed=3", "--cutscene=kelly_floor_intro"], "frames": 200 },
	{ "name": "arena", "args": ["--arena", "--seed=3"], "frames": 120 },
]


func _initialize() -> void:
	var out := ProjectSettings.globalize_path("res://tools/press_kit")
	DirAccess.make_dir_recursive_absolute(out)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--only="):
			only = str(a).trim_prefix("--only=")
	for m in MOMENTS:
		if only != "" and str(m["name"]) != only:
			continue
		var args: Array = ["--path", ProjectSettings.globalize_path("res://"), "--"]
		args.append_array(m["args"])
		args.append("--shot=%s/%s.png" % [out, m["name"]])
		args.append("--frames=%d" % int(m.get("frames", 90)))
		var code := OS.execute(OS.get_executable_path(), PackedStringArray(args))
		print("%s: %s" % [m["name"], "ok" if code == 0 else "exit %d" % code])
	quit(0)

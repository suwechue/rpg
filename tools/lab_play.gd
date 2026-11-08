## Play a Lab fight as text, one step at a time (docs/LAB_TUNER.md Part 5). Each
## call replays the inputs so far and prints the board, units, enemy plans, the
## hand and every option with its exact preview. Nothing is saved.
## Run: godot --headless --path . -s res://tools/lab_play.gd -- --fight=thin_ice --preset=cl_base --seed=4 --actions="3,1,7"
## --actions: inputs in order, split by commas or semicolons: option numbers, or
## named steps (m3.2 move, s4.2 Strike, c2@4.2 hand card 2 at a tile, c2 on
## yourself, c2@4.2#Spark with a choice, e end turn, surge, gauge, delay, p2, h2);
## "u" undoes the last step when the rules allow.
## --brief: a shorter screen (moves on one line).
## --cmd: "rules" (this preset's rules), "explain <lever>", "show discard",
## "show ally deck size", "fights", "presets", or "rate" with --persona=id and
## --card='{"fun":4,...}' to save an agent's rating card for this fight and preset
## to user://lab/agents/<persona>/<preset>/<fight>.json.
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const Play := preload("res://src/core/lab/play_text.gd")
const Setup := preload("res://src/core/lab/lab_setup.gd")
const Rules := preload("res://src/core/combat/rules.gd")


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var s := str(a).trim_prefix("--")
		var eq := s.find("=")
		args[s.substr(0, eq) if eq >= 0 else s] = s.substr(eq + 1) if eq >= 0 else ""
	var db: Dictionary = DT.tables("res://data")
	var fight := str(args.get("fight", "ledge_day"))
	var preset := str(args.get("preset", "cl_base"))
	var seed_value := int(args.get("seed", "1"))
	var inputs: Array = []
	for t in str(args.get("actions", "")).replace(" ", "").replace(";", ",").split(",", false):
		inputs.append(t)
	if str(args.get("cmd", "")) == "rate":
		print(rate(fight, preset, str(args.get("persona", "")), str(args.get("card", ""))))
	else:
		print(run(db, fight, preset, seed_value, inputs, str(args.get("cmd", "")), args.has("brief")))
	quit(0)


## Save an agent's rating card (the same fields as the human card, plus notes).
static func rate(fight: String, preset: String, persona: String, card_json: String) -> String:
	var card: Variant = JSON.parse_string(card_json)
	if persona == "" or typeof(card) != TYPE_DICTIONARY:
		return "Sorry: pass --persona=<id> and --card with a JSON object: fun 1-5, options 1-5, clever true/false, boring, misunderstood, broken, journal."
	# Always the real Lab folder: lab_play runs take --seed, which would send them to the test sandbox.
	var dir := "user://lab/agents/%s/%s/" % [persona, preset]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	card["savedAt"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(dir + fight + ".json", FileAccess.WRITE)
	if f == null:
		return "Sorry: couldn't save the card."
	f.store_string(JSON.stringify(card, "  "))
	f.close()
	return "Saved your rating card for %s under %s." % [fight, preset]


static func run(db: Dictionary, fight: String, preset: String, seed_value: int, inputs: Array, cmd: String, brief: bool = false) -> String:
	var c := cmd.strip_edges().to_lower()
	if c == "rules":
		return Play.rules_text(db, preset)
	if c.begins_with("explain"):
		var lever := cmd.strip_edges().substr(7).strip_edges()
		return Play.explain(db, preset, lever) if lever != "" else "Say which lever: explain <lever name>."
	if c == "fights":
		return "\n".join(PackedStringArray(Setup.fights(db).map(func(f: Dictionary) -> String: return "%s: %s" % [f["id"], f.get("text", "")])))
	if c == "presets":
		return "\n".join(PackedStringArray(Rules.presets(db).map(func(p: Dictionary) -> String: return "%s: %s" % [p["id"], p.get("text", "")])))
	var r := Play.replay(db, fight, preset, seed_value, inputs)
	if str(r["error"]) != "":
		return "Sorry: " + str(r["error"])
	if c == "show discard":
		return Play.show_discard(r["st"])
	if c == "show ally deck size" or c == "show ally decks":
		return Play.ally_decks(r["st"])
	if c != "":
		return "Sorry, I don't know the command '%s'. Commands: rules, explain <lever>, show discard, show ally deck size, fights, presets. To play, pass option numbers in --actions." % cmd
	return Play.render(db, r, preset, brief)

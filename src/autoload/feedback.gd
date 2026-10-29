## Feedback and the demo's ending (docs/VECTORS_DEMO.md Parts 5 and 6).
## F8 (or the pause menu) asks for a note and saves it with a screenshot, the
## gameplay log and its summary, the current save and the build version into a
## zip in user://feedback/, then opens that folder. In demo mode the run ends
## after the week 1 boss: a thanks screen, then the survey (saved the same way).
extends Node

const Demo := preload("res://src/core/demo.gd")
const Modal := preload("res://src/scenes/ui/modal.gd")

const DIR := "user://feedback"

## Set by tests and F1 to play the demo ending in a full build.
var force_demo := false
var last_zip := ""
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("feedback") and not _open:
		get_viewport().set_input_as_handled()
		send_feedback()


func demo_active() -> bool:
	return force_demo or Demo.is_on(DataDB.all(), OS.has_feature("demo"))


func version() -> String:
	return Demo.version(DataDB.all())


## Ask for a note, then save the feedback zip and show the folder.
func send_feedback() -> void:
	_open = true
	var shot := get_viewport().get_texture().get_image()
	var m := Modal.new()
	m.build(Strings.t("feedback.title"), 380)
	m.text(Strings.t("feedback.prompt"), UiTheme.DIM)
	var note := TextEdit.new()
	note.custom_minimum_size = Vector2(340, 80)
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	m.body.add_child(note)
	m.add_button(Strings.t("feedback.send"), func() -> void: m.finish(note.text))
	m.add_button(Strings.t("feedback.cancel"), func() -> void: m.finish(null))
	note.grab_focus.call_deferred()
	var got: Variant = await Flow.show_modal(m)
	if got != null:
		var path := save_zip({ "note.txt": str(got).to_utf8_buffer() }, shot)
		Narrator.say(Strings.t("feedback.saved") % ProjectSettings.globalize_path(path))
		if not GameState.dev_autoplay and DisplayServer.get_name() != "headless":
			OS.shell_open(ProjectSettings.globalize_path(DIR))
	_open = false


## Write a feedback zip with these extra files plus the standard set. Returns its path.
func save_zip(extra: Dictionary, shot: Image = null) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/feedback_%s.zip" % [DIR, stamp]
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		push_warning("Feedback: could not write %s" % path)
		return ""
	var files := extra.duplicate()
	files["version.txt"] = ("%s\n%s\n" % [version(), Engine.get_version_info().get("string", "")]).to_utf8_buffer()
	files["summary.json"] = JSON.stringify(_summary(), "  ").to_utf8_buffer()
	for p in [PlayLog.path, SaveSystem.SAVE_PATH, "user://logs/godot.log"]:
		if FileAccess.file_exists(str(p)):
			files[str(p).get_file()] = FileAccess.get_file_as_bytes(str(p))
	if shot != null and not shot.is_empty():
		files["screenshot.png"] = shot.save_png_to_buffer()
	for name in files:
		zip.start_file(str(name))
		zip.write_file(files[name])
		zip.close_file()
	zip.close()
	last_zip = path
	return path


func _summary() -> Dictionary:
	var records: Array = []
	if FileAccess.file_exists(PlayLog.path):
		for line in FileAccess.get_file_as_string(PlayLog.path).split("\n"):
			var parsed: Variant = JSON.parse_string(line) if line.strip_edges() != "" else null
			if parsed is Dictionary:
				records.append(parsed)
	var where := {}
	if GameState.has_run():
		where = { "week": Calendar.week(), "day": Calendar.day_name(), "part": Calendar.part_id(), "scene": str(get_tree().current_scene.name) if get_tree().current_scene != null else "" }
	return Demo.log_summary(records, GameState.run if GameState.has_run() else {}, where)


## The demo's ending: thanks, the survey, then back to the title.
func end_demo() -> void:
	var db: Dictionary = DataDB.all()
	var t := Demo.thanks(db, GameState.run, Journal.data)
	var lines: Array = [Strings.t("demo.thanks_text")]
	lines.append(Strings.t("demo.combos") % [t["combos"].size(), int(t["comboTotal"])])
	lines.append(Strings.t("demo.met") % (", ".join(PackedStringArray(t["met"])) if not t["met"].is_empty() else "-"))
	lines.append(Strings.t("demo.coming"))
	for c in t["coming"]:
		lines.append("- " + str(c))
	Audio.play_music_first(["victory", "title"])
	await Flow.show_event({ "title": Strings.t("demo.thanks_title"), "text": "\n".join(PackedStringArray(lines)) })
	var answers := await _survey(Demo.survey(db))
	if not answers.is_empty():
		save_zip({ "survey.json": JSON.stringify(answers, "  ").to_utf8_buffer() })
	GameState.set_flag("demo_ended")
	EventBus.run_ended.emit("demo_end")


## 5 to 7 quick questions from data/demo.json. Returns { id: answer }, or {} if skipped.
func _survey(questions: Array) -> Dictionary:
	var answers := {}
	for q in questions:
		var qd: Dictionary = q
		var m := Modal.new()
		m.build(Strings.t("demo.survey_title"), 380)
		m.text(str(qd.get("text", "")), UiTheme.ACCENT)
		var field: TextEdit = null
		match str(qd.get("type", "text")):
			"scale":
				var r := m.row()
				for i in range(int(qd.get("min", 1)), int(qd.get("max", 5)) + 1):
					var v := i
					r.add_child(UiTheme.button(str(i), func() -> void: m.finish(v)))
			"choice":
				for o in qd.get("options", []):
					var label := str(o)
					m.add_button(label, func() -> void: m.finish(label))
			_:
				field = TextEdit.new()
				field.custom_minimum_size = Vector2(340, 50)
				field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
				m.body.add_child(field)
				var f := field
				m.add_button(Strings.t("demo.next"), func() -> void: m.finish(f.text))
		m.add_button(Strings.t("demo.skip_survey"), func() -> void: m.finish("__skip"))
		if GameState.dev_autoplay:
			m.finish.call_deferred("")
		var got: Variant = await Flow.show_modal(m)
		if str(got) == "__skip":
			return answers
		answers[str(qd.get("id", ""))] = got
	return answers

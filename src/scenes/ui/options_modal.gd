## Options (ROADMAP M22): volumes, text speed, screen shake, window size and
## fullscreen, the colorblind palette, Easy minigames, key rebinding, and what
## mode and difficulty this run uses. Saved in user://settings.cfg.
extends "res://src/scenes/ui/modal.gd"

const SETTINGS := "user://settings.cfg"
const SR := preload("res://src/core/settings_rules.gd")

var _page := "main"
var _waiting := ""


func _ready() -> void:
	build(Strings.t("options.title"), Display.base.x * 0.56)
	_refresh()


func _save_setting(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value(section, key, value)
	cfg.save(SETTINGS)


func _load_setting(section: String, key: String, fallback: Variant) -> Variant:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	return cfg.get_value(section, key, fallback)


func _refresh() -> void:
	clear_body()
	if _page == "keys":
		_keys()
		return
	var db: Dictionary = DataDB.all()
	var oc := SR.cfg(db)
	for ch in ["music", "sfx", "ambience", "voice"]:
		var channel: String = ch
		var vol := float(_load_setting("audio", channel, 0.0))
		var r := row()
		r.add_child(UiTheme.label(Strings.t("options.volume") % [Strings.t("options.ch_" + channel), roundi(vol)]))
		r.add_child(UiTheme.button("-", func() -> void:
			_save_setting("audio", channel, SR.step_volume(db, vol, false))
			Audio.apply_volumes()
			_refresh()))
		r.add_child(UiTheme.button("+", func() -> void:
			_save_setting("audio", channel, SR.step_volume(db, vol, true))
			Audio.apply_volumes()
			_refresh()))
	var speed := int(_load_setting("text", "speed", 45))
	add_button(Strings.t("options.text_speed") % (Strings.t("options.instant") if speed >= 999 else str(speed)), func() -> void:
		_save_setting("text", "speed", int(SR.cycle(oc.get("textSpeeds", [45]), speed)))
		_refresh())
	add_button(Strings.t("options.shake") % (Strings.t("options.on") if UiTheme.shake_on else Strings.t("options.off")), func() -> void:
		_save_setting("fx", "shake", not UiTheme.shake_on)
		_refresh())
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	add_button(Strings.t("options.fullscreen") % (Strings.t("options.on") if full else Strings.t("options.off")), func() -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_save_setting("display", "fullscreen", not full)
		_refresh())
	var scale := int(_load_setting("display", "scale", int(DataDB.table("display").get("windowScale", 2))))
	add_button(Strings.t("options.window") % scale, func() -> void:
		var next := int(SR.cycle(oc.get("windowScales", [2]), scale))
		_save_setting("display", "scale", next)
		if not full:
			DisplayServer.window_set_size(Display.base * next)
		_refresh())
	add_button(Strings.t("options.colorblind") % (Strings.t("options.on") if UiTheme.colorblind else Strings.t("options.off")), func() -> void:
		UiTheme.set_colorblind(not UiTheme.colorblind)
		UiTheme.rebuild()
		_refresh())
	var easy := bool(_load_setting("minigames", "easy", false))
	add_button(Strings.t("options.minigames") % (Strings.t("options.easy") if easy else Strings.t("options.normal")), func() -> void:
		_save_setting("minigames", "easy", not easy)
		_refresh())
	add_button(Strings.t("options.keys"), func() -> void:
		_page = "keys"
		_refresh())
	if GameState.has_run():
		var modes: Dictionary = DataDB.table("run_modes").get("modes", {})
		var mode := str(modes.get(str(GameState.run.get("runMode", "permadeath")), {}).get("name", "-"))
		var diff := str(DataDB.table("combat_rules").get("difficulties", {}).get(GameState.combat_difficulty, {}).get("name", GameState.combat_difficulty))
		text(Strings.t("options.this_run") % [mode, diff], UiTheme.DIM)
	add_button(Strings.t("options.clear_data"), _clear_data)
	add_button(Strings.t("feedback.button"), func() -> void:
		finish(null)
		Feedback.send_feedback.call_deferred())
	add_button(Strings.t("party_panel.close"), func() -> void: finish(null))
	focus_first()


## Wipe saved data, with a confirmation: the Journal (unlocks, achievements,
## records), the settings, the current save, or everything.
func _clear_data() -> void:
	var m := preload("res://src/scenes/ui/modal.gd").new()
	m.build(Strings.t("options.clear_title"), Display.base.x * 0.5)
	m.text(Strings.t("options.clear_warning"), UiTheme.BAD)
	for k in ["journal", "settings", "save", "all"]:
		var key: String = k
		m.add_button(Strings.t("options.clear_" + key), func() -> void: m.finish(key))
	m.add_button(Strings.t("options.back"), func() -> void: m.finish(null))
	var pick: Variant = await Flow.show_modal(m)
	if pick == null:
		return
	var confirm := preload("res://src/scenes/ui/modal.gd").new()
	confirm.build(Strings.t("options.clear_sure"), Display.base.x * 0.45)
	confirm.add_button(Strings.t("options.clear_yes"), func() -> void: confirm.finish(true))
	confirm.add_button(Strings.t("options.back"), func() -> void: confirm.finish(false))
	if not bool(await Flow.show_modal(confirm)):
		return
	var what := str(pick)
	if what in ["journal", "all"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Journal.PATH))
		Journal.load_journal()
	if what in ["settings", "all"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
		Audio.apply_volumes()
	if what in ["save", "all"]:
		SaveSystem.delete_save()
	if what == "all" and FileAccess.file_exists(PlayLog.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayLog.path))
	Narrator.say(Strings.t("options.cleared"))
	_refresh()


func _keys() -> void:
	text(Strings.t("options.keys_help"), UiTheme.DIM)
	for a in SR.cfg(DataDB.all()).get("rebindable", []):
		var action := str(a)
		var label := Strings.t("options.waiting") if _waiting == action else InputSetup.key_text(action)
		add_button("%s: %s" % [Strings.t("options.action_" + action), label], func() -> void:
			_waiting = action
			_refresh())
	add_button(Strings.t("options.back"), func() -> void:
		_waiting = ""
		_page = "main"
		_refresh())
	focus_first()


func _input(event: InputEvent) -> void:
	if _waiting == "" or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	InputSetup.rebind(_waiting, (event as InputEventKey).physical_keycode)
	_waiting = ""
	_refresh()

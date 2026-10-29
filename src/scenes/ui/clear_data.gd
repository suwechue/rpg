## Clear saved data, with a confirmation: metadata (the Narrator's Journal:
## unlocks, achievements, records), settings, the current save, or everything.
## Opened from the title screen and Options.
extends RefCounted

const Modal := preload("res://src/scenes/ui/modal.gd")


static func ask() -> void:
	var m := Modal.new()
	m.build(Strings.t("options.clear_title"), Display.base.x * 0.55)
	m.text(Strings.t("options.clear_warning"), UiTheme.BAD)
	for k in ["meta", "settings", "save", "all"]:
		var key: String = k
		m.add_button(Strings.t("options.clear_" + key), func() -> void: m.finish(key), key == "save" and not SaveSystem.has_save())
	m.add_button(Strings.t("options.back"), func() -> void: m.finish(null))
	var pick: Variant = await Flow.show_modal(m)
	if pick == null:
		return
	var confirm := Modal.new()
	confirm.build(Strings.t("options.clear_sure"), Display.base.x * 0.45)
	confirm.text(Strings.t("options.clear_" + str(pick)), UiTheme.DIM)
	confirm.add_button(Strings.t("options.clear_yes"), func() -> void: confirm.finish(true))
	confirm.add_button(Strings.t("options.back"), func() -> void: confirm.finish(false))
	if not bool(await Flow.show_modal(confirm)):
		return
	var gone := SaveSystem.clear_data(str(pick))
	Narrator.say(Strings.t("options.cleared") if not gone.is_empty() else Strings.t("options.nothing_to_clear"))
	EventBus.screen_closed.emit("clear_data")

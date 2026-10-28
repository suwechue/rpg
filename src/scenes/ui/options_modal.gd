## A small Options panel until the full Options screen (M22): Easy minigames
## (PT Part 5) and the colorblind palette. Saved in user://settings.cfg.
extends "res://src/scenes/ui/modal.gd"

const SETTINGS := "user://settings.cfg"


func _ready() -> void:
	build(Strings.t("options.title"), 300)
	_refresh()


func _refresh() -> void:
	clear_body()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	var easy := bool(cfg.get_value("minigames", "easy", false))
	add_button(Strings.t("options.minigames") % (Strings.t("options.easy") if easy else Strings.t("options.normal")), func() -> void:
		cfg.set_value("minigames", "easy", not easy)
		cfg.save(SETTINGS)
		_refresh())
	add_button(Strings.t("options.colorblind") % (Strings.t("options.on") if UiTheme.colorblind else Strings.t("options.off")), func() -> void:
		UiTheme.set_colorblind(not UiTheme.colorblind)
		UiTheme.rebuild()
		_refresh())
	add_button(Strings.t("feedback.button"), func() -> void:
		finish(null)
		Feedback.send_feedback.call_deferred())
	add_button(Strings.t("party_panel.close"), func() -> void: finish(null))
	focus_first()

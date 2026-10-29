## TL Part 7: "What can I do?" Open places and who's there, favors, mystery
## leads, Bond scenes and the forge, from src/core/town/goals.gd. Opens with G
## or from the town pause menu.
extends "res://src/scenes/ui/modal.gd"

const Goals := preload("res://src/core/town/goals.gd")

const MAX_LINES := 5


func _ready() -> void:
	build(Strings.t("goals.title"), Display.base.x * 0.7)
	var g := Goals.build(DataDB.all(), GameState.run, { "week": Calendar.week(), "day": Calendar.day_name(),
		"part": Calendar.part_id(), "day_count": int(GameState.run.get("day_count", 0)) })
	for section in Goals.SECTIONS:
		text(Strings.t("goals." + section), UiTheme.ACCENT)
		var lines: Array = g.get(section, [])
		if lines.is_empty():
			text("  " + Strings.t("goals.nothing"), UiTheme.DIM)
		for i in mini(lines.size(), MAX_LINES):
			text("  - " + str(lines[i]))
		if lines.size() > MAX_LINES:
			text("  " + Strings.t("goals.more") % (lines.size() - MAX_LINES), UiTheme.DIM)
	add_button(Strings.t("goals.close"), func() -> void: finish(null))
	focus_first()

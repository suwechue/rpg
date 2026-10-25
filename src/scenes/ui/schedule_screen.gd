## Weekly schedule: pick one class for each of the 3 periods.
extends "res://src/scenes/ui/modal.gd"

const School := preload("res://src/core/run/school.gd")

var picks: Array = []


func _ready() -> void:
	picks = GameState.schedule.duplicate()
	build(Strings.t("schedule.week_schedule") % Calendar.week(), 420)
	_refresh()


func _refresh() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	text(Strings.t("schedule.pick_a_class_for_each"), UiTheme.DIM)
	for period in 3:
		var r := row()
		r.add_child(UiTheme.label("P%d" % (period + 1), UiTheme.ACCENT))
		var flow := HFlowContainer.new()
		flow.custom_minimum_size = Vector2(380, 0)
		r.add_child(flow)
		for cls in School.classes(db):
			var cid := str(cls["id"])
			var err := School.class_gate_error(db, GameState.run, cid)
			var chosen: bool = period < picks.size() and str(picks[period]) == cid
			var p := period
			var b := UiTheme.button(("[%s]" if chosen else "%s") % str(cls["name"]), func() -> void:
				while picks.size() < 3:
					picks.append("")
				picks[p] = cid
				_refresh())
			b.disabled = err != ""
			b.tooltip_text = Strings.t("schedule.teacher") % [cls.get("blurb", ""), str(db.get("school_classes", {}).get("professors", {}).get(str(cls.get("professor", "")), "")), err]
			if chosen:
				b.theme_type_variation = "SelectedButton"
			flow.add_child(b)
	var err := School.schedule_error(db, GameState.run, picks)
	if err != "":
		text(err, UiTheme.BAD)
	add_button(Strings.t("schedule.confirm_schedule"), func() -> void:
		School.set_schedule(DataDB.all(), GameState.run, picks, Calendar.week())
		Narrator.say(Strings.t("schedule.schedule_set") % ", ".join(PackedStringArray(picks.map(func(c: Variant) -> String: return str(School.class_rec(DataDB.all(), str(c)).get("name", c))))))
		finish(picks), err != "")
	focus_first()

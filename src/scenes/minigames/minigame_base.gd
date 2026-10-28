## Shared frame for the crafting minigames: a dimmed backdrop, a titled box,
## E / click / A as the action, and finish(performance 0..1).
extends Control

signal finished(performance: float)

var archetype := ""
var title := ""
var hint := ""
var done := false
var box := Rect2(80, 60, 320, 150)


## Timing from data/minigames.json "timing": windows and limits x windowMul,
## and again x easyMul with the Easy minigame setting (PT Part 5).
static func timing(key: String, fallback: Variant) -> Variant:
	return DataDB.table("minigames").get("timing", {}).get(key, fallback)


static func time_mul() -> float:
	var t: Dictionary = DataDB.table("minigames").get("timing", {})
	var cfg := ConfigFile.new()
	var easy := cfg.load("user://settings.cfg") == OK and bool(cfg.get_value("minigames", "easy", false))
	return float(t.get("windowMul", 1.5)) * (float(t.get("easyMul", 1.5)) if easy else 1.0)


func _ready() -> void:
	box.position = (Display.size_f() - box.size) / 2.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			action_pressed()
		else:
			action_released()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event.is_action_pressed("interact"):
		action_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("interact"):
		action_released()
		get_viewport().set_input_as_handled()
	else:
		other_input(event)


func action_pressed() -> void:
	pass


func action_released() -> void:
	pass


func other_input(_event: InputEvent) -> void:
	pass


func finish(performance: float) -> void:
	if done:
		return
	done = true
	Audio.play_sfx("click")
	queue_redraw()
	await get_tree().create_timer(0.6).timeout
	finished.emit(clampf(performance, 0.0, 1.0))
	queue_free()


func draw_frame(status: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, Display.size_f()), Color(0, 0, 0, 0.7))
	draw_rect(box, Color("141824"))
	draw_rect(box, Color("ffd966"), false, 1.0)
	var font: Font = UiTheme.font
	draw_string(font, box.position + Vector2(10, 7 + UiTheme.FONT_SIZE), Strings.t("minigame_base.minigame") % title, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color("ffd966"))
	draw_string(font, box.position + Vector2(10, 30), hint, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 20, UiTheme.FONT_SIZE, Color("8c8fa3"))
	draw_string(font, box.position + Vector2(10, box.size.y - 8), status, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 20, UiTheme.FONT_SIZE, Color("e8e6d8"))

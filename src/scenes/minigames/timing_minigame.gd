## Stub crafting minigame shared by every archetype until M8: a marker sweeps
## across a bar; stop it on the target (E, Enter, click or A) three times.
## Performance = the average closeness, 0..1. Emits `finished(performance)`.
extends Control

signal finished(performance: float)

const ROUNDS := 3

var archetype := "precision"
var title := "Precision"
var hint := ""
var speed := 1.3
var _t := 0.0
var _round := 0
var _scores: Array = []
var _target := 0.5
var _done := false
var _flash := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_target = 0.5
	set_process(true)


func _marker() -> float:
	return 0.5 + 0.5 * sin(_t * speed * TAU * 0.5)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta * (1.0 + 0.25 * float(_round))
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_stop()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_stop()
		get_viewport().set_input_as_handled()


func _stop() -> void:
	if _done:
		return
	var score := clampf(1.0 - absf(_marker() - _target) / 0.35, 0.0, 1.0)
	_scores.append(score)
	_round += 1
	_flash = 0.3
	Audio.play_sfx("click")
	if _round >= ROUNDS:
		_done = true
		var total := 0.0
		for s in _scores:
			total += float(s)
		var perf := total / float(_scores.size())
		queue_redraw()
		await get_tree().create_timer(0.6).timeout
		finished.emit(perf)
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.7))
	var box := Rect2(90, 80, 300, 110)
	draw_rect(box, Color("141824"))
	draw_rect(box, Color("ffd966"), false, 1.0)
	var font: Font = UiTheme.font
	draw_string(font, Vector2(100, 96), "%s minigame  (round %d/%d)" % [title, mini(_round + 1, ROUNDS), ROUNDS], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color("ffd966"))
	draw_string(font, Vector2(100, 110), hint, HORIZONTAL_ALIGNMENT_LEFT, 280, UiTheme.FONT_SIZE, Color("8c8fa3"))
	var bar := Rect2(110, 130, 260, 14)
	draw_rect(bar, Color("262c40"))
	var zone_w := bar.size.x * 0.12
	draw_rect(Rect2(bar.position.x + bar.size.x * _target - zone_w / 2.0, bar.position.y, zone_w, bar.size.y), Color("8fd694", 0.6))
	var mx := bar.position.x + bar.size.x * _marker()
	draw_rect(Rect2(mx - 1, bar.position.y - 3, 3, bar.size.y + 6), Color.WHITE if _flash <= 0.0 else Color("ffd966"))
	var s := ""
	for v in _scores:
		s += "%d%%  " % roundi(float(v) * 100.0)
	draw_string(font, Vector2(110, 162), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color("e8e6d8"))
	draw_string(font, Vector2(110, 178), "[E] / click to stop the marker in the green band", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color("8c8fa3"))

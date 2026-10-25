## Chemical (Tier 3 Vectors): add four reagents in the shown order with the
## arrow keys before the mix turns. Performance = correct steps, minus a little
## for time and mistakes.
extends "res://src/scenes/minigames/minigame_base.gd"

const LIMIT := 6.0
const KEYS := ["move_up", "move_right", "move_down", "move_left"]
const NAMES := ["Up", "Right", "Down", "Left"]
const COLORS := ["#e87cc9", "#5fd98a", "#8a9b3c", "#7cc7e8"]

var _seq: Array = []
var _step := 0
var _mistakes := 0
var _t := 0.0


func _ready() -> void:
	super._ready()
	var rng := Rng.stream("fx")
	for i in 4:
		_seq.append(rng.randi_range(0, 3))


func other_input(event: InputEvent) -> void:
	for i in 4:
		if event.is_action_pressed(KEYS[i]):
			get_viewport().set_input_as_handled()
			if i == int(_seq[_step]):
				_step += 1
				Audio.play_sfx("click")
				if _step >= _seq.size():
					finish(1.0 - 0.15 * _mistakes - 0.3 * (_t / LIMIT))
			else:
				_mistakes += 1
			return


func action_pressed() -> void:
	pass


func _process(delta: float) -> void:
	if done:
		return
	_t += delta
	if _t >= LIMIT:
		finish(float(_step) / float(_seq.size()) * 0.7 - 0.1 * _mistakes)
	queue_redraw()


func _draw() -> void:
	draw_frame(Strings.t("chemical_minigame.mix_turns_in_1f_s") % [maxf(0.0, LIMIT - _t), _mistakes])
	for i in _seq.size():
		var p := box.position + Vector2(60 + i * 52, 70)
		var idx := int(_seq[i])
		var col := Color(str(COLORS[idx]))
		if i < _step:
			col = col.darkened(0.6)
		draw_rect(Rect2(p, Vector2(40, 30)), col)
		draw_string(UiTheme.font, p + Vector2(4, 44), str(NAMES[idx]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color("e8e6d8"))
		if i == _step:
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(44, 34)), Color("ffd966"), false, 1.0)

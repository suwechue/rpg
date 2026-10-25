## Alignment (Binding or Light): three rings spin at different speeds, each
## with a gap. Press E to lock each ring with its gap at the top.
## Performance = average closeness of the gaps to the top.
extends "res://src/scenes/minigames/minigame_base.gd"

const SPEEDS := [1.4, -2.0, 2.7]

var _angles := [0.5, 2.0, 4.0]
var _locked := 0
var _scores: Array = []


func action_pressed() -> void:
	if _locked >= 3:
		return
	var a: float = fposmod(float(_angles[_locked]), TAU)
	var off := minf(absf(a), absf(TAU - a))
	_scores.append(clampf(1.0 - off / 1.2, 0.0, 1.0))
	_locked += 1
	Audio.play_sfx("click")
	if _locked >= 3:
		var total := 0.0
		for s in _scores:
			total += float(s)
		finish(total / 3.0)


func _process(delta: float) -> void:
	if done:
		return
	for i in range(_locked, 3):
		_angles[i] = float(_angles[i]) + float(SPEEDS[i]) * delta
	queue_redraw()


func _draw() -> void:
	var s := ""
	for v in _scores:
		s += "%d%%  " % roundi(float(v) * 100.0)
	draw_frame(Strings.t("alignment_minigame.ring_3") % [mini(_locked + 1, 3), s])
	var center := box.position + Vector2(box.size.x / 2.0, 90)
	draw_line(center + Vector2(0, -52), center + Vector2(0, -40), Color("8fd694"), 2.0)
	for i in 3:
		var r := 18.0 + 11.0 * i
		var a: float = float(_angles[i]) - PI / 2.0
		var col := Color("b07ce8") if i >= _locked else Color("f5e27a")
		draw_arc(center, r, a + 0.4, a + TAU - 0.4, 36, col, 3.0)

## Precision (Force or Motion): a marker swings across a bar; stop it on the
## target three times (it speeds up). Performance = average closeness.
extends "res://src/scenes/minigames/minigame_base.gd"

const ROUNDS := 3

var _t := 0.0
var _round := 0
var _scores: Array = []
var _flash := 0.0


func _marker() -> float:
	return 0.5 + 0.5 * sin(_t * float(timing("precisionSpeed", 1.3)) / time_mul() * TAU * 0.5)


func _process(delta: float) -> void:
	if done:
		return
	_t += delta * (1.0 + 0.25 * float(_round))
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func action_pressed() -> void:
	if _round >= ROUNDS:
		return
	_scores.append(clampf(1.0 - absf(_marker() - 0.5) / 0.35, 0.0, 1.0))
	_round += 1
	_flash = 0.3
	Audio.play_sfx("click")
	if _round >= ROUNDS:
		var total := 0.0
		for s in _scores:
			total += float(s)
		finish(total / float(ROUNDS))


func _draw() -> void:
	var s := ""
	for v in _scores:
		s += "%d%%  " % roundi(float(v) * 100.0)
	draw_frame(Strings.t("precision_minigame.round_e_to_stop") % [mini(_round + 1, ROUNDS), ROUNDS, s])
	var bar := Rect2(box.position + Vector2(30, 70), Vector2(260, 14))
	draw_rect(bar, Color("262c40"))
	var zone_w := bar.size.x * 0.12
	draw_rect(Rect2(bar.position.x + bar.size.x * 0.5 - zone_w / 2.0, bar.position.y, zone_w, bar.size.y), Color("8fd694", 0.6))
	var mx := bar.position.x + bar.size.x * _marker()
	draw_rect(Rect2(mx - 1, bar.position.y - 3, 3, bar.size.y + 6), Color.WHITE if _flash <= 0.0 else Color("ffd966"))

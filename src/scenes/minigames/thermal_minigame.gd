## Thermal (Heat or Cold): a temperature needle drifts. Hold E to heat, let go
## to cool; keep it inside the band. Performance = share of time in the band.
extends "res://src/scenes/minigames/minigame_base.gd"

const DURATION := 5.0

var _temp := 0.3
var _heating := false
var _t := 0.0
var _in_band := 0.0


func action_pressed() -> void:
	_heating = true


func action_released() -> void:
	_heating = false


func _band_center() -> float:
	return 0.55 + 0.2 * sin(_t * 0.9)


func _process(delta: float) -> void:
	if done:
		return
	_t += delta
	_temp += (0.55 if _heating else -0.45) * delta
	_temp += 0.12 * sin(_t * 3.1) * delta
	_temp = clampf(_temp, 0.0, 1.0)
	if absf(_temp - _band_center()) <= 0.1:
		_in_band += delta
	if _t >= DURATION:
		finish(_in_band / DURATION)
	queue_redraw()


func _draw() -> void:
	draw_frame(Strings.t("thermal_minigame.time_1f_s_in_the") % [maxf(0.0, DURATION - _t), roundi(_in_band / maxf(0.01, _t) * 100.0)])
	var bar := Rect2(box.position + Vector2(150, 44), Vector2(20, 90))
	draw_rect(bar, Color("262c40"))
	var c := _band_center()
	var band_y := bar.end.y - bar.size.y * (c + 0.1)
	draw_rect(Rect2(bar.position.x, band_y, bar.size.x, bar.size.y * 0.2), Color("8fd694", 0.6))
	var ny := bar.end.y - bar.size.y * _temp
	draw_rect(Rect2(bar.position.x - 4, ny - 1, bar.size.x + 8, 3), Color("e8663c") if _heating else Color("7cc7e8"))
	draw_string(UiTheme.font, bar.position + Vector2(30, 50), Strings.t("thermal_minigame.hold_e_to_heat"), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color("e8e6d8"))

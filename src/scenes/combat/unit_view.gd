## An upright unit on the 2.5D battlefield: oval shadow, the pixel sprite at 1x
## (asset id: a walk sheet, or a one-row strip for bosses) facing left or
## right, and a small HP bar. Display only.
extends Node2D

const Walker := preload("res://src/scenes/common/walker_sprite.gd")

var unit_id := ""
var team := "party"
var is_prop := false
var sprite: Sprite2D
var hp_ratio := 1.0
var shield := 0
var downed := false
var highlight := false
var statuses: Array = []   # status ids; icons and colors come from data/ui.json
var intent_icon := ""      # enemies: what they'll do next (data/ui.json "intentIcons")
var charge := 0            # turns left charging a big attack
var friend_link := false   # next to a Friend-tier ally (+5% damage)
var _frame := Vector2i.ONE
var _walker := false
var _bob := 0.0


func setup(id: String, p_team: String, sprite_id: String, prop_kind: String = "") -> void:
	unit_id = id
	team = p_team
	is_prop = prop_kind != ""
	if is_prop:
		return
	_frame = Assets.frame(sprite_id)
	if str(Assets.spec(sprite_id).get("kind", "")) == "strip":
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture = Assets.texture(sprite_id)
		sprite.region_rect = Rect2(Vector2.ZERO, _frame)
		sprite.offset = Vector2(-_frame.x / 2.0, -_frame.y)
	else:
		var w := Walker.new(sprite_id)
		w.offset = Vector2(-_frame.x / 2.0, -_frame.y)
		sprite = w
		_walker = true
	add_child(sprite)


func face(dir: int) -> void:
	if _walker:
		(sprite as Walker).face(Vector2i(dir, 0))
	elif sprite != null:
		sprite.flip_h = dir > 0


func walk_tick(delta: float) -> void:
	if _walker:
		(sprite as Walker).play_walk(delta)


func stop_walk() -> void:
	if _walker:
		(sprite as Walker).stop()


func _process(delta: float) -> void:
	if downed or is_prop:
		return
	_bob += delta
	queue_redraw()


func sprite_height() -> float:
	if is_prop:
		return Display.tile * 0.56
	return float(_frame.y)


func _draw() -> void:
	var w := Display.tile * (0.44 if not is_prop else 0.5)
	var pts := PackedVector2Array()
	var segments := 18
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a) * w, sin(a) * 3.5))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.35))
	if is_prop:
		var h := sprite_height()
		var hw := Display.tile * 0.35
		draw_rect(Rect2(-hw, -h, hw * 2.0, h), Color("7a5a3a"))
		draw_rect(Rect2(-hw, -h, hw * 2.0, 4), Color("9c7a52"))
		draw_rect(Rect2(-hw, -h, hw * 2.0, h), Color("3d2b1a"), false, 1.0)
		draw_line(Vector2(-hw, -h), Vector2(hw, 0), Color("3d2b1a"), 1.0)
	if highlight:
		draw_arc(Vector2.ZERO, w + 2.0, 0, TAU, 20, Color("ffd966"), 1.0)
	var top := -sprite_height() - 5.0
	var bar_w := 20.0
	draw_rect(Rect2(-bar_w / 2.0, top, bar_w, 3), Color(0, 0, 0, 0.7))
	var col := Color("8fd694") if team == "party" else Color("e8746a")
	if is_prop:
		col = Color("c9a66b")
	draw_rect(Rect2(-bar_w / 2.0, top, bar_w * clampf(hp_ratio, 0.0, 1.0), 3), col)
	if shield > 0:
		draw_rect(Rect2(-bar_w / 2.0, top - 2, bar_w, 1), Color("7cc7e8"))
	# Status icons sit in one row under the feet, clear of floating texts above.
	# Hovering the unit names them (combat.gd hover info).
	var icon_w := Display.tile / 2.0
	var x := -float(statuses.size()) * icon_w / 2.0
	for id in statuses:
		var info := UiTheme.status_info(str(id))
		var tex := Assets.texture(str(info.get("icon", "")))
		draw_texture_rect(tex, Rect2(x, 3, icon_w, icon_w), false, Color(str(info.get("color", "#ffffff"))))
		x += icon_w
	if friend_link:
		var link := Assets.texture("icon_vector_binding")
		draw_texture_rect(link, Rect2(Display.tile * 0.35, -Display.tile * 0.3, Display.tile / 2.0, Display.tile / 2.0), false, UiTheme.GOOD)
	if intent_icon != "" and not downed:
		var ic := Assets.texture(intent_icon)
		var at := Vector2(-ic.get_width() / 2.0, top - ic.get_height() - 2)
		var tint := UiTheme.color("bad") if charge > 0 or intent_icon.ends_with("attack") or intent_icon.ends_with("tracking") else UiTheme.TEXT
		draw_texture(ic, at, tint)
		if charge > 0:
			var f := UiTheme.font
			var p := at + Vector2(ic.get_width() + 1, UiTheme.FONT_SIZE)
			draw_string_outline(f, p, str(charge), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, 3, UiTheme.color("outline"))
			draw_string(f, p, str(charge), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, UiTheme.ACCENT)
	if downed and sprite != null:
		sprite.modulate = Color(0.5, 0.5, 0.6, 0.6)
		sprite.rotation = PI / 2.0 if team == "party" else -PI / 2.0
	elif sprite != null:
		sprite.modulate = Color.WHITE
		sprite.rotation = 0.0

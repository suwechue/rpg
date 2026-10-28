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
var affixes: Array = []    # elite affix ids (icons from data/ui.json "affixes")
var burrowed := false
var active := false        # CT Part 2b: the unit whose turn it is (ring, bob, full color)
var acted := false         # already took its turn this round (check mark, a bit darker)
var spotlight := false
var covered := false       # in cover against the relevant attacker (CT Part 3)
var tag := 0               # PT Part 3: number on duplicate enemies ("Wisp 2")
var max_hp := 1
var bleed := 0             # downed: rounds before they're out
var fade := 1.0            # see-through: units in front of the hovered tile fade
var focus := false         # the attacker behind a hovered red tile     # someone else's turn: dim and desaturate the sprite only
var _dim := 0.0            # 0 = full color, 1 = fully dimmed (tweened)
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
	var mat := ShaderMaterial.new()
	mat.shader = _spot_shader()
	sprite.material = mat


static var _shader: Shader


## Brightness and saturation for the spotlight, on the sprite only, so HP bars,
## icons and telegraphs drawn by this node stay bright.
static func _spot_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """shader_type canvas_item;
uniform float brightness = 1.0;
uniform float saturation = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(g), c.rgb, saturation) * brightness;
	COLOR = c;
}
"""
	return _shader


func _spot() -> Dictionary:
	return DataDB.table("ui").get("spotlight", {})


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
	var sp := _spot()
	var want := 1.0 if spotlight and bool(sp.get("enabled", true)) else 0.0
	var fade := maxf(0.01, float(sp.get("fade", 0.2)))
	_dim = move_toward(_dim, want, delta / fade)
	if sprite != null and sprite.material is ShaderMaterial:
		var lo := float(sp.get("actedBrightness", 0.42)) if acted else float(sp.get("brightness", 0.55))
		(sprite.material as ShaderMaterial).set_shader_parameter("brightness", lerpf(1.0, lo, _dim))
		(sprite.material as ShaderMaterial).set_shader_parameter("saturation", lerpf(1.0, float(sp.get("saturation", 0.5)), _dim))
	if downed or is_prop:
		return
	_bob += delta
	if sprite != null:
		sprite.position.y = -absf(sin(_bob * float(sp.get("bobSpeed", 4.0)))) * float(sp.get("bob", 1.0)) if active else 0.0
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
	if is_prop and unit_id.begins_with("low_wall"):
		# A low stone wall: wide and short, so it reads as cover, not a crate.
		var lh := sprite_height() * 0.6
		var lw := Display.tile * 0.45
		draw_rect(Rect2(-lw, -lh, lw * 2.0, lh), Color("8a8f98"))
		draw_rect(Rect2(-lw, -lh, lw * 2.0, 3), Color("b3b8c0"))
		draw_line(Vector2(-lw * 0.3, -lh + 3), Vector2(-lw * 0.3, 0), Color("5c6068"), 1.0)
		draw_line(Vector2(lw * 0.4, -lh + 3), Vector2(lw * 0.4, 0), Color("5c6068"), 1.0)
		draw_rect(Rect2(-lw, -lh, lw * 2.0, lh), Color("4a4d54"), false, 1.0)
	elif is_prop:
		var h := sprite_height()
		var hw := Display.tile * 0.35
		draw_rect(Rect2(-hw, -h, hw * 2.0, h), Color("7a5a3a"))
		draw_rect(Rect2(-hw, -h, hw * 2.0, 4), Color("9c7a52"))
		draw_rect(Rect2(-hw, -h, hw * 2.0, h), Color("3d2b1a"), false, 1.0)
		draw_line(Vector2(-hw, -h), Vector2(hw, 0), Color("3d2b1a"), 1.0)
	if highlight:
		var pulse := 0.5 + 0.5 * sin(_bob * float(_spot().get("ringPulse", 5.0)))
		draw_arc(Vector2.ZERO, w + 2.0 + pulse, 0, TAU, 20, Color(UiTheme.ACCENT, 0.6 + 0.4 * pulse), 1.0)
	var top := -sprite_height() - 5.0
	var bar_w := 20.0
	draw_rect(Rect2(-bar_w / 2.0, top, bar_w, 3), Color(0, 0, 0, 0.7))
	var col := Color("8fd694") if team == "party" else Color("e8746a")
	if is_prop:
		col = Color("c9a66b")
	draw_rect(Rect2(-bar_w / 2.0, top, bar_w * clampf(hp_ratio, 0.0, 1.0), 3), col)
	if shield > 0:
		# The shield as a segment on the HP bar, and its number (PT Part 3).
		var sw := bar_w * clampf(float(shield) / float(maxi(1, max_hp)), 0.0, 1.0)
		var start := bar_w * clampf(hp_ratio, 0.0, 1.0)
		draw_rect(Rect2(-bar_w / 2.0 + minf(start, bar_w - sw), top, sw, 3), Color("7cc7e8"))
		draw_string_outline(UiTheme.font, Vector2(bar_w / 2.0 + 1, top + 4), str(shield), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, 2, UiTheme.color("outline"))
		draw_string(UiTheme.font, Vector2(bar_w / 2.0 + 1, top + 4), str(shield), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color("7cc7e8"))
	if tag > 0:
		draw_string_outline(UiTheme.font, Vector2(-bar_w / 2.0 - 7, top + 4), str(tag), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, 2, UiTheme.color("outline"))
		draw_string(UiTheme.font, Vector2(-bar_w / 2.0 - 7, top + 4), str(tag), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, UiTheme.TEXT)
	if focus:
		draw_arc(Vector2.ZERO, w + 4.0, 0, TAU, 20, UiTheme.color("bad"), 2.0)
	if downed and not is_prop:
		# A heart and the bleed-out counter: revive with any heal.
		var hx := Vector2(-4, top - 10)
		draw_circle(hx + Vector2(-1.5, 0), 2.0, UiTheme.color("bad"))
		draw_circle(hx + Vector2(1.5, 0), 2.0, UiTheme.color("bad"))
		draw_colored_polygon(PackedVector2Array([hx + Vector2(-3.5, 0.5), hx + Vector2(3.5, 0.5), hx + Vector2(0, 4)]), UiTheme.color("bad"))
		draw_string(UiTheme.font, hx + Vector2(6, 4), str(bleed), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, UiTheme.TEXT)
	# Status icons sit in one row under the feet, clear of floating texts above.
	# Hovering the unit names them (combat.gd hover info).
	var icon_w := Display.tile / 2.0
	var x := -float(statuses.size()) * icon_w / 2.0
	for id in statuses:
		var info := UiTheme.status_info(str(id))
		var tex := Assets.texture(str(info.get("icon", "")))
		draw_texture_rect(tex, Rect2(x, 3, icon_w, icon_w), false, Color(str(info.get("color", "#ffffff"))))
		x += icon_w
	if covered and not downed:
		var sh := Assets.texture(str(DataDB.table("ui").get("coverIcon", "icon_status_guard")))
		draw_texture_rect(sh, Rect2(-Display.tile * 0.55, top - Display.tile * 0.15, Display.tile / 2.0, Display.tile / 2.0), false, UiTheme.color("cover", Color("7cc7e8")))
	if acted and not downed and not is_prop:
		# A small check mark: this unit already acted this round.
		var cx := Display.tile * 0.3
		var cy := top - 1.0
		draw_line(Vector2(cx, cy), Vector2(cx + 2, cy + 2), UiTheme.GOOD, 1.0)
		draw_line(Vector2(cx + 2, cy + 2), Vector2(cx + 6, cy - 3), UiTheme.GOOD, 1.0)
	if friend_link:
		var link := Assets.texture("icon_vector_binding")
		draw_texture_rect(link, Rect2(Display.tile * 0.35, -Display.tile * 0.3, Display.tile / 2.0, Display.tile / 2.0), false, UiTheme.GOOD)
	var ax := -float(affixes.size()) * Display.tile / 4.0
	for a in affixes:
		var info: Dictionary = DataDB.table("ui").get("affixes", {}).get(str(a), {})
		draw_texture_rect(Assets.texture(str(info.get("icon", ""))), Rect2(ax, top - Display.tile / 2.0 - 1, Display.tile / 2.0, Display.tile / 2.0), false, Color(str(info.get("color", "#ffffff"))))
		ax += Display.tile / 2.0
	if sprite != null and not downed:
		sprite.modulate.a = 0.25 if burrowed else 1.0
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
		sprite.modulate = Color(0.5, 0.5, 0.6, 0.6 * fade)
		sprite.rotation = PI / 2.0 if team == "party" else -PI / 2.0
	elif sprite != null:
		sprite.modulate = Color(1, 1, 1, (0.25 if burrowed else 1.0) * fade)
		sprite.rotation = 0.0

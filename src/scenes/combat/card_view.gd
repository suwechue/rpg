## One card in hand (ROADMAP M11): the skin's frame for its kind tinted with
## its Vector color, the art slot (card art asset id), Vector icons, MP cost,
## name and a one-line effect, plus a faint per-Vector pattern so color never
## carries the meaning alone. A Button, so mouse, keyboard and pad all work.
extends Button

const CardRules := preload("res://src/core/card.gd")

var card: Dictionary = {}
var cost := 0
var selected := false
var owner_color := Color(0, 0, 0, 0)   # CT Part 2b: thin border in the owner's color
var held := false                     # PT Part 2: kept over from last turn (a small pin)
var _axes: Array = []
var _frame: Texture2D
var _art: Texture2D
var _tint := Color.WHITE


func setup(p_card: Dictionary, p_cost: int) -> void:
	card = p_card
	cost = p_cost
	var db: Dictionary = DataDB.all()
	var cards: Dictionary = UiTheme.skin("cards")
	var kind := "spell" if CardRules.is_spell(card) else str(card.get("kind", "basic"))
	_frame = Assets.texture(str(cards.get(kind, cards.get("basic", ""))))
	custom_minimum_size = Vector2(_frame.get_size())
	flat = true
	focus_mode = Control.FOCUS_ALL
	_axes = CardRules.ordered_vectors(db, card.get("vectors", {})) if CardRules.is_spell(card) else []
	if not _axes.is_empty():
		_tint = UiTheme.vector_color(str(_axes[0]))
	else:
		_tint = UiTheme.color("itemCard" if kind == "item" else "neutralCard")
	for id in CardRules.art_ids(db, card):
		if Assets.has(str(id)) or Assets.custom_file(str(id)) != "":
			_art = Assets.texture(str(id))
			break
	tooltip_text = Strings.t("card_view.mp") % [card.get("name", ""), cost, CardRules.describe(db, card)]
	queue_redraw()


func _pos(key: String) -> Vector2:
	var a: Array = UiTheme.skin("cards").get(key, [0, 0])
	return Vector2(float(a[0]), float(a[1]))


func _draw() -> void:
	if _frame == null:
		return
	var lift := Vector2(0, -3) if (is_hovered() or has_focus() or selected) and not disabled else Vector2.ZERO
	var dim := Color(0.55, 0.55, 0.6) if disabled else Color.WHITE
	draw_texture(_frame, lift, _tint * dim)
	var art_pos := _pos("artPos") + lift
	if _art != null:
		draw_texture(_art, art_pos, dim)
	var icon_x := art_pos.x + (_art.get_width() if _art != null else 0) - UiTheme.FONT_SIZE * 2
	for axis in _axes:
		var ic := Assets.texture("icon_vector_%s" % axis)
		draw_texture(ic, Vector2(icon_x, art_pos.y + 1), UiTheme.vector_color(str(axis)) * dim)
		icon_x -= ic.get_width() - 2
	var text_pos := _pos("textPos") + lift
	var box := Rect2(text_pos - Vector2(1, 1), Vector2(_frame.get_width() - text_pos.x * 2 + 2, _frame.get_height() - text_pos.y - 3))
	if not _axes.is_empty():
		_pattern(box, UiTheme.vector_pattern(str(_axes[0])), Color(_tint, 0.18))
	var f := UiTheme.font
	var fs := UiTheme.FONT_SIZE
	var cost_pos := _pos("costPos") + lift + Vector2(0, fs - 1)
	draw_string_outline(f, cost_pos, str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, UiTheme.color("outline"))
	draw_string(f, cost_pos, str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.ACCENT if not disabled else UiTheme.DIM)
	var name_w := _frame.get_width() - cost_pos.x - fs - 2
	draw_string(f, cost_pos + Vector2(fs, 0), str(card.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, name_w, fs, UiTheme.TEXT * dim)
	draw_string(f, text_pos + Vector2(0, fs - 1), CardRules.summary(DataDB.all(), card), HORIZONTAL_ALIGNMENT_LEFT, box.size.x, fs, UiTheme.TEXT * dim)
	if owner_color.a > 0.0:
		draw_rect(Rect2(lift, _frame.get_size()), owner_color * dim, false, 1.0)
	if bool(card.get("quick", false)):
		# Quick cards: a bright edge and a QUICK badge (PT Part 3 asks for more; this marks them now).
		draw_rect(Rect2(lift + Vector2(1, 1), _frame.get_size() - Vector2(2, 2)), Color(UiTheme.GOOD, 0.8) * dim, false, 1.0)
	if held:
		draw_circle(lift + Vector2(_frame.get_width() - 4, 4), 2.5, UiTheme.ACCENT)
	if selected:
		draw_texture(Assets.texture(str(UiTheme.skin("cards").get("select", ""))), lift)


## Faint lines or dots behind the effect text, one pattern per Vector.
func _pattern(r: Rect2, kind: String, c: Color) -> void:
	var step := 4.0
	match kind:
		"stripes", "backslash":
			var x := -r.size.y
			while x < r.size.x:
				var a := r.position + Vector2(x, r.size.y) if kind == "stripes" else r.position + Vector2(x, 0)
				var b := a + (Vector2(r.size.y, -r.size.y) if kind == "stripes" else Vector2(r.size.y, r.size.y))
				_clipped_line(r, a, b, c)
				x += step
		"dots", "grid", "checks", "cross", "rings", "waves":
			var y := r.position.y + 1
			var row := 0
			while y < r.end.y:
				var x := r.position.x + 1 + (2.0 if kind == "dots" and row % 2 == 1 else 0.0)
				while x < r.end.x:
					match kind:
						"dots":
							draw_rect(Rect2(x, y, 1, 1), c)
						"grid":
							draw_rect(Rect2(x, r.position.y, 1, r.size.y), c)
						"checks":
							if (int((x - r.position.x) / step) + row) % 2 == 0:
								draw_rect(Rect2(x, y, step / 2.0, step / 2.0), c)
						"cross":
							draw_rect(Rect2(x - 1, y, 3, 1), c)
							draw_rect(Rect2(x, y - 1, 1, 3), c)
						"rings":
							draw_arc(Vector2(x + 1, y + 1), 1.5, 0, TAU, 6, c)
						"waves":
							draw_rect(Rect2(x, y + (1 if int(x) % 4 < 2 else 0), 2, 1), c)
					x += step
				y += step
				row += 1


func _clipped_line(r: Rect2, a: Vector2, b: Vector2, c: Color) -> void:
	var steps := int(a.distance_to(b))
	for i in steps:
		var p := a.lerp(b, float(i) / float(maxi(steps, 1)))
		if r.has_point(p):
			draw_rect(Rect2(p.floor(), Vector2.ONE), c)

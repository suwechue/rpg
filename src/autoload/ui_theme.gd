## Builds the one Theme every screen uses (ROADMAP M11) from data/ui.json
## (colors, font sizes, Vector colors) and the skin images in assets/ui/skin/
## (asset ids: 9-slice panels, buttons, bars, card frames, cursor, font).
## Screens never style themselves: they use the theme, its type variations
## (TimelineParty, TimelineEnemy, TimelineCurrent, OutlinedLabel, Tooltip) or
## the color names here. `rebuild()` re-reads everything (F1 > Art reload).
extends Node

const SETTINGS := "user://settings.cfg"

var FONT_SIZE := 9
var TITLE_SIZE := 18

var BG := Color.BLACK
var BG_LIGHT := Color.BLACK
var BORDER := Color.BLACK
var TEXT := Color.WHITE
var DIM := Color.GRAY
var ACCENT := Color.WHITE
var GOOD := Color.GREEN
var BAD := Color.RED
var LABEL := Color.WHITE

var colorblind := false
## P2 1.2: true after keyboard or controller input (focus outlines show), false
## after mouse input (clicks release focus, no outline lingers).
var nav_mode := false
var _role_fonts: Dictionary = {}
var font: Font
var theme: Theme


func _ready() -> void:
	# Tooltips never wrap on their own, so long ones ran off the screen: wrap
	# each control's tooltip just before it can show (user report, Oct 28).
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is Control and not (n as Control).mouse_entered.is_connected(_wrap_tooltip):
			(n as Control).mouse_entered.connect(_wrap_tooltip.bind(n)))
	theme = ThemeDB.get_project_theme()
	if theme == null:
		theme = Theme.new()
		get_tree().root.theme = theme
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		colorblind = bool(cfg.get_value("ui", "colorblind", false))
	else:
		colorblind = bool(_ui().get("colorblind", false))
	rebuild()
	Assets.reloaded.connect(rebuild)


func _wrap_tooltip(c: Control) -> void:
	if is_instance_valid(c) and c.tooltip_text.length() > int(_ui().get("tooltipChars", 56)):
		c.tooltip_text = wrap_text(c.tooltip_text, int(_ui().get("tooltipChars", 56)))


## Break text into lines of at most `width` characters at spaces, keeping its
## own line breaks.
static func wrap_text(text: String, width: int) -> String:
	var out: Array = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			if line != "" and line.length() + 1 + word.length() > width:
				out.append(line)
				line = word
			else:
				line = word if line == "" else line + " " + word
		out.append(line)
	return "\n".join(PackedStringArray(out))


func _ui() -> Dictionary:
	return DataDB.table("ui")


func color(name: String, fallback: Color = Color.MAGENTA) -> Color:
	var c: Dictionary = _ui().get("colors", {})
	return Color(str(c[name])) if c.has(name) else fallback


func rebuild() -> void:
	FONT_SIZE = int(_ui().get("fontSize", FONT_SIZE))
	TITLE_SIZE = int(_ui().get("titleSize", TITLE_SIZE))
	BG = color("bg")
	BG_LIGHT = color("bgLight")
	BORDER = color("border")
	TEXT = color("text")
	DIM = color("dim")
	ACCENT = color("accent")
	GOOD = color("good")
	BAD = color("bad")
	LABEL = color("label")
	font = theme.default_font
	var base_font := Assets.font(Assets.role("font"))
	if font is FontVariation and base_font != null:
		(font as FontVariation).base_font = base_font
	elif font == null:
		var v := FontVariation.new()
		v.base_font = base_font
		v.spacing_space = 2
		font = v
	_fill_theme(theme)
	_set_cursor()


func set_colorblind(on: bool) -> void:
	colorblind = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("ui", "colorblind", on)
	cfg.save(SETTINGS)


## The font for a role (ui, dialogue, title, damage) from data/ui.json "fonts",
## as a variation with the UI's wider spaces.
func font_for(role: String) -> Font:
	var rec: Dictionary = _ui().get("fonts", {}).get(role, {})
	var base := Assets.font(str(rec.get("id", "")))
	if base == null:
		return font
	if _role_fonts.has(role) and (_role_fonts[role] as FontVariation).base_font == base:
		return _role_fonts[role]
	var v := FontVariation.new()
	v.base_font = base
	v.spacing_space = 2
	_role_fonts[role] = v
	return v


func size_for(role: String) -> int:
	return int(_ui().get("fonts", {}).get(role, {}).get("size", FONT_SIZE))


## A label in a role's font and size.
func role_label(text: String, role: String, color_value: Variant = null) -> Label:
	var l := label(text, color_value)
	l.add_theme_font_override("font", font_for(role))
	if size_for(role) != FONT_SIZE:
		l.add_theme_font_size_override("font_size", size_for(role))
	return l


## A Vector's color (the colorblind-safe palette when that option is on).
func vector_color(axis: String) -> Color:
	var key := "vectorColorsColorblind" if colorblind else "vectorColors"
	return Color(str(_ui().get(key, {}).get(axis, "#888888")))


func vector_pattern(axis: String) -> String:
	return str(_ui().get("vectorPatterns", {}).get(axis, "none"))


func status_info(id: String) -> Dictionary:
	return _ui().get("statuses", {}).get(id, {})


func skin(key: String) -> Variant:
	return _ui().get("skin", {}).get(key, {})


## A 9-slice style from a skin entry { "id", "margin", "padding": [x, y] }.
func skin_box(entry: Dictionary, id_key: String = "id") -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Assets.texture(str(entry.get(id_key, "")))
	var m := float(entry.get("margin", 4))
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	var pad: Array = entry.get("padding", [m, m])
	sb.content_margin_left = float(pad[0])
	sb.content_margin_right = float(pad[0])
	sb.content_margin_top = float(pad[1])
	sb.content_margin_bottom = float(pad[1])
	return sb


func _fill_theme(t: Theme) -> void:
	t.default_font = font
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 1)
	var panel := skin_box(skin("panel"))
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	var btn: Dictionary = skin("button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", skin_box(btn, state))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_focus_color", "Button", ACCENT)
	var tip := skin_box(skin("tooltip"))
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", FONT_SIZE)
	t.set_type_variation("Tooltip", "PanelContainer")
	t.set_stylebox("panel", "Tooltip", tip)
	var field := skin_box(skin("field"))
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field)
	t.set_stylebox("background", "ProgressBar", skin_box(skin("barBg")))
	var fill := skin_box(skin("barFill"))
	fill.modulate_color = GOOD
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_constant("separation", "VBoxContainer", 2)
	t.set_constant("separation", "HBoxContainer", 3)
	# Combat timeline chips: the skin panel tinted by team; the current unit gets the accent.
	for v in [["TimelineParty", color("party")], ["TimelineEnemy", color("enemy")], ["TimelineCurrent", ACCENT]]:
		var sb := skin_box(skin("panel"))
		sb.modulate_color = v[1]
		sb.content_margin_left = 2
		sb.content_margin_right = 2
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		t.set_type_variation(v[0], "PanelContainer")
		t.set_stylebox("panel", v[0], sb)
	# World text (prompts, name tags, floating numbers): outlined so it reads on any map.
	t.set_type_variation("OutlinedLabel", "Label")
	t.set_color("font_outline_color", "OutlinedLabel", color("outline"))
	t.set_constant("outline_size", "OutlinedLabel", 3)
	t.set_type_variation("SelectedButton", "Button")
	t.set_color("font_color", "SelectedButton", ACCENT)
	# Selected (P2 1.2): a filled background, not an outline, so it never looks like focus.
	var sel := skin_box(btn, "pressed")
	sel.modulate_color = ACCENT
	for st in ["normal", "hover", "focus"]:
		t.set_stylebox(st, "SelectedButton", sel)
	if not nav_mode:
		t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# Effects strip borders (P2 2.1): risky red, helpful green, overrides amber.
	for v in [["EffectRisky", BAD], ["EffectGood", GOOD], ["EffectWarning", color("warning", Color("e8a33d"))]]:
		var eb := skin_box(skin("panel"))
		eb.modulate_color = v[1]
		t.set_type_variation(v[0], "Button")
		for st in ["normal", "hover", "pressed", "focus"]:
			t.set_stylebox(st, v[0], eb)
	t.set_type_variation("CompactBox", "HBoxContainer")
	t.set_constant("separation", "CompactBox", 1)
	t.set_type_variation("CompactGrid", "GridContainer")
	t.set_constant("h_separation", "CompactGrid", 1)
	t.set_constant("v_separation", "CompactGrid", 1)


func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(null)


func _set_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tex := Assets.texture(str(skin("cursor")))
	var img := tex.get_image()
	var scale := maxi(1, int(DataDB.table("display").get("windowScale", 1)))
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img))


## Small helpers for code-built UI. `color` defaults to the text color.
func label(text: String, color_value: Variant = null, size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	if color_value != null:
		l.add_theme_color_override("font_color", color_value)
	if size > 0 and size != FONT_SIZE:
		l.add_theme_font_size_override("font_size", size)
	return l


## A label for the game world (prompts, name tags): outlined.
func world_label(text: String, color_value: Variant = null, role: String = "ui") -> Label:
	var l := label(text, color_value) if role == "ui" else role_label(text, role, color_value)
	l.theme_type_variation = "OutlinedLabel"
	return l


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0):
		if nav_mode:
			nav_mode = false
			_apply_focus_style()
		if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
			_release_focus.call_deferred()
	elif (event is InputEventKey and event.pressed) or event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		if not nav_mode:
			nav_mode = true
			_apply_focus_style()


func _release_focus() -> void:
	if not nav_mode and get_viewport() != null:
		get_viewport().gui_release_focus()


## Focus outline only in nav mode; the empty style in mouse mode.
func _apply_focus_style() -> void:
	if theme == null:
		return
	theme.set_stylebox("focus", "Button", skin_box(skin("button"), "focus") if nav_mode else StyleBoxEmpty.new())


func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: Audio.play_sfx("click"))
	b.pressed.connect(callback)
	b.focus_mode = Control.FOCUS_ALL
	return b

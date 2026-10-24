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
var font: Font
var theme: Theme


func _ready() -> void:
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
	t.set_type_variation("CompactBox", "HBoxContainer")
	t.set_constant("separation", "CompactBox", 1)
	t.set_type_variation("CompactGrid", "GridContainer")
	t.set_constant("h_separation", "CompactGrid", 1)
	t.set_constant("v_separation", "CompactGrid", 1)


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
func world_label(text: String, color_value: Variant = null) -> Label:
	var l := label(text, color_value)
	l.theme_type_variation = "OutlinedLabel"
	return l


func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: Audio.play_sfx("click"))
	b.pressed.connect(callback)
	b.focus_mode = Control.FOCUS_ALL
	return b

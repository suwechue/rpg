## Fills in the project theme (assets/ui/theme.tres: the pixel font at its
## native 9px, 2048/227.5 units per pixel, with wider spaces) with flat dark
## panels and button styles, in code so it is easy to read.
extends Node

const FONT_PATH := "res://assets/packs/ninja_adventure/Ui/Font/NormalFont.ttf"
const FONT_SIZE := 9
const TITLE_SIZE := 18

const BG := Color("141824ee")
const BG_LIGHT := Color("262c40")
const BORDER := Color("5a6488")
const TEXT := Color("e8e6d8")
const DIM := Color("8c8fa3")
const ACCENT := Color("ffd966")
const GOOD := Color("8fd694")
const BAD := Color("e8746a")

var font: Font
var theme: Theme


func _ready() -> void:
	theme = ThemeDB.get_project_theme()
	if theme == null:
		theme = Theme.new()
		get_tree().root.theme = theme
	font = theme.default_font
	if font == null:
		var v := FontVariation.new()
		v.base_font = load(FONT_PATH) as Font
		v.spacing_space = 2
		font = v
	_fill_theme(theme)


func _fill_theme(t: Theme) -> void:
	t.default_font = font
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 1)
	var panel := box(BG, BORDER)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var bg := BG_LIGHT
		var border := BORDER
		match state:
			"hover":
				bg = BG_LIGHT.lightened(0.15)
				border = ACCENT
			"pressed":
				bg = BG_LIGHT.darkened(0.2)
				border = ACCENT
			"disabled":
				bg = BG_LIGHT.darkened(0.4)
			"focus":
				bg = Color(0, 0, 0, 0)
				border = ACCENT
		var sb := box(bg, border)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_stylebox("panel", "TooltipPanel", box(BG, ACCENT))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", FONT_SIZE)
	t.set_stylebox("normal", "LineEdit", box(BG_LIGHT, BORDER))
	t.set_stylebox("background", "ProgressBar", box(BG_LIGHT, BORDER))
	t.set_stylebox("fill", "ProgressBar", box(GOOD, GOOD))
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_constant("separation", "VBoxContainer", 2)
	t.set_constant("separation", "HBoxContainer", 3)


func box(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


## Small helpers for code-built UI.
func label(text: String, color: Color = TEXT, size: int = FONT_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if size != FONT_SIZE:
		l.add_theme_font_size_override("font_size", size)
	return l


func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	b.focus_mode = Control.FOCUS_ALL
	return b

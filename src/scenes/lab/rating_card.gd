## The rating card after every Lab fight (docs/COMBAT_LAB.md Part 1). Every answer
## is optional and the card can be skipped. Finishes with a Dictionary of answers.
extends "res://src/scenes/ui/modal.gd"

var answers: Dictionary = {}
var _note: LineEdit


func _ready() -> void:
	build(Strings.t("lab.rate_title"), 340)
	_scale("fun", Strings.t("lab.rate_fun"))
	_scale("options", Strings.t("lab.rate_options"))
	var clever := row()
	clever.add_child(UiTheme.label(Strings.t("lab.rate_clever")))
	for pair in [[Strings.t("lab.yes"), true], [Strings.t("lab.no"), false]]:
		var b := UiTheme.button(str(pair[0]), func() -> void: pass)
		b.set_meta("value", pair[1])
		b.pressed.connect(func() -> void:
			answers["clever"] = pair[1]
			_mark(clever, pair[1]))
		clever.add_child(b)
	text(Strings.t("lab.rate_note"))
	_note = LineEdit.new()
	_note.custom_minimum_size = Vector2(panel.custom_minimum_size.x - 2 * UiTheme.FONT_SIZE, 0)
	body.add_child(_note)
	add_button(Strings.t("lab.rate_save"), func() -> void:
		if _note.text.strip_edges() != "":
			answers["note"] = _note.text.strip_edges()
		finish(answers))
	add_button(Strings.t("lab.rate_skip"), func() -> void: finish({}))
	focus_first()


func _scale(key: String, question: String) -> void:
	text(question)
	var r := row()
	for i in range(1, 6):
		var n := i
		var b := UiTheme.button(str(n), func() -> void: pass)
		b.set_meta("value", n)
		b.pressed.connect(func() -> void:
			answers[key] = n
			_mark(r, n))
		r.add_child(b)


func _mark(r: Control, value: Variant) -> void:
	for c in r.get_children():
		if c is Button:
			(c as Button).theme_type_variation = "SelectedButton" if c.get_meta("value") == value else ""

## TL Part 7: the town pause menu (P): resume, the goal tracker, the party,
## options, save.
extends "res://src/scenes/ui/modal.gd"


func _ready() -> void:
	build(Strings.t("pause.title"), 220)
	add_button(Strings.t("pause.resume"), func() -> void: finish("resume"))
	add_button(Strings.t("goals.title"), func() -> void: finish("goals"))
	add_button(Strings.t("pause.party"), func() -> void: finish("party"))
	add_button(Strings.t("pause.options"), func() -> void: finish("options"))
	add_button(Strings.t("pause.save"), func() -> void: finish("save"))
	focus_first()

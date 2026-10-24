## A generic event: text, then choices (greyed out with a hint when their
## conditions fail), then the result. Event shape:
## { "title", "text", "effects", "choices": [{ "label", "cond", "lockedHint",
##   "effects", "result" }], "speaker" }
extends "res://src/scenes/ui/modal.gd"

const StoryRules := preload("res://src/core/story/story.gd")

var event: Dictionary = {}
var extra_ctx: Dictionary = {}


func _ready() -> void:
	build(str(event.get("title", "")), 380)
	var speaker := str(event.get("speaker", ""))
	if speaker != "":
		title_label.text = "%s%s" % [title_label.text + "  " if title_label.text != "" else "", speaker]
	text(str(event.get("text", "")))
	var choices: Array = event.get("choices", [])
	if choices.is_empty():
		add_button("Continue", func() -> void: _choose({ "effects": event.get("effects", {}), "result": event.get("result", "") }))
	else:
		for ch in choices:
			var ok := GameState.conditions_met(ch.get("cond", {}))
			var c: Dictionary = ch
			var label := str(ch.get("label", "..."))
			if not ok and ch.has("lockedHint"):
				label += "  (%s)" % ch["lockedHint"]
			add_button(label, func() -> void: _choose(c), not ok)
	focus_first()


func _choose(picked: Dictionary) -> void:
	var ch := StoryRules.resolve_choice(DataDB.all(), GameState.run, picked, Rng.stream("dialogue"))
	clear_body()
	if bool(ch.get("wasMisheard", false)):
		var quip := Narrator.line("misheard")
		if quip != "":
			text("(%s)" % quip, UiTheme.DIM)
	var lines := GameState.apply_effects(ch.get("effects", {}), extra_ctx)
	if str(ch.get("result", "")) != "":
		text(str(ch["result"]))
	for line in lines:
		text(str(line), UiTheme.DIM)
	add_button("Continue", func() -> void: finish(ch))
	focus_first()

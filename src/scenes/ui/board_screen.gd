## The mystery board (ROADMAP M18): your clues by category; pick two and link
## them. A matching pair forms a deduction that opens new story choices.
extends "res://src/scenes/ui/modal.gd"

const Mystery := preload("res://src/core/story/mystery.gd")

var _picked: Array = []


func _ready() -> void:
	build(Strings.t("board.title"), 440)
	_refresh()


func _refresh() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var have: Array = GameState.run.get("clues", [])
	if have.is_empty():
		text(Strings.t("board.none"), UiTheme.DIM)
	else:
		text(Strings.t("board.pick"), UiTheme.DIM)
	for id in have:
		var cid := str(id)
		var c := Mystery.clue(db, cid)
		var b := UiTheme.button("%s: %s" % [str(c.get("category", "")), str(c.get("text", cid))], func() -> void:
			if _picked.has(cid):
				_picked.erase(cid)
			elif _picked.size() < 2:
				_picked.append(cid)
			_refresh())
		b.theme_type_variation = "SelectedButton" if _picked.has(cid) else ""
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(panel.custom_minimum_size.x - 2 * UiTheme.FONT_SIZE, 0)
		body.add_child(b)
	add_button(Strings.t("board.connect"), func() -> void:
		var before: int = GameState.run.get("deductions", []).size()
		var d := Mystery.connect_clues(db, GameState.run, str(_picked[0]), str(_picked[1]))
		if not d.is_empty():
			Journal.note("deductions", str(d["id"]))
		_picked.clear()
		Narrator.say(Strings.t("board.deduced") % str(d["text"]) if not d.is_empty() else Strings.t("board.no_link"))
		# A new deduction earns a rare card pick (user request, Oct 29).
		if GameState.run.get("deductions", []).size() > before:
			visible = false
			await Flow.card_reward("deduction")
			visible = true
		_refresh(), _picked.size() != 2)
	var done: Array = GameState.run.get("deductions", [])
	if not done.is_empty():
		text(Strings.t("board.deductions"), UiTheme.ACCENT)
		for d in Mystery.cfg(db).get("deductions", []):
			if done.has(str(d["id"])):
				text("- " + str(d["text"]), UiTheme.GOOD)
	add_button(Strings.t("phone.close"), func() -> void: finish(null))
	focus_first()

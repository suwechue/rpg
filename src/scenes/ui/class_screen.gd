## A class period: attend (gains + a class event) or skip (a free 2 AP part).
extends "res://src/scenes/ui/modal.gd"

const School := preload("res://src/core/run/school.gd")
const Fx := preload("res://src/core/run/effects.gd")

var period := 1
var cls: Dictionary = {}
var _event: Dictionary = {}
var _ctx: Dictionary = {}


func _ready() -> void:
	var db: Dictionary = DataDB.all()
	period = int(Calendar.current_part().get("period", 1))
	cls = School.class_rec(db, str(GameState.schedule[period - 1]))
	build("Period %d: %s" % [period, cls.get("name", "?")], 380)
	var prof := str(db.get("school_classes", {}).get("professors", {}).get(str(cls.get("professor", "")), ""))
	text("%s, with %s. %s" % [cls.get("name", ""), prof, cls.get("blurb", "")], UiTheme.DIM)
	var grade := float(GameState.run["grades"].get(str(cls.get("professor", "")), 0.0))
	text("Grade with %s: %d. Skips this week: %d." % [prof, roundi(grade), int(GameState.run.get("skips_week", 0))], UiTheme.DIM)
	add_button("Attend (takes the whole period)", _attend)
	add_button("Skip (free 2 AP part, Grade drops)", _skip)
	focus_first()
	Audio.play_music("school")


func _attend() -> void:
	var db: Dictionary = DataDB.all()
	var report := School.attend(db, GameState.run, period, Rng.stream("events"), GameState.ctx())
	_ctx = report["ctx"]
	_ctx["teacher"] = str(db.get("school_classes", {}).get("professors", {}).get(str(cls.get("professor", "")), ""))
	_ctx["class_name"] = str(cls.get("name", ""))
	_event = report["event"]
	if bool(_event.get("partner", false)):
		var partner := School.pick_partner(db, str(cls["id"]), Rng.stream("events"))
		_ctx["partner"] = partner
		_ctx["partner_name"] = str(db.get("npcs/" + partner, {}).get("name", partner.capitalize()))
	clear_body()
	for line in report["lines"]:
		text(str(line), UiTheme.GOOD if str(line).ends_with("!") else UiTheme.DIM)
	EventBus.stats_changed.emit("player")
	if _event.is_empty():
		add_button("Continue", func() -> void: finish("attended"))
		focus_first()
		return
	text(School.fill(str(_event.get("text", "")), _ctx))
	var choices: Array = _event.get("choices", [])
	if choices.is_empty():
		add_button("Continue", func() -> void: _resolve(-1))
	else:
		for i in choices.size():
			var ch: Dictionary = choices[i]
			var ok := Fx.conditions_met(db, GameState.run, ch.get("cond", {}), GameState.ctx())
			var idx := i
			add_button(School.fill(str(ch.get("label", "...")), _ctx), func() -> void: _resolve(idx), not ok, str(ch.get("lockedHint", "")))
	focus_first()


func _resolve(choice: int) -> void:
	var r := School.resolve_event(DataDB.all(), GameState.run, _event, choice, Rng.stream("events"), _ctx)
	clear_body()
	for line in r["lines"]:
		text(School.fill(str(line), _ctx))
	EventBus.stats_changed.emit("player")
	add_button("Continue", func() -> void: finish("attended"))
	focus_first()


func _skip() -> void:
	var lines := School.skip(DataDB.all(), GameState.run, period)
	clear_body()
	for line in lines:
		text(str(line))
	text("The period is yours: 2 AP to spend however you like.", UiTheme.DIM)
	add_button("Continue", func() -> void: finish("skipped"))
	focus_first()

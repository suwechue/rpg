## The spark quiz (docs/VECTORS_DEMO.md Part 3): the narrator's questions,
## then the reveal. Once the Journal unlocks it, the player may pick a spark
## directly instead. Finishes with the spark id.
extends "res://src/scenes/ui/modal.gd"

const Spark := preload("res://src/core/progression/spark.gd")

var allow_choose := false
var _answers: Array = []


func _ready() -> void:
	build(Strings.t("spark.title"), 400)
	if allow_choose:
		_choose()
	else:
		_question()


func _choose() -> void:
	clear_body()
	text(Strings.t("spark.choose_text"), UiTheme.DIM)
	add_button(Strings.t("spark.take_quiz"), _question)
	for s in Spark.all(DataDB.all()):
		var sid := str(s["id"])
		var b := add_button(str(s.get("name", sid)), func() -> void: _reveal(sid))
		b.add_theme_color_override("font_color", UiTheme.vector_color(sid))
	focus_first()


func _question() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var qs: Array = Spark.quiz(db).get("questions", [])
	if _answers.size() >= qs.size():
		_reveal(Spark.result(db, _answers))
		return
	if _answers.is_empty():
		text(str(Spark.quiz(db).get("intro", "")), UiTheme.DIM)
	var q: Dictionary = qs[_answers.size()]
	text(Strings.t("spark.question") % [_answers.size() + 1, qs.size()], UiTheme.DIM)
	text(str(q.get("text", "")), UiTheme.ACCENT)
	var opts: Array = q.get("answers", [])
	for i in opts.size():
		var idx := i
		add_button(str(opts[i].get("label", "?")), func() -> void:
			_answers.append(idx)
			Audio.event("click")
			_question())
	# Autoplay (tests) answers the first option.
	if GameState.dev_autoplay:
		_answers.append(0)
		_question.call_deferred()
		return
	focus_first()


func _reveal(spark_id: String) -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var s := Spark.find(db, spark_id)
	if Assets.has(str(s.get("art", ""))) or Assets.custom_file(str(s.get("art", ""))) != "":
		var tr := TextureRect.new()
		tr.texture = Assets.texture(str(s["art"]))
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		body.add_child(tr)
	var tr_rec := DataDB.record("traits", str(s.get("trait", "")))
	var card := preload("res://src/core/card.gd").resolve(db, str(s.get("card", "")))
	var l := text(Strings.t("spark.reveal") % [str(s.get("name", spark_id)), str(s.get("reveal", "")), str(DataDB.table("vectors").get("display", {}).get(spark_id, spark_id.capitalize())),
		str(card.get("name", s.get("card", ""))), str(tr_rec.get("name", "")), str(tr_rec.get("text", ""))])
	l.add_theme_color_override("font_color", UiTheme.vector_color(spark_id))
	Audio.event("combo_discovered")
	add_button(Strings.t("spark.continue"), func() -> void: finish(spark_id))
	if GameState.dev_autoplay:
		finish.call_deferred(spark_id)
		return
	focus_first()

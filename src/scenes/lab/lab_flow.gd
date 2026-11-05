## What happens around a Lab fight: restart buttons, the result panel, the rating
## card, saving the log line, and A/B runs (docs/COMBAT_LAB.md Part 1).
extends RefCounted

const Session := preload("res://src/core/lab/lab_session.gd")
const Rules := preload("res://src/core/combat/rules.gd")
const Setup := preload("res://src/core/lab/lab_setup.gd")
const FightLog := preload("res://src/core/lab/fight_log.gd")
const RatingCard := preload("res://src/scenes/lab/rating_card.gd")
const LabScreen := preload("res://src/scenes/lab/lab.gd")
const Modal := preload("res://src/scenes/ui/modal.gd")
const Extras := preload("res://src/core/combat/extras.gd")
const CardRules := preload("res://src/core/card.gd")


static func restart() -> void:
	LabScreen.start_fight()


static func restart_other_preset() -> void:
	var m := Modal.new()
	m.build(Strings.t("lab.pick_preset"), 260)
	for p in Rules.presets(DataDB.all()):
		var pid := str(p["id"])
		m.add_button(str(p.get("name", pid)), func() -> void: m.finish(pid))
	m.add_button(Strings.t("lab.back"), func() -> void: m.finish(""))
	var pick: Variant = await Flow.show_modal(m)
	if str(pick) != "":
		Session.reset_ab()
		Session.preset_id = str(pick)
		Session.overrides = {}
		restart()


## The fight ended: rate it, save the line, then move on.
static func finished(scene: Node, state: Object, summary: Dictionary) -> void:
	var rating: Dictionary = {}
	if not GameState.dev_autoplay:
		var r: Variant = await Flow.show_modal(RatingCard.new())
		if r is Dictionary:
			rating = r
	FightLog.append(state.lab_log.line(str(summary["result"]), int(summary["rounds"]), rating))
	if not Session.ab.is_empty():
		_next_ab(state)
		return
	if GameState.dev_autoplay:
		LabScreen.exit_lab()
		return
	_result_panel(scene, state, summary)


## A board relic drops after a win (the storyRelics lever).
static func _drop_relic(m: Modal) -> void:
	var pool: Array = DataDB.table("lab/board_relics").get("relics", []).filter(func(rec: Dictionary) -> bool: return not Session.relics.has(str(rec["id"])))
	if pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = Session.relics.size() + 7
	var rec: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	Session.relics.append(str(rec["id"]))
	m.text(Strings.t("lab.relic") % [rec["name"], rec["text"]], UiTheme.ACCENT)


## After a win: pick a new card, a gear upgrade, or remove a card. Changes the Lab party's decks.
static func _post_fight_choice() -> void:
	var db: Dictionary = DataDB.all()
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	var m := Modal.new()
	m.build(Strings.t("lab.choice"), 340)
	for id in Extras.post_fight_cards(db, rng):
		var cid := str(id)
		var c := CardRules.resolve(db, cid)
		m.add_button(Strings.t("lab.choice_card") % str(c.get("name", cid)), func() -> void: m.finish(cid), false, CardRules.describe(db, c))
	m.add_button(Strings.t("lab.choice_gear"), func() -> void: m.finish("gear"))
	m.add_button(Strings.t("lab.choice_remove"), func() -> void: m.finish("remove"))
	var r: Variant = await Flow.show_modal(m)
	if Session.picks.is_empty():
		Session.picks = Setup.picks_for(db, Setup.fight(db, Session.fight_id)).duplicate(true)
	var pick: Dictionary = Session.picks[0]
	var rules: RefCounted = Rules.build(db, Session.preset_id, Session.overrides)
	var cls: Dictionary = db.get("classes", {}).get("classes", []).filter(func(c: Dictionary) -> bool: return str(c["id"]) == str(pick.get("class", "")))[0]
	var deck: Array = pick.get("deck", Setup.deck_for(db, pick, rules, { "deck": cls.get("starterDeck", []) }))
	match str(r):
		"gear":
			# The Lab has no gear of its own, so this stands in as a level.
			pick["level"] = int(pick.get("level", 1)) + 1
		"remove":
			if deck.size() > 1:
				deck.pop_back()
				pick["deck"] = deck
		"":
			pass
		_:
			deck.append(str(r))
			pick["deck"] = deck


static func _next_ab(state: Object) -> void:
	if int(Session.ab["stage"]) == 0:
		Session.ab["stage"] = 1
		restart()
		return
	var a := str(Session.ab["a"])
	var b := str(Session.ab["b"])
	var pick: Variant = ""
	if not GameState.dev_autoplay:
		var m := Modal.new()
		m.build(Strings.t("lab.ab_which"), 260)
		m.add_button(Strings.t("lab.ab_a") % a, func() -> void: m.finish(a))
		m.add_button(Strings.t("lab.ab_b") % b, func() -> void: m.finish(b))
		m.add_button(Strings.t("lab.ab_same"), func() -> void: m.finish(""))
		pick = await Flow.show_modal(m)
	FightLog.append({ "kind": "ab", "at": Time.get_datetime_string_from_system(), "fight": str(Session.ab["fight"]), "a": a, "b": b, "pick": str(pick), "seed": int(state.lab_log.seed_value) })
	Session.reset_ab()
	SceneRouter.goto(LabScreen.SCENE)


static func _result_panel(scene: Node, state: Object, summary: Dictionary) -> void:
	var m := Modal.new()
	var key := "lab.result_" + str(summary["result"])
	m.build(Strings.t(key), 260)
	m.text(Strings.t("lab.result_line") % [int(summary["rounds"]), int(state.lab_log.board_kills), int(state.lab_log.combos)])
	for b in summary.get("bonus", []):
		m.text(("%s %s" % [Strings.t("lab.bonus_done") if bool(b["done"]) else Strings.t("lab.bonus_missed"), b["text"]]), UiTheme.GOOD if bool(b["done"]) else UiTheme.DIM)
	if str(summary["result"]) == "win" and state.rules.flag("storyRelics"):
		_drop_relic(m)
	if str(summary["result"]) == "win" and state.rules.flag("postFightChoice"):
		m.add_button(Strings.t("lab.choice"), func() -> void: m.finish("choice"))
	m.add_button(Strings.t("lab.again"), func() -> void: m.finish("again"))
	m.add_button(Strings.t("lab.other_preset"), func() -> void: m.finish("other"))
	m.add_button(Strings.t("lab.back_to_lab"), func() -> void: m.finish("lab"))
	var r: Variant = await Flow.show_modal(m)
	if not is_instance_valid(scene):
		return
	match str(r):
		"choice":
			await _post_fight_choice()
			restart()
		"again":
			restart()
		"other":
			restart_other_preset()
		_:
			SceneRouter.goto(LabScreen.SCENE)

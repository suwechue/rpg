## Runs the day: when a part starts, shows the screens it needs (schedule,
## detention, class, the dungeon, night) over whatever scene is open, and owns
## the HUD for free parts. Free-roam scenes (the town) call begin() once and
## set_hud(true). Scenes check is_busy() before taking movement input.
extends CanvasLayer

const ScheduleScreen := preload("res://src/scenes/ui/schedule_screen.gd")
const ClassScreen := preload("res://src/scenes/ui/class_screen.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Exams := preload("res://src/core/run/exams.gd")
const Clubs := preload("res://src/core/run/clubs.gd")
const Phone := preload("res://src/core/social/phone.gd")
const Truancy := preload("res://src/core/town/truancy.gd")
const NightScreen := preload("res://src/scenes/ui/night_screen.gd")
const EventScreen := preload("res://src/scenes/ui/event_screen.gd")
const Hud := preload("res://src/scenes/ui/hud.gd")
const StoryRules := preload("res://src/core/story/story.gd")
const STORY_SCENE := "res://src/scenes/story/story_scene.tscn"
const TITLE_SCENE := "res://src/scenes/title/title.tscn"

const DUNGEON_SCENE := "res://src/scenes/dungeon/dungeon.tscn"

var _queue: Array = []
var _busy := false
var _hud: Control
var _active := false
var night_hooks: Array = []     # Callables returning [{ "label", "run": Callable }]
var night_line_hooks: Array = []  # Callables returning [String]
var part_hooks: Array = []      # Callables(screens: Array) -> Array, can add screens
var custom_screens: Dictionary = {}  # screen name -> Callable (awaitable)


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud = Hud.new()
	_hud.visible = false
	add_child(_hud)
	EventBus.part_started.connect(_on_part_started)
	EventBus.run_ended.connect(_on_run_ended)


func set_hud(on: bool) -> void:
	_hud.visible = on


func is_busy() -> bool:
	return _busy or DebugMenu.is_open()


## Start running the calendar from the current part (after a new run or a load).
func begin() -> void:
	_active = true
	_queue.clear()
	_busy = false
	for c in get_children():
		if c != _hud and c.has_signal("closed"):
			c.queue_free()
	_on_part_started()


func _on_part_started() -> void:
	if not _active or not GameState.has_run() or _busy:
		return
	var screens := GameState.part_screens()
	for id in StoryRules.due(DataDB.all(), GameState.run, GameState.ctx(), true):
		screens.push_front("story:" + str(id))
	# M19: Monday mornings announce what's new this week; the day's start is
	# remembered for Narrator's Mercy.
	if Calendar.day_name() == "mon" and Calendar.part_id() == "before_school" and Calendar.week() > 1 and not GameState.flag("unlocks_told_%d" % Calendar.week()):
		GameState.set_flag("unlocks_told_%d" % Calendar.week())
		var news := str(DataDB.table("unlocks").get("weeks", {}).get(str(Calendar.week()), ""))
		if news != "":
			Narrator.say(news)
	if Calendar.part_id() in ["before_school", "morning"]:
		GameState.day_snapshot = GameState.to_dict().duplicate(true)
	# TL Part 2: the attendance streak, the curfew and the allowance.
	if Calendar.day_name() == "mon" and Calendar.part_id() == "before_school" and str(GameState.run.get("lastStreak", "")) != "":
		Narrator.say(Strings.t("truancy.streak") % str(GameState.run["lastStreak"]).to_upper())
		GameState.run["lastStreak"] = ""
	if Calendar.part_id() == "night":
		var cd := Truancy.night_ap_delta(DataDB.all(), GameState.run)
		if cd != 0:
			Calendar.set_ap(maxi(0, Calendar.ap() + cd))
			Narrator.say(Strings.t("truancy.curfew"))
	if Calendar.day_name() == "sat" and Calendar.part_id() == "morning":
		var pay := Truancy.allowance(DataDB.all(), GameState.run)
		if pay > 0:
			GameState.money += pay
			Narrator.say(Strings.t("truancy.allowance") % pay)
	# TL Part 4: commissions the blacksmith has ready.
	if Calendar.part_id() in ["before_school", "morning"]:
		for got in preload("res://src/core/items/gear.gd").collect(GameState.run, int(GameState.run.get("day_count", 0))):
			Narrator.say(Strings.t("smith.ready") % str(DataDB.record("items", str(got)).get("name", got)))
	# TL Part 3: the morning paper.
	if Calendar.part_id() == "before_school":
		screens.push_front("paper")
	# M18: friendship scenes waiting from Bond gains, tonight's texts, and today's plans.
	for sid in GameState.run.get("pendingFriendScenes", []):
		screens.push_front("friend:" + str(sid))
	GameState.run["pendingFriendScenes"] = []
	if Calendar.part_id() == "night":
		var new_texts := Phone.night_texts(DataDB.all(), GameState.run, int(GameState.run.get("day_count", 0)), Rng.stream("npc"))
		if not new_texts.is_empty():
			Narrator.say(Strings.t("phone.new_texts") % new_texts.size())
	if Calendar.part_id() == "after_school" and Phone.invite_today(GameState.run, int(GameState.run.get("day_count", 0))) != "":
		screens.push_front("invite:" + Phone.invite_today(GameState.run, int(GameState.run.get("day_count", 0))))
	# M16: a club meeting takes the After School part on its days.
	if Calendar.part_id() == "after_school" and not Calendar.is_weekend():
		var club := Clubs.meeting_today(DataDB.all(), GameState.run, Calendar.day_name())
		if club != "":
			screens.append("club:" + club)
	if GameState.player.has("pendingClassChange") and not screens.has("class") and not screens.has("dungeon"):
		screens.push_front("class_change")
	if not GameState.player.get("pendingPerks", []).is_empty() and not screens.has("dungeon"):
		screens.push_front("perk_pick")
	if not GameState.player.get("pendingTechniques", []).is_empty() and not screens.has("dungeon"):
		screens.push_front("technique_pick")
	if Calendar.day_name() == "sun" and Calendar.part_id() == "weekend_evening":
		var tease := str(preload("res://src/core/dungeon/signature.gd").week_rec(DataDB.all(), Calendar.week()).get("sundayTease", ""))
		if tease != "":
			Narrator.say(tease)
	for hook in part_hooks:
		screens = hook.call(screens)
	_queue = screens
	_hud.refresh()
	_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		_hud.refresh()
		return
	_busy = true
	var screen := str(_queue.pop_front())
	match screen:
		"schedule":
			var s := ScheduleScreen.new()
			add_child(s)
			await s.closed
			_next()
		"detention":
			await _detention()
			_next()
		"class":
			var s := ClassScreen.new()
			add_child(s)
			var r: Variant = await s.closed
			if str(r) == "skipped":
				Calendar.set_ap(int(DataDB.table("school_classes").get("rules", {}).get("skipAp", 2)))
				# TL Part 5: skipping with a friend plays their scene.
				if GameState.run.has("skipScene"):
					var sid := str(GameState.run["skipScene"])
					GameState.run.erase("skipScene")
					await Cutscenes.play(sid, get_tree().current_scene)
					await play_pending_friend_scenes()
				_queue.clear()
				_busy = false
				_hud.refresh()
				EventBus.screen_closed.emit("class")
				return
			_busy = false
			GameState.advance_part()
		"dungeon":
			_busy = false
			enter_dungeon()
		"night":
			var s := NightScreen.new()
			add_child(s)
			await s.closed
			_busy = false
			GameState.advance_part()
		"perk_pick":
			_drop_empty_perk_levels()
			while not GameState.player.get("pendingPerks", []).is_empty():
				await show_modal(preload("res://src/scenes/ui/perk_screen.gd").new())
				_drop_empty_perk_levels()
			_next()
		"technique_pick":
			const Lv := preload("res://src/core/progression/leveling.gd")
			while not GameState.player.get("pendingTechniques", []).is_empty():
				if GameState.dev_autoplay or Lv.technique_options(DataDB.all(), GameState.player).is_empty():
					Lv.auto_techniques(DataDB.all(), GameState.player)
					break
				await show_modal(preload("res://src/scenes/ui/technique_screen.gd").new())
			_next()
		"class_change":
			await show_modal(preload("res://src/scenes/ui/class_change_screen.gd").new())
			_next()
		_ when screen.begins_with("story:"):
			await play_inline_story(screen.substr(6))
			_next()
		"paper":
			await show_event(_morning_paper())
			_next()
		_ when screen.begins_with("friend:"):
			await Cutscenes.play(screen.substr(7), get_tree().current_scene)
			_next()
		_ when screen.begins_with("invite:"):
			await _invite(screen.substr(7))
			_next()
		_ when screen.begins_with("club:"):
			await show_event(Clubs.meeting_event(DataDB.all(), GameState.run, screen.substr(5), Rng.stream("events")))
			Calendar.spend_ap(Calendar.ap(), "club")
			_next()
		_:
			var custom: Callable = custom_screens.get(screen, Callable())
			if custom.is_valid():
				await custom.call()
			_next()


## Show an event screen and wait for it. Returns the chosen choice.
func show_event(event: Dictionary, extra_ctx: Dictionary = {}) -> Variant:
	var was_busy := _busy
	_busy = true
	var s := EventScreen.new()
	s.event = event
	s.extra_ctx = extra_ctx
	add_child(s)
	var r: Variant = await s.closed
	await give_pending_cards()
	_busy = was_busy
	_hud.refresh()
	return r


## Cards granted by events, treasure and bosses: ask whose deck each goes into (P2 1.3).
func give_pending_cards() -> void:
	if not GameState.has_run():
		return
	while not GameState.run.get("pendingCards", []).is_empty():
		var cid := str(GameState.run["pendingCards"].pop_front())
		if GameState.dev_autoplay:
			var auto := preload("res://src/core/arena/arena.gd").auto_owner(DataDB.all(), GameState.run, preload("res://src/core/card.gd").resolve(DataDB.all(), cid, GameState.cards))
			if auto != "":
				(GameState.character(auto)["deck"] as Array).append(cid)
			continue
		var op := preload("res://src/scenes/ui/owner_pick.gd").new()
		op.card_id = cid
		op.active_ids = ["player"] + GameState.party_ids
		var who: Variant = await show_modal(op)
		if who != null and str(who) != "":
			var ch := GameState.character(str(who))
			if not ch.is_empty():
				(ch["deck"] as Array).append(cid)


## Show any modal (an instance of src/scenes/ui/modal.gd) and wait for it.
func show_modal(m: Control) -> Variant:
	var was_busy := _busy
	_busy = true
	add_child(m)
	if m.has_method("focus_first"):
		m.call("focus_first")
	var r: Variant = await m.closed
	_busy = was_busy
	_hud.refresh()
	return r


func _detention() -> void:
	GameState.run["detention_pending"] = false
	GameState.run["detentions"] = int(GameState.run.get("detentions", 0)) + 1
	var pick: Dictionary = {}
	for e in DataDB.table("events/detention").get("events", []):
		if GameState.conditions_met(e.get("cond", {})):
			pick = e
	if not pick.is_empty():
		await show_event(pick)
	Calendar.set_ap(0)
	Narrator.say(Strings.t("flow.detention_ate_your_afternoon_the"))


## The evening Upside-Down. Until the dungeon scene exists, it is skipped.
func enter_dungeon() -> void:
	var due := StoryRules.due(DataDB.all(), GameState.run, GameState.ctx(), false)
	if not due.is_empty():
		set_hud(false)
		GameState.run["story_pos"] = { "id": str(due[0]), "step": 0, "combat": -1 }
		SceneRouter.goto(STORY_SCENE)
		return
	if ResourceLoader.exists(DUNGEON_SCENE):
		var dcfg: Dictionary = DataDB.table("dungeon")
		if _at_woods_edge() and not GameState.roster.is_empty():
			Narrator.say(str(dcfg.get("woodsEdgeText", "")))
			await show_modal(preload("res://src/scenes/ui/party_screen.gd").new())
		elif not GameState.roster.is_empty():
			Narrator.say(str(dcfg.get("pulledInText", "")))
		set_hud(false)
		SceneRouter.goto(DUNGEON_SCENE)
		return
	Narrator.say(Strings.t("flow.the_spark_tugs_at_you"))
	GameState.advance_part()


func end_part() -> void:
	if is_busy():
		return
	GameState.advance_part()


func night_lines() -> Array:
	var out: Array = []
	for h in night_line_hooks:
		out.append_array(h.call())
	return out


func night_extras() -> Array:
	var out: Array = []
	for h in night_hooks:
		out.append_array(h.call())
	return out


func run_night_extra(e: Dictionary) -> void:
	var cb: Callable = e["run"]
	await cb.call()


## An inline story (no fights): its event steps play over the current scene.
func play_inline_story(id: String) -> void:
	var story := StoryRules.find(DataDB.all(), id)
	GameState.set_flag("story_done_" + id)
	for step in story.get("steps", []):
		match str(step.get("type", "")):
			"event":
				await show_event(step["event"])
			"narrate":
				await show_event({ "title": "", "text": str(step["text"]) })
			"cutscene":
				await Cutscenes.play(str(step["id"]), get_tree().current_scene)
			"clubFair":
				await _club_fair()
			"testWeek":
				GameState.set_flag("test_week")
			"reportCard":
				await _report_card()
			"endAct":
				await _end_act(int(step.get("act", 1)))
			"foreshadow":
				var l := Narrator.line("foreshadow")
				Narrator.say(l)
				await show_event({ "title": Strings.t("flow.the_narrator"), "text": l })


## M18: a hangout you planned by text. Going costs the hangout AP; skipping hurts.
func _invite(id: String) -> void:
	var db: Dictionary = DataDB.all()
	var who := str(db.get("npcs/" + id, {}).get("name", id))
	var ap := int(db.get("social", {}).get("hangoutAp", 2))
	var r: Variant = await show_event({ "title": Strings.t("phone.invite_title"), "text": Strings.t("phone.invite_text") % who,
		"choices": [{ "label": Strings.t("phone.invite_go") % ap, "cond": { "minAp": ap }, "effects": { "ap": -ap } },
			{ "label": Strings.t("phone.invite_skip"), "effects": { "bond": { id: -5 } } }] })
	Phone.clear_invite(GameState.run, id)
	if r is Dictionary and (r as Dictionary).get("effects", {}).has("ap"):
		var lines := preload("res://src/core/social/bonds.gd").hang_out(db, GameState.run, id, Rng.stream("npc"))
		await show_event({ "title": who, "text": "\n".join(PackedStringArray(lines)) })
		await play_pending_friend_scenes()


## M18: play any friendship scenes that Bond gains have unlocked.
func play_pending_friend_scenes() -> void:
	var pend: Array = GameState.run.get("pendingFriendScenes", [])
	GameState.run["pendingFriendScenes"] = []
	for sid in pend:
		await Cutscenes.play(str(sid), get_tree().current_scene)


## M21: End of Act 1. The run is saved with act1_complete and the title says
## so; Continue keeps it until Act 2 exists.
func _end_act(act: int) -> void:
	GameState.set_flag("act%d_complete" % act)
	SaveSystem.save_run()
	await show_event({ "title": "", "text": Strings.t("act.continue_later") })
	_active = false
	_queue.clear()
	SceneRouter.goto(TITLE_SCENE)


## TL Part 3: a short recap card at Before School.
func _morning_paper() -> Dictionary:
	var db: Dictionary = DataDB.all()
	var run: Dictionary = GameState.run
	var lines: Array = [Narrator.line("foreshadow")]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("paper:%d:%d" % [GameState.run_seed, int(run.get("day_count", 0))])
	lines.append(Strings.t("paper.favors") % preload("res://src/core/town/favors.gd").board(db, run, Calendar.week(), rng).size())
	var open: Array = []
	for l in db.get("town/locations", {}).get("locations", []):
		if l.get("hours", []) is Array and preload("res://src/core/town/locations.gd").expand_hours(db, l.get("hours", [])).has("period_2") and str(l.get("zone", "")) != "school":
			open.append(str(l.get("name", "")))
	lines.append(Strings.t("paper.open") % ", ".join(PackedStringArray(open.slice(0, 6))))
	lines.append(Strings.t("paper.rumor") % preload("res://src/core/town/crowd.gd").rumor(db, run, Calendar.week(), rng))
	return { "title": Strings.t("paper.title"), "text": "\n".join(PackedStringArray(lines)) }


## M16: the club fair. Join up to maxJoin clubs.
func _club_fair() -> void:
	var db: Dictionary = DataDB.all()
	while true:
		var m := preload("res://src/scenes/ui/modal.gd").new()
		m.build(Strings.t("club.fair_title"), 400)
		m.text(Strings.t("club.fair_text") % int(db.get("clubs", {}).get("maxJoin", 2)), UiTheme.DIM)
		var joined: Array = Clubs.joined(GameState.run)
		for c in Clubs.all(db):
			var cid := str(c["id"])
			var days := ", ".join(PackedStringArray(c.get("days", []).map(func(d: Variant) -> String: return str(d).capitalize())))
			m.add_button(Strings.t("club.join") % [str(c.get("name", cid)), Strings.t("club.days") % days, str(c.get("blurb", ""))],
				func() -> void: m.finish(cid), joined.has(cid) or joined.size() >= int(db.get("clubs", {}).get("maxJoin", 2)))
		m.add_button(Strings.t("club.done"), func() -> void: m.finish(null))
		if GameState.dev_autoplay:
			m.finish.call_deferred(null)
		var pick: Variant = await show_modal(m)
		if pick == null:
			return
		if Clubs.join(db, GameState.run, str(pick)) == "":
			Narrator.say(Strings.t("club.joined") % str(Clubs.find(db, str(pick)).get("name", pick)))


## M16: the report card at the end of test week.
func _report_card() -> void:
	var db: Dictionary = DataDB.all()
	var rep := Exams.report(db, GameState.run, GameState.schedule)
	var lines: Array = []
	for r in rep["rows"]:
		lines.append(Strings.t("exam.row") % [str(r["name"]), str(r["letter"]), int(r["score"])])
	lines.append(Strings.t("exam.gpa") % float(rep["gpa"]))
	var att := 0
	for cid in GameState.run.get("attendance", {}):
		att += int(GameState.run["attendance"][cid])
	lines.append(Strings.t("truancy.attendance") % [att, int(GameState.run.get("skips_total", 0))])
	lines.append("")
	lines.append(str(rep["parent"].get("text", "")))
	for e in Exams.report_effects(db, rep):
		Fx.apply(db, GameState.run, e["effects"], Rng.stream("events"), e["ctx"])
	GameState.run["reportCard"] = rep
	GameState.set_flag("report_card_done")
	await show_event({ "title": Strings.t("exam.title"), "text": "\n".join(PackedStringArray(lines)) })


## Permadeath: the save goes, the narrator gives the ending, back to the title.
## Narrator's Mercy (M19) rewinds to the start of the day instead.
func _on_run_ended(cause: String) -> void:
	var mode: Dictionary = DataDB.table("run_modes").get("modes", {}).get(str(GameState.run.get("runMode", "permadeath")), {})
	if bool(mode.get("rewind", false)) and cause != "demo_end" and not GameState.day_snapshot.is_empty():
		_queue.clear()
		_busy = false
		GameState.load_dict(GameState.day_snapshot.duplicate(true))
		var quips: Array = DataDB.table("run_modes").get("mercyQuips", [""])
		await show_event({ "title": Strings.t("flow.rewound_title"), "text": str(quips[Rng.stream("events").randi_range(0, quips.size() - 1)]) })
		GameState.run["rewinds"] = int(GameState.run.get("rewinds", 0)) + 1
		SaveSystem.save_run()
		SceneRouter.goto("res://src/scenes/town/town.tscn")
		return
	_active = false
	_queue.clear()
	set_hud(false)
	SaveSystem.delete_save()
	var endings: Dictionary = DataDB.table("endings").get("deaths", {})
	var text := str(endings.get(cause, endings.get("default", Strings.t("flow.and_that_was_the_end"))))
	Audio.play_music("death")
	_busy = false
	var p: Dictionary = GameState.player
	var summary := Strings.t("flow.week_level_days_survived_roster") % [Calendar.week(), Calendar.day_name().capitalize(),
		int(p.get("level", 1)), str(p.get("class", "")).capitalize(), int(GameState.run.get("day_count", 0)), GameState.roster.size(), int(GameState.run.get("kelly_risk", 0))]
	summary += "\n" + "\n".join(PackedStringArray(preload("res://src/core/town/goals.gd").run_summary(DataDB.all(), GameState.run, [GameState.player] + GameState.roster)))
	var jr: Dictionary = Journal.data
	var journal_line := Strings.t("flow.the_narrator_s_journal_now") % [jr.get("lore", {}).size(), jr.get("enemies", {}).size(), int(jr.get("runs", 0))]
	await show_event({ "title": Strings.t("flow.the_end_of_this_run"), "text": "%s

%s
%s

Seed %d. The narrator closes the book. Then, after a moment, opens a new one." % [text, summary, journal_line, GameState.run_seed] })
	EventBus.run_closed.emit(cause)
	SceneRouter.goto(TITLE_SCENE)

## Standing near the park and woods edge when dusk comes lets you pick the party.
func _at_woods_edge() -> bool:
	var pos: Dictionary = GameState.run.get("town_pos", {})
	if str(pos.get("map", "")) != "outskirts" or bool(pos.get("interior", false)):
		return false
	var c: Array = pos.get("cell", [0, 0])
	var spot: Array = DataDB.table("town/zones/outskirts").get("spots", {}).get("park", [34, 25])
	return absi(int(c[0]) - int(spot[0])) + absi(int(c[1]) - int(spot[1])) <= 6


## Pending perk levels with no options (no perk list for the class) are dropped.
func _drop_empty_perk_levels() -> void:
	var p: Dictionary = GameState.player
	var pending: Array = p.get("pendingPerks", [])
	while not pending.is_empty() and preload("res://src/core/progression/leveling.gd").perk_options(DataDB.all(), p, int(pending[0])).is_empty():
		pending.remove_at(0)

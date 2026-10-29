## The single source of truth for a run: one Dictionary built by
## src/core/run/run_model.gd. Saving = to_dict(); loading = load_dict().
## Fields are exposed as properties so scenes can read GameState.player etc.
extends Node

const SAVE_VERSION := 3
const Char := preload("res://src/core/character.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const DT := preload("res://src/core/data_tables.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const DayFlow := preload("res://src/core/run/day_flow.gd")
const BondRules := preload("res://src/core/social/bonds.gd")

const COMBAT_SCENE := "res://src/scenes/combat/combat.tscn"

var run: Dictionary = {}
var combat_turn_mode := ""   # F1 > Fights override of data/combat_rules.json "turnMode" ("" = data)
## Combat difficulty for this run ("normal" or "hard"), chosen at new run; F1 > Fights can switch it.
var combat_difficulty: String:
	get: return str(run.get("combat_difficulty", DataDB.table("combat_rules").get("difficulty", "normal")))
	set(value): run["combat_difficulty"] = value
var dev_autoplay := false
var pending_combat: Dictionary = {}
var combat_return := ""
var combat_context := ""     # "arena" for Endless Arena and Rift fights (losing isn't death there)
var last_combat: Dictionary = {}

var run_seed: int:
	get: return int(run.get("seed", 0))
var player: Dictionary:
	get: return run.get("player", {})
	set(v): run["player"] = v
var roster: Array:
	get: return run.get("roster", [])
	set(v): run["roster"] = v
var party_ids: Array:
	get: return run.get("party_ids", [])
	set(v): run["party_ids"] = v
var cards: Dictionary:
	get: return run.get("cards", {})
var money: int:
	get: return int(run.get("money", 0))
	set(v): run["money"] = v
var flags: Dictionary:
	get: return run.get("flags", {})
var bonds: Dictionary:
	get: return run.get("bonds", {})
var schedule: Array:
	get: return run.get("schedule", [])


## Start a fresh run. Pass a seed to replay a run exactly; -1 picks one.
func new_run(seed_value: int = -1, class_id: String = "mage", player_name: String = Strings.t("game_state.new_kid"), opts: Dictionary = {}) -> void:
	if seed_value < 0:
		seed_value = absi(hash(Time.get_ticks_usec() + int(Time.get_unix_time_from_system()))) % 2147483647
	Rng.reseed(seed_value)
	combat_turn_mode = ""   # the F1 override never carries into a new run (P2 1.1)
	var o := opts.duplicate()
	o["name"] = player_name
	run = RM.new_run(DataDB.all(), seed_value, class_id, Rng.stream("creation"), o)
	pending_combat = {}
	last_combat = {}
	Calendar.reset()
	EventBus.run_started.emit(seed_value)
	EventBus.stats_changed.emit("player")


func has_run() -> bool:
	return not run.is_empty()


## Character record by id: "player" or a roster member.
func character(id: String) -> Dictionary:
	return RM.character(run, id)


func flag(key: String) -> bool:
	return RM.flag(run, key)


func set_flag(key: String, value: Variant = true) -> void:
	RM.set_flag(run, key, value)


## Give XP and run level-ups (the "leveling" stream). Returns the reports.
func give_xp(id: String, amount: int) -> Array:
	var ch := character(id)
	if ch.is_empty():
		return []
	var reports := Lv.add_xp(DataDB.all(), ch, amount, Rng.stream("leveling"))
	if not ch.get("isPlayer", false):
		Lv.auto_perks(DataDB.all(), ch)
	if not reports.is_empty():
		Audio.event("level_up")
	EventBus.stats_changed.emit(id)
	return reports


## Apply an effects Dictionary (see src/core/run/effects.gd). Returns lines.
func apply_effects(fx: Dictionary, extra_ctx: Dictionary = {}) -> Array:
	var c := ctx()
	c.merge(extra_ctx, true)
	if fx.has("ap"):
		Calendar.set_ap(Calendar.ap() + int(fx["ap"]))
	var lines := Fx.apply(DataDB.all(), run, fx, Rng.stream("events"), c)
	EventBus.stats_changed.emit("player")
	EventBus.money_changed.emit(money)
	return lines


## Context for event conditions: week, day, part, period.
func ctx() -> Dictionary:
	return { "week": Calendar.week(), "day": Calendar.day_name(), "part": Calendar.part_id(),
		"period": int(Calendar.current_part().get("period", 0)), "ap": Calendar.ap() }


func conditions_met(cond: Dictionary) -> bool:
	return Fx.conditions_met(DataDB.all(), run, cond, ctx())


func spend_money(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	EventBus.money_changed.emit(money)
	return true


# --- Time ---------------------------------------------------------------------------

## Move to the next day part. Handles sleep at the end of a day and the weekly
## reset, autosaves, and announces the new part.
func advance_part() -> void:
	var day_before: int = Calendar.logic.day_index
	var week_before: int = Calendar.week()
	Calendar.advance_part()
	if Calendar.logic.day_index != day_before or Calendar.week() != week_before:
		for line in DayFlow.end_day(DataDB.all(), run):
			Narrator.say(str(line))
	if Calendar.week() != week_before:
		DayFlow.new_week(DataDB.all(), run)
		EventBus.week_started.emit(Calendar.week())
	SaveSystem.save_run()
	EventBus.part_started.emit()


## Screens the current part opens with (see DayFlow.on_enter).
func part_screens() -> Array:
	return DayFlow.on_enter(run, Calendar.week(), Calendar.day_name(), Calendar.current_part(), Calendar.logic.is_weekend())


# --- Combat hand-off --------------------------------------------------------------

## Characters who fight tonight: the player plus chosen roster members who are
## not injured, as combat setup entries.
func combat_party() -> Array:
	var ids := DayFlow.available_party(run)
	player["partyBonds"] = BondRules.party_bonds(run, ids)
	var out: Array = [{ "char": player }]
	for id in ids:
		var m := character(str(id))
		m["partyBonds"] = { "player": RM.bond(run, str(id)) }
		out.append({ "char": m, "ai": bool(m.get("guest", false)), "guest": bool(m.get("guest", false)) })
	for g in run.get("guests", []):
		out.append({ "char": g, "ai": true, "guest": true })
	return out


## Build a combat setup from enemy ids (or records) and a layout id.
func combat_setup(enemies: Array, layout_id: String, opts: Dictionary = {}) -> Dictionary:
	var db: Dictionary = DataDB.all()
	var index := DT.index_under(db, "enemies/", "enemies")
	var recs: Array = []
	for e in enemies:
		var rec: Dictionary = (e if typeof(e) == TYPE_DICTIONARY else index.get(str(e), {})).duplicate(true)
		if not rec.is_empty():
			recs.append(rec)
	var setup := {
		"layout": DataDB.record("rooms/combat_layouts", layout_id),
		"party": opts.get("party", combat_party()),
		"enemies": recs,
		"boss": bool(opts.get("boss", false)),
		"library": cards,
	}
	for key in ["intro", "fleeAllowed", "context", "formation", "roles", "reinforcements", "turnMode",
			"tutorial", "playerDeck", "addCards", "ui", "fair", "hpFloor", "guaranteeImprovise", "lesson", "stayedInRed", "partyFirst"]:
		if opts.has(key):
			setup[key] = opts[key]
	setup["difficulty"] = combat_difficulty
	setup["backpack"] = run.get("backpack", [])
	return setup


## Arena pause > Save and Quit (PT Part 3): the run is saved at the start of the
## current wave (party HP and MP as they were, the wave not yet fought), so
## Continue restarts that wave. Then back to the title.
func save_arena_and_quit() -> void:
	var a: Dictionary = run.get("arena", {})
	if a.is_empty():
		return
	if bool(a.get("inFight", false)):
		a["wave"] = int(a.get("wave", 1)) - 1
		a["inFight"] = false
		for ch_state in a.get("partyBefore", []):
			var ch := character(str(ch_state["id"]))
			if not ch.is_empty():
				ch["hp"] = int(ch_state["hp"])
				ch["mp"] = int(ch_state["mp"])
	run["resume_scene"] = "res://src/scenes/arena/arena.tscn"
	SaveSystem.save_run(true)
	pending_combat = {}
	SceneRouter.goto("res://src/scenes/title/title.tscn")


## Go to the combat scene; come back to `return_scene` (default: the current one).
func start_combat(setup: Dictionary, return_scene: String = "") -> void:
	pending_combat = setup
	if return_scene == "":
		var cur := get_tree().current_scene
		return_scene = cur.scene_file_path if cur != null else ""
	combat_return = return_scene
	combat_context = str(setup.get("context", ""))
	SceneRouter.goto(COMBAT_SCENE)


func take_pending_combat() -> Dictionary:
	var s := pending_combat
	pending_combat = {}
	return s


## Debug: add a generated party member and put them in tonight's party.
func add_debug_ally(class_id: String) -> void:
	if run.is_empty():
		new_run()
	var id := "debug_%s_%d" % [class_id, roster.size()]
	var ch := Char.create(DataDB.all(), class_id, Rng.stream("creation"), { "id": id, "name": Strings.t("game_state.debug") % class_id.capitalize() })
	ch["sprite"] = Assets.role("debugAlly")
	roster.append(ch)
	party_ids.append(id)


## Used when the combat scene is opened directly (F6 in the editor, debug).
func debug_combat_setup() -> Dictionary:
	if run.is_empty():
		new_run()
	return combat_setup(["pom_pom_wisp", "megaphone_mimic", "bleacher_creeper"], "open_field")


## Apply a fight's summary to the run: XP for everyone who fought, money,
## injuries for the downed. Returns { "lines": [...] } for the result screen.
func finish_combat(summary: Dictionary) -> Dictionary:
	last_combat = summary
	var lines: Array = []
	# Items (user request, Oct 28): used consumables leave decks and the backpack;
	# whoever went down loses the relics they wore.
	const Inv := preload("res://src/core/items/inventory.gd")
	Inv.spend_from_backpack(run, summary.get("backpackUsed", []))
	for p in summary.get("party", []):
		var who := character(str(p.get("id", "")))
		if who.is_empty():
			continue
		if not p.get("spent", []).is_empty():
			Inv.spend_from_deck(who, p["spent"])
			lines.append(Strings.t("game_state.item_used_up") % [str(who.get("name", "?")), ", ".join(PackedStringArray(p["spent"].map(func(c: Variant) -> String: return str(DataDB.record("cards", str(c)).get("name", c)))))])
		if bool(p.get("downed", false)):
			for rid in Inv.lose_relics(who):
				lines.append(Strings.t("relic.lost") % [str(who.get("name", "?")), str(Inv.item(DataDB.all(), str(rid)).get("name", rid))])
	var result := str(summary.get("result", ""))
	if result == "win":
		money += int(summary.get("money", 0))
		lines.append(Strings.t("game_state.xp_each") % [int(summary.get("xp", 0)), int(summary.get("money", 0))])
		EventBus.money_changed.emit(money)
	elif result == "flee":
		lines.append(Strings.t("game_state.you_leave_the_room_s"))
	for p in summary.get("party", []):
		var ch := character(str(p["id"]))
		if ch.is_empty():
			continue
		if bool(p.get("downed", false)) and not ch.get("isPlayer", false):
			ch["injured"] = int(DataDB.table("leveling").get("injuryDays", 2))
			lines.append(Strings.t("game_state.is_injured_and_will_need") % ch.get("name", "?"))
		if result == "win" and int(summary.get("xp", 0)) > 0:
			for r in give_xp(str(p["id"]), int(summary.get("xp", 0))):
				lines.append(Strings.t("game_state.reached_level") % [ch.get("name", "?"), int(r["level"])])
	if result == "lose":
		lines.append(Strings.t("game_state.you_re_knocked_out") if combat_context == "arena" else Strings.t("game_state.the_upside_down_keeps_you"))
	else:
		var survivors: Array = []
		for p in summary.get("party", []):
			if not bool(p.get("downed", false)) and not character(str(p["id"])).get("guest", false):
				survivors.append(str(p["id"]))
		BondRules.fought_together(DataDB.all(), run, survivors)
	EventBus.combat_finished.emit(summary)
	return { "lines": lines }


## Leave the combat scene. Death is handled by whoever listens for run_ended.
func leave_combat() -> void:
	if str(last_combat.get("result", "")) == "lose" and combat_context != "arena":
		EventBus.run_ended.emit("combat")
		return
	var dest := combat_return if combat_return != "" else "res://src/scenes/town/town.tscn"
	SceneRouter.goto(dest)


# --- Save ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"rng": Rng.get_state(),
		"calendar": Calendar.get_state(),
		"run": run,
	}


func load_dict(d: Dictionary) -> void:
	run = d.get("run", {})
	Rng.set_state(d.get("rng", {}))
	Calendar.reset(d.get("calendar", {}))
	EventBus.stats_changed.emit("player")

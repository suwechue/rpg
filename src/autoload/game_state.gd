## The single source of truth for a run. Saving = to_dict(); loading = load_dict().
extends Node

const SAVE_VERSION := 2
const Char := preload("res://src/core/character.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const DT := preload("res://src/core/data_tables.gd")

var run_seed: int = 0
var player: Dictionary = {}
var roster: Array = []
var cards: Dictionary = {}
var flags: Dictionary = {}
var bonds: Dictionary = {}
var schedule: Array = []
var town_signature: Dictionary = {}
var encounter_log: Array = []


## Start a fresh run. Pass a seed to replay a run exactly; -1 picks one.
func new_run(seed_value: int = -1, class_id: String = "mage", player_name: String = "New Kid") -> void:
	if seed_value < 0:
		seed_value = absi(hash(Time.get_ticks_usec() + int(Time.get_unix_time_from_system()))) % 2147483647
	run_seed = seed_value
	Rng.reseed(run_seed)
	player = Char.create(DataDB.all(), class_id, Rng.stream("creation"), { "id": "player", "name": player_name, "isPlayer": true })
	roster = []
	cards = {}
	money = int(DataDB.table("economy").get("startMoney", 20))
	party_ids = []
	flags = {}
	bonds = {}
	schedule = DataDB.table("school_classes").get("defaultSchedule", []).duplicate()
	town_signature = {}
	encounter_log = []
	Calendar.reset()
	EventBus.run_started.emit(run_seed)
	EventBus.stats_changed.emit("player")


## Character record by id: "player" or a roster member.
func character(id: String) -> Dictionary:
	if id == "player":
		return player
	for m in roster:
		if str(m.get("id", "")) == id:
			return m
	return {}


## Give XP and run level-ups (the "leveling" stream). Returns the reports.
func give_xp(id: String, amount: int) -> Array:
	var ch := character(id)
	if ch.is_empty():
		return []
	var reports := Lv.add_xp(DataDB.all(), ch, amount, Rng.stream("leveling"))
	if not ch.get("isPlayer", false):
		Lv.auto_perks(DataDB.all(), ch)
	EventBus.stats_changed.emit(id)
	return reports


# --- Combat hand-off --------------------------------------------------------------

const COMBAT_SCENE := "res://src/scenes/combat/combat.tscn"

var money: int = 0
var dev_autoplay := false
var party_ids: Array = []
var pending_combat: Dictionary = {}
var combat_return := ""
var last_combat: Dictionary = {}


## Characters who fight tonight: the player plus chosen roster members who are
## not injured, as combat setup entries.
func combat_party() -> Array:
	var out: Array = [{ "char": player }]
	for id in party_ids:
		var m := character(str(id))
		if not m.is_empty() and not bool(m.get("injured", false)):
			out.append({ "char": m, "ai": bool(m.get("guest", false)), "guest": bool(m.get("guest", false)) })
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
	if opts.has("intro"):
		setup["intro"] = opts["intro"]
	if opts.has("fleeAllowed"):
		setup["fleeAllowed"] = opts["fleeAllowed"]
	return setup


## Go to the combat scene; come back to `return_scene` (default: the current one).
func start_combat(setup: Dictionary, return_scene: String = "") -> void:
	pending_combat = setup
	if return_scene == "":
		var cur := get_tree().current_scene
		return_scene = cur.scene_file_path if cur != null else ""
	combat_return = return_scene
	SceneRouter.goto(COMBAT_SCENE)


func take_pending_combat() -> Dictionary:
	var s := pending_combat
	pending_combat = {}
	return s


## Debug: add a generated party member and put them in tonight's party.
func add_debug_ally(class_id: String) -> void:
	var id := "debug_%s_%d" % [class_id, roster.size()]
	var ch := Char.create(DataDB.all(), class_id, Rng.stream("creation"), { "id": id, "name": "Debug %s" % class_id.capitalize() })
	ch["sprite"] = "res://assets/packs/ninja_adventure/Actor/Character/Knight/SpriteSheet.png"
	roster.append(ch)
	party_ids.append(id)


## Used when the combat scene is opened directly (F6 in the editor, debug).
func debug_combat_setup() -> Dictionary:
	if player.is_empty():
		new_run()
	return combat_setup(["pom_pom_wisp", "megaphone_mimic", "bleacher_creeper"], "open_field")


## Apply a fight's summary to the run: XP for everyone who fought, money,
## injuries for the downed. Returns { "lines": [...] } for the result screen.
func finish_combat(summary: Dictionary) -> Dictionary:
	last_combat = summary
	var lines: Array = []
	var result := str(summary.get("result", ""))
	if result == "win":
		money += int(summary.get("money", 0))
		lines.append("+%d XP each, +$%d" % [int(summary.get("xp", 0)), int(summary.get("money", 0))])
		EventBus.money_changed.emit(money)
	elif result == "flee":
		lines.append("You leave the room's loot behind.")
	for p in summary.get("party", []):
		var ch := character(str(p["id"]))
		if ch.is_empty():
			continue
		if bool(p.get("downed", false)) and not ch.get("isPlayer", false):
			ch["injured"] = true
			lines.append("%s is injured and will need the hospital." % ch.get("name", "?"))
		if result == "win" and int(summary.get("xp", 0)) > 0:
			for r in give_xp(str(p["id"]), int(summary.get("xp", 0))):
				lines.append("%s reached level %d!" % [ch.get("name", "?"), int(r["level"])])
	if result == "lose":
		lines.append("The Upside-Down keeps you.")
	EventBus.combat_finished.emit(summary)
	return { "lines": lines }


## Leave the combat scene. Death is handled by whoever listens for run_ended.
func leave_combat() -> void:
	if str(last_combat.get("result", "")) == "lose":
		EventBus.run_ended.emit("combat")
	var dest := combat_return if combat_return != "" else "res://src/scenes/main.tscn"
	SceneRouter.goto(dest)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"run_seed": run_seed,
		"rng": Rng.get_state(),
		"calendar": Calendar.get_state(),
		"player": player,
		"roster": roster,
		"cards": cards,
		"money": money,
		"party_ids": party_ids,
		"flags": flags,
		"bonds": bonds,
		"schedule": schedule,
		"town_signature": town_signature,
		"encounter_log": encounter_log,
	}


func load_dict(d: Dictionary) -> void:
	run_seed = int(d.get("run_seed", 0))
	Rng.set_state(d.get("rng", {}))
	player = d.get("player", {})
	roster = d.get("roster", [])
	cards = d.get("cards", {})
	money = int(d.get("money", 0))
	party_ids = d.get("party_ids", [])
	flags = d.get("flags", {})
	bonds = d.get("bonds", {})
	schedule = d.get("schedule", [])
	town_signature = d.get("town_signature", {})
	encounter_log = d.get("encounter_log", [])
	Calendar.reset(d.get("calendar", {}))
	EventBus.stats_changed.emit("player")

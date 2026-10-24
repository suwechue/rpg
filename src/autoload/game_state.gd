## The single source of truth for a run. Saving = to_dict(); loading = load_dict().
extends Node

const SAVE_VERSION := 2
const Char := preload("res://src/core/character.gd")
const Lv := preload("res://src/core/progression/leveling.gd")

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


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"run_seed": run_seed,
		"rng": Rng.get_state(),
		"calendar": Calendar.get_state(),
		"player": player,
		"roster": roster,
		"cards": cards,
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
	flags = d.get("flags", {})
	bonds = d.get("bonds", {})
	schedule = d.get("schedule", [])
	town_signature = d.get("town_signature", {})
	encounter_log = d.get("encounter_log", [])
	Calendar.reset(d.get("calendar", {}))
	EventBus.stats_changed.emit("player")

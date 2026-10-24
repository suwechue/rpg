## The single source of truth for a run. Saving = to_dict(); loading = load_dict().
extends Node

const SAVE_VERSION := 1

var run_seed: int = 0
var player: Dictionary = {}
var roster: Array = []
var flags: Dictionary = {}
var bonds: Dictionary = {}
var schedule: Array = []
var town_signature: Dictionary = {}
var encounter_log: Array = []


## Start a fresh run. Pass a seed to replay a run exactly; -1 picks one.
func new_run(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = absi(hash(Time.get_ticks_usec() + int(Time.get_unix_time_from_system()))) % 2147483647
	run_seed = seed_value
	Rng.reseed(run_seed)
	player = DataDB.table("player_template").duplicate(true)
	roster = []
	flags = {}
	bonds = {}
	schedule = DataDB.table("school_classes").get("defaultSchedule", []).duplicate()
	town_signature = {}
	encounter_log = []
	Calendar.reset()
	EventBus.run_started.emit(run_seed)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"run_seed": run_seed,
		"rng": Rng.get_state(),
		"calendar": Calendar.get_state(),
		"player": player,
		"roster": roster,
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
	flags = d.get("flags", {})
	bonds = d.get("bonds", {})
	schedule = d.get("schedule", [])
	town_signature = d.get("town_signature", {})
	encounter_log = d.get("encounter_log", [])
	Calendar.reset(d.get("calendar", {}))
	EventBus.stats_changed.emit("player")

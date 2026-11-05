## Records one Lab fight (docs/COMBAT_LAB.md Part 1). CombatState passes it every
## event; the Lab screen adds the rating and saves one JSON line per fight in
## user://lab/. Plain data and file I/O only.
extends RefCounted

const UserPaths := preload("res://src/core/user_paths.gd")

const FILE_NAME := "lab_log.jsonl"
const BOARD_CAUSES := ["collision", "pit", "fall", "hazard", "burn", "spikes", "explosion", "toxic", "shift_board"]

var fight := ""
var seed_value := 0
var party: Array = []
var preset := ""
var lever_values: Dictionary = {}
var turns: Array = []
var pushes := 0
var board_kills := 0
var combos := 0
var cards_played := 0
var telegraphed_damage := 0
var untelegraphed_damage := 0
var redirects := 0
var cancels := 0
var lever_changes: Array = []
var surge_spent := 0
var started_ms := 0
var _turn: Dictionary = {}


func _init(fight_id: String = "", seed_in: int = 0, party_in: Array = [], preset_id: String = "", values: Dictionary = {}) -> void:
	fight = fight_id
	seed_value = seed_in
	party = party_in
	preset = preset_id
	lever_values = values
	started_ms = Time.get_ticks_msec()


func begin_turn(unit_id: String, round_num: int, options: Array) -> void:
	_turn = { "unit": unit_id, "round": round_num, "options": options, "played": [], "pushes": 0, "boardKills": 0, "combos": 0, "telegraphed": 0, "untelegraphed": 0 }
	turns.append(_turn)


func played(name: String) -> void:
	cards_played += 1
	if not _turn.is_empty():
		_turn["played"].append(name)


func note_lever_change(round_num: int, changes: Dictionary) -> void:
	lever_changes.append({ "round": round_num, "changes": changes })


func _bump(key: String, by: int = 1) -> void:
	if not _turn.is_empty():
		_turn[key] = int(_turn[key]) + by


## Every event CombatState emits passes through here.
func observe(e: Dictionary) -> void:
	match str(e.get("t", "")):
		"push":
			pushes += 1
			_bump("pushes")
		"combo":
			combos += 1
			_bump("combos")
		"board_kill":
			board_kills += 1
			_bump("boardKills")
		"redirected":
			redirects += 1
		"telegraph_cancelled":
			cancels += 1
		"surge_spent":
			surge_spent += 1
		"damage":
			if not bool(e.get("toParty", false)):
				return
			var dealt := int(e.get("amount", 0)) + int(e.get("absorbed", 0))
			if bool(e.get("telegraphed", false)):
				telegraphed_damage += dealt
				_bump("telegraphed", dealt)
			else:
				untelegraphed_damage += dealt
				_bump("untelegraphed", dealt)


## Options offered per turn, averaged over player turns: how much choice there was.
func decisions_per_turn() -> float:
	var total := 0
	var n := 0
	for t in turns:
		if not t.get("options", []).is_empty() or not t.get("played", []).is_empty():
			total += t.get("options", []).size()
			n += 1
	return float(total) / float(maxi(1, n))


func line(result: String, rounds: int, rating: Dictionary = {}) -> Dictionary:
	return {
		"kind": "fight", "at": Time.get_datetime_string_from_system(), "fight": fight, "seed": seed_value, "party": party,
		"preset": preset, "levers": lever_values, "leverChanges": lever_changes,
		"result": result, "rounds": rounds, "seconds": roundi(float(Time.get_ticks_msec() - started_ms) / 1000.0),
		"pushes": pushes, "boardKills": board_kills, "combos": combos, "cardsPlayed": cards_played, "redirects": redirects, "cancels": cancels, "surgeSpent": surge_spent,
		"telegraphedDamage": telegraphed_damage, "untelegraphedDamage": untelegraphed_damage,
		"decisionsPerTurn": snappedf(decisions_per_turn(), 0.01), "turns": turns, "rating": rating,
	}


static func path() -> String:
	return UserPaths.of("lab/") + FILE_NAME


static func append(rec: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UserPaths.of("lab/")))
	var f: FileAccess
	if FileAccess.file_exists(path()):
		f = FileAccess.open(path(), FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_line(JSON.stringify(rec))
	f.close()
	return true


## Every line in the lab folder that parses.
static func read_all(folder: String = "") -> Array:
	var dir := folder if folder != "" else UserPaths.of("lab/")
	var out: Array = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		return out
	for name in DirAccess.get_files_at(dir):
		if not str(name).ends_with(".jsonl"):
			continue
		for row in FileAccess.get_file_as_string(dir + str(name)).split("\n", false):
			var rec: Variant = JSON.parse_string(row)
			if typeof(rec) == TYPE_DICTIONARY:
				out.append(rec)
	return out

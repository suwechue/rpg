## The Narrator's Journal: persists between runs (DESIGN.md Section 14). Keeps
## lore you uncovered, enemy entries, endings seen and small starting-option
## unlocks (traits to pick at creation, never raw power). user://journal.json,
## written atomically like the run save.
extends Node

const PATH := "user://journal.json"

var data: Dictionary = {}


func _ready() -> void:
	load_journal()
	EventBus.combat_finished.connect(_on_combat)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.week_started.connect(func(w: int) -> void:
		note_week(w))


## VD Part 2: note a combo discovery in the run and the Journal. True the
## first time this run (the caller shows the reveal).
func discover_combo(id: String) -> bool:
	if not GameState.has_run():
		return false
	var fresh := preload("res://src/core/combos.gd").discover(GameState.run, data, id)
	if fresh:
		save_journal()
	return fresh


func load_journal() -> void:
	data = { "runs": 0, "lore": {}, "enemies": {}, "endings": {}, "unlocks": [], "bestWeek": 0 }
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			data.merge(parsed, true)


func save_journal() -> void:
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var final_abs := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(final_abs)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), final_abs)


func _on_combat(summary: Dictionary) -> void:
	var idx: Dictionary = {}
	for e in DataDB.records_under("enemies/", "enemies"):
		idx[str(e["id"])] = e
	for id in summary.get("kills", []):
		var key := str(id)
		var entry: Dictionary = data["enemies"].get(key, { "name": str(idx.get(key, {}).get("name", key)), "text": str(idx.get(key, {}).get("text", "")), "defeated": 0 })
		entry["defeated"] = int(entry.get("defeated", 0)) + 1
		data["enemies"][key] = entry
	for id in summary.get("remaining", []):
		var key := str(id)
		if not data["enemies"].has(key):
			data["enemies"][key] = { "name": str(idx.get(key, {}).get("name", key)), "text": str(idx.get(key, {}).get("text", "")), "defeated": 0 }
	collect_lore()
	save_journal()


## Copy lore flags from the run ("lore_*") into the journal with readable text.
func collect_lore() -> void:
	if not GameState.has_run():
		return
	var texts: Dictionary = DataDB.table("journal").get("lore", {})
	for f in GameState.flags:
		var key := str(f)
		if key.begins_with("lore_") and texts.has(key):
			data["lore"][key] = str(texts[key])


func note_week(w: int) -> void:
	data["bestWeek"] = maxi(int(data.get("bestWeek", 0)), w)
	_check_unlocks()
	save_journal()


func _on_run_ended(cause: String) -> void:
	data["runs"] = int(data.get("runs", 0)) + 1
	data["endings"][cause] = int(data["endings"].get(cause, 0)) + 1
	collect_lore()
	_check_unlocks()
	save_journal()


## Record an ending that isn't a death (the week 5 finale).
func note_ending(id: String) -> void:
	data["endings"][id] = int(data["endings"].get(id, 0)) + 1
	collect_lore()
	_check_unlocks()
	save_journal()


## Starting traits unlock from what you've seen (data/journal.json "unlocks").
func _check_unlocks() -> void:
	for u in DataDB.table("journal").get("unlocks", []):
		var id := str(u["trait"])
		if data["unlocks"].has(id):
			continue
		var ok := true
		if u.has("ending") and not data["endings"].has(str(u["ending"])):
			ok = false
		if u.has("week") and int(data.get("bestWeek", 0)) < int(u["week"]):
			ok = false
		if u.has("runs") and int(data.get("runs", 0)) < int(u["runs"]):
			ok = false
		if u.has("lore") and data["lore"].size() < int(u["lore"]):
			ok = false
		if ok:
			data["unlocks"].append(id)


func unlocked_traits() -> Array:
	return data.get("unlocks", [])

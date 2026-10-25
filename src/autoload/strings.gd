## UI text by key from data/strings.json: Strings.t("combat.enemy_turn").
## Keeping every player-facing line in data makes it easy to rewrite and,
## later, to translate. A missing key logs a warning once and shows the key.
extends Node

const Str := preload("res://src/core/strings.gd")

var _warned: Dictionary = {}


func t(key: String) -> String:
	var table: Dictionary = DataDB.table("strings").get("strings", {})
	if not table.has(key):
		if not _warned.has(key):
			_warned[key] = true
			push_warning("Strings: no text for '%s' in data/strings.json" % key)
		return key
	return str(table[key])

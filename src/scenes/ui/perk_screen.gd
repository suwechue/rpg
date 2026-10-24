## Pick 1 of 2 perks for a level you reached (levels 3, 6 and 9).
extends "res://src/scenes/ui/modal.gd"

const Lv := preload("res://src/core/progression/leveling.gd")


func _ready() -> void:
	var p: Dictionary = GameState.player
	var lvl := int(p["pendingPerks"][0])
	build("Level %d perk" % lvl, 380)
	text("Pick one. It stays with you (a Class Change lets you keep one).", UiTheme.DIM)
	for id in Lv.perk_options(DataDB.all(), p, lvl):
		var pid := str(id)
		var rec := DataDB.record("perks", pid)
		add_button("%s: %s" % [rec.get("name", pid), rec.get("text", "")], func() -> void:
			Lv.choose_perk(DataDB.all(), GameState.player, pid)
			EventBus.stats_changed.emit("player")
			finish(pid))
	focus_first()

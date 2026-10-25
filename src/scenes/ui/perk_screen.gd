## Pick 1 of 2 perks for a level you reached (levels 3, 6 and 9).
extends "res://src/scenes/ui/modal.gd"

const Lv := preload("res://src/core/progression/leveling.gd")


func _ready() -> void:
	var p: Dictionary = GameState.player
	var lvl := int(p["pendingPerks"][0])
	build(Strings.t("perk.level_perk") % lvl, 380)
	text(Strings.t("perk.pick_one_it_stays_with"), UiTheme.DIM)
	for id in Lv.perk_options(DataDB.all(), p, lvl):
		var pid := str(id)
		var rec := DataDB.record("perks", pid)
		add_button("%s: %s" % [rec.get("name", pid), rec.get("text", "")], func() -> void:
			Lv.choose_perk(DataDB.all(), GameState.player, pid)
			EventBus.stats_changed.emit("player")
			finish(pid))
	focus_first()

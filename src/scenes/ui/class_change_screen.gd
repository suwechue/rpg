## Class Change at levels 5 and 12: pick an advanced class you qualify for
## (locked ones show what they need), then which old perk to keep.
extends "res://src/scenes/ui/modal.gd"

const CC := preload("res://src/core/progression/class_change.gd")
const DT := preload("res://src/core/data_tables.gd")


func _ready() -> void:
	build("Class Change (level %d)" % int(GameState.player.get("level", 1)), 420)
	Audio.play_sfx("secret")
	_menu()


func _menu() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var p: Dictionary = GameState.player
	var cur := DT.record(db, "classes", str(p.get("class", "")))
	text("You're a %s. Something in you is ready to change shape. Taking a new class swaps your growth and signature perk; you keep one perk." % cur.get("name", "?"), UiTheme.DIM)
	var opts := CC.options(db, GameState.run, p)
	for id in opts["available"]:
		var cls := DT.record(db, "classes", str(id))
		var cid := str(id)
		add_button("%s%s: %s" % [cls.get("name", id), " (hidden)" if bool(cls.get("hidden", false)) else "", cls.get("text", "")], func() -> void: _keep_perk(cid),
			false, str(cls.get("perk", {}).get("text", "")))
	for l in opts["locked"]:
		var cls := DT.record(db, "classes", str(l["id"]))
		add_button("%s  [%s]" % [cls.get("name", l["id"]), l["why"]], func() -> void: pass, true)
	add_button("Not now (wait for the next marker)", func() -> void:
		CC.decline(GameState.player)
		finish(null))
	focus_first()


func _keep_perk(class_id: String) -> void:
	var perks: Array = GameState.player.get("perks", [])
	if perks.is_empty():
		_apply(class_id, "")
		return
	clear_body()
	text("Keep which perk?", UiTheme.DIM)
	for pk in perks:
		var pid := str(pk)
		var rec := DT.record(DataDB.all(), "perks", pid)
		add_button("%s: %s" % [rec.get("name", pid), rec.get("text", "")], func() -> void: _apply(class_id, pid))
	add_button("Back", _menu)
	focus_first()


func _apply(class_id: String, keep: String) -> void:
	CC.apply(DataDB.all(), GameState.run, GameState.player, class_id, keep)
	var cls := DT.record(DataDB.all(), "classes", class_id)
	Narrator.say("You are a %s now. The narrator updates your character sheet, slightly smug about it." % cls.get("name", class_id))
	EventBus.stats_changed.emit("player")
	finish(class_id)

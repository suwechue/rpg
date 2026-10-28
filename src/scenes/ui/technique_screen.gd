## Pick a Technique (PT Part 8) at levels 2, 3, 6, 10, 14 and 18, or swap one
## at the workbench (reconfigure_from set). Planned Techniques are listed but greyed.
extends "res://src/scenes/ui/modal.gd"

const Lv := preload("res://src/core/progression/leveling.gd")

var who := "player"            # character id
var reconfigure_from := ""     # a Technique to swap out, or "" for a level pick


func _ready() -> void:
	var db: Dictionary = DataDB.all()
	var ch := GameState.character(who)
	var pending: Array = ch.get("pendingTechniques", [])
	build(Strings.t("technique.title") % (int(pending[0]) if not pending.is_empty() else int(ch.get("level", 1))), 420)
	if reconfigure_from != "":
		text(Strings.t("technique.swap_out") % str(Lv.techniques(db).get(reconfigure_from, {}).get("name", reconfigure_from)), UiTheme.ACCENT)
	text(Strings.t("technique.pick_one"), UiTheme.DIM)
	var offered := Lv.technique_options(db, ch)
	for id in offered:
		var tid := str(id)
		var rec: Dictionary = Lv.techniques(db).get(tid, {})
		add_button("[%s %d] %s: %s" % [str(rec.get("category", "")).capitalize(), int(rec.get("tier", 1)), rec.get("name", tid), rec.get("text", "")], func() -> void:
			if reconfigure_from != "":
				Lv.reconfigure(DataDB.all(), GameState.character(who), reconfigure_from, tid)
			else:
				Lv.choose_technique(DataDB.all(), GameState.character(who), tid)
			EventBus.stats_changed.emit(who)
			finish(tid))
	for t in Lv.techniques(db).values():
		if bool(t.get("planned", false)) and int(t.get("minLevel", 2)) <= int(ch.get("level", 1)):
			add_button("%s: %s %s" % [t.get("name", ""), t.get("text", ""), Strings.t("technique.planned")], func() -> void: pass, true)
	focus_first()

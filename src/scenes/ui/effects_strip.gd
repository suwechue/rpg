## The effects strip (P2 2.1): a column of small icons on the left edge for
## everything active now (mutators, run modifiers, story effects). Risky ones
## get a red border, helpful ones green, debug overrides amber. Hover for the
## details; click to open the Effects page in the Party panel.
extends VBoxContainer

const Effects := preload("res://src/core/effects.gd")

var state: Object = null    # a CombatState during a fight (the Party panel shows hands)


func _ready() -> void:
	add_theme_constant_override("separation", 1)
	refresh()


func _ctx() -> Dictionary:
	var cfg := ConfigFile.new()
	var easy := cfg.load("user://settings.cfg") == OK and bool(cfg.get_value("minigames", "easy", false))
	return { "difficulty": GameState.combat_difficulty, "easyMinigames": easy, "turnOverride": GameState.combat_turn_mode,
		"dataTurnMode": str(DataDB.table("combat_rules").get("turnMode", "")) }


func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if not GameState.has_run():
		return
	var size := Display.tile / 2.0
	for e in Effects.gather(DataDB.all(), GameState.run, _ctx()):
		if str(e["kind"]) in ["perk", "technique"]:
			continue
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(size + 2, size + 2)
		b.icon = Assets.texture(str(e["icon"]))
		b.expand_icon = true
		b.tooltip_text = "%s\n%s\n%s%s" % [e["name"], e["text"], e["source"], (" - " + str(e["duration"])) if str(e["duration"]) != "" else ""]
		var tone := str(e["tone"])
		if tone != "neutral":
			b.flat = false
			b.theme_type_variation = { "risky": "EffectRisky", "good": "EffectGood", "warning": "EffectWarning" }.get(tone, "")
		b.pressed.connect(_open_page)
		add_child(b)


func _open_page() -> void:
	var pp := preload("res://src/scenes/ui/party_panel.gd").new()
	pp.state = state
	pp.tab = "effects"
	await Flow.show_modal(pp)

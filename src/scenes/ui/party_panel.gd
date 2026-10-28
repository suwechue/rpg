## The Party panel (PT Part 3): every party member's character sheet (stats with
## explanations, derived values, Vectors, Forms, perks, deck), and during a
## fight their hand and discard pile. Read only; decks are edited at the
## workbench and at arena checkpoints. Reachable from the pause menu and the
## Party button in combat and the arena.
extends "res://src/scenes/ui/modal.gd"

const CharSheet := preload("res://src/scenes/ui/character_sheet.gd")
const CardRules := preload("res://src/core/card.gd")

var state: Object = null     # a CombatState during a fight, for hands and discard piles
var tab := "members"         # "members" or "effects" (P2 2.3)
var _who := 0


func _ready() -> void:
	build(Strings.t("party_panel.title"), 420)
	_refresh()


## The Effects page (P2 2.3): run-wide effects, then each member's perks,
## Techniques and lasting effects, each with icon, name, text, source, duration.
func _effects_page() -> void:
	var cfg := ConfigFile.new()
	var easy := cfg.load("user://settings.cfg") == OK and bool(cfg.get_value("minigames", "easy", false))
	var all := preload("res://src/core/effects.gd").gather(DataDB.all(), GameState.run, { "difficulty": GameState.combat_difficulty, "easyMinigames": easy,
		"turnOverride": GameState.combat_turn_mode, "dataTurnMode": str(DataDB.table("combat_rules").get("turnMode", "")) })
	text(Strings.t("party_panel.run_wide"), UiTheme.ACCENT)
	for e in all:
		if str(e["member"]) == "" :
			_effect_row(e)
	for ch in _members():
		var mine: Array = all.filter(func(x: Dictionary) -> bool: return str(x["member"]) == str(ch.get("id", "")))
		if mine.is_empty():
			continue
		text(str(ch.get("name", "?")), UiTheme.ACCENT)
		for e in mine:
			_effect_row(e)


func _effect_row(e: Dictionary) -> void:
	var r := row()
	var ic := TextureRect.new()
	ic.texture = Assets.texture(str(e["icon"]))
	ic.custom_minimum_size = Vector2(Display.tile / 2.0, Display.tile / 2.0)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.add_child(ic)
	var l := UiTheme.label("%s: %s (%s%s)" % [e["name"], e["text"], e["source"], (", " + str(e["duration"])) if str(e["duration"]) != "" else ""])
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	r.add_child(l)


func _members() -> Array:
	var out: Array = [GameState.player]
	for id in GameState.party_ids:
		var ch := GameState.character(str(id))
		if not ch.is_empty():
			out.append(ch)
	for g in GameState.run.get("guests", []):
		if g is Dictionary:
			out.append(g)
	return out


func _refresh() -> void:
	clear_body()
	var members := _members()
	var top := row()
	for t in ["members", "effects", "compendium"]:
		var key: String = t
		var tb := UiTheme.button(Strings.t("party_panel.tab_" + key), func() -> void:
			if key == "compendium":
				# VD Part 2: the Vector Compendium opens over the panel.
				visible = false
				await Flow.show_modal(preload("res://src/scenes/ui/compendium_screen.gd").new())
				visible = true
				return
			tab = key
			_refresh())
		tb.theme_type_variation = "SelectedButton" if key == tab else ""
		top.add_child(tb)
	if tab == "effects":
		_effects_page()
		add_button(Strings.t("party_panel.close"), func() -> void: finish(null))
		focus_first()
		return
	var tabs := row()
	for i in members.size():
		var idx := i
		var b := UiTheme.button(str(members[i].get("name", "?")).split(" ")[0], func() -> void:
			_who = idx
			_refresh())
		b.disabled = i == _who
		tabs.add_child(b)
	var ch: Dictionary = members[clampi(_who, 0, members.size() - 1)]
	var sheet := CharSheet.new()
	body.add_child(sheet)
	sheet.show_character(ch, GameState.cards)
	if state != null:
		for u in state.get("units"):
			if str(u.get("id")) == str(ch.get("id", "")) and u.get("deck") != null:
				var deck: Object = u.get("deck")
				var names := func(ids: Array) -> String:
					var n: Array = []
					for id in ids:
						n.append(str(CardRules.resolve(DataDB.all(), str(id), GameState.cards).get("name", id)))
					return ", ".join(PackedStringArray(n)) if not n.is_empty() else "-"
				text(Strings.t("party_panel.hand") % names.call(deck.get("hand")))
				text(Strings.t("party_panel.draw_discard") % [(deck.get("draw_pile") as Array).size(), names.call(deck.get("discard"))], UiTheme.DIM)
		text(Strings.t("party_panel.read_only"), UiTheme.DIM)
	add_button(Strings.t("party_panel.close"), func() -> void: finish(null))
	focus_first()

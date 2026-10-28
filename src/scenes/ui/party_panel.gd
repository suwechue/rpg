## The Party panel (PT Part 3): every party member's character sheet (stats with
## explanations, derived values, Vectors, Forms, perks, deck), and during a
## fight their hand and discard pile. Read only; decks are edited at the
## workbench and at arena checkpoints. Reachable from the pause menu and the
## Party button in combat and the arena.
extends "res://src/scenes/ui/modal.gd"

const CharSheet := preload("res://src/scenes/ui/character_sheet.gd")
const CardRules := preload("res://src/core/card.gd")

var state: Object = null     # a CombatState during a fight, for hands and discard piles
var _who := 0


func _ready() -> void:
	build(Strings.t("party_panel.title"), 420)
	_refresh()


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

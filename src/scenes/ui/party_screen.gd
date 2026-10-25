## Choose who comes into the Upside-Down tonight (up to 3 from the roster).
extends "res://src/scenes/ui/modal.gd"

const BondRules := preload("res://src/core/social/bonds.gd")
const Dlg := preload("res://src/core/social/dialogue_check.gd")
const CharSheet := preload("res://src/scenes/ui/character_sheet.gd")

var _picks: Array = []


func _ready() -> void:
	_picks = GameState.party_ids.duplicate()
	build(Strings.t("party.party"), 400)
	_refresh()


func _refresh() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var max_party := int(db.get("social", {}).get("maxParty", 3))
	if GameState.roster.is_empty():
		text(Strings.t("party.nobody_has_joined_you_yet"), UiTheme.DIM)
	else:
		text(Strings.t("party.pick_up_to_to_come") % max_party, UiTheme.DIM)
	for m in GameState.roster:
		var id := str(m["id"])
		var bond := float(GameState.bonds.get(id, 0.0))
		var injured := int(m.get("injured", 0)) > 0
		var label := Strings.t("party.lv_hp_bond") % ["[x] " if _picks.has(id) else "[ ] ", m.get("name", id), int(m.get("level", 1)),
			str(m.get("class", "")).capitalize(), int(m.get("hp", 0)), roundi(bond), Dlg.bond_tier(db, bond), Strings.t("party.injured") if injured else ""]
		add_button(label, func() -> void:
			if _picks.has(id):
				_picks.erase(id)
			elif _picks.size() < max_party:
				_picks.append(id)
			_refresh())
	add_button(Strings.t("party.done"), func() -> void:
		BondRules.set_party(DataDB.all(), GameState.run, _picks)
		finish(_picks))
	focus_first()

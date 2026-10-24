## Choose who comes into the Upside-Down tonight (up to 3 from the roster).
extends "res://src/scenes/ui/modal.gd"

const BondRules := preload("res://src/core/social/bonds.gd")
const Dlg := preload("res://src/core/social/dialogue_check.gd")
const CharSheet := preload("res://src/scenes/ui/character_sheet.gd")

var _picks: Array = []


func _ready() -> void:
	_picks = GameState.party_ids.duplicate()
	build("Party", 400)
	_refresh()


func _refresh() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var max_party := int(db.get("social", {}).get("maxParty", 3))
	if GameState.roster.is_empty():
		text("Nobody has joined you yet. Reach Friend Bond (41+) with someone recruitable and ask them.", UiTheme.DIM)
	else:
		text("Pick up to %d to come with you tonight." % max_party, UiTheme.DIM)
	for m in GameState.roster:
		var id := str(m["id"])
		var bond := float(GameState.bonds.get(id, 0.0))
		var injured := int(m.get("injured", 0)) > 0
		var label := "%s%s  Lv %d %s  HP %d  Bond %d (%s)%s" % ["[x] " if _picks.has(id) else "[ ] ", m.get("name", id), int(m.get("level", 1)),
			str(m.get("class", "")).capitalize(), int(m.get("hp", 0)), roundi(bond), Dlg.bond_tier(db, bond), "  INJURED" if injured else ""]
		add_button(label, func() -> void:
			if _picks.has(id):
				_picks.erase(id)
			elif _picks.size() < max_party:
				_picks.append(id)
			_refresh())
	add_button("Done", func() -> void:
		BondRules.set_party(DataDB.all(), GameState.run, _picks)
		finish(_picks))
	focus_first()

## Whose deck does a card go into? (P2 1.3) One button per party member with
## their deck size and a one-line fit hint; ineligible members are greyed with
## the reason; benched members sit under a divider; "Collection only" is always
## offered. finish() returns the member id, or "" for the collection only.
extends "res://src/scenes/ui/modal.gd"

const Arena := preload("res://src/core/arena/arena.gd")
const CardRules := preload("res://src/core/card.gd")

var card_id := ""
var active_ids: Array = []    # members in the party now; everyone else counts as benched


func _ready() -> void:
	var db: Dictionary = DataDB.all()
	var card := CardRules.resolve(db, card_id, GameState.cards)
	build(Strings.t("owner.title") % str(card.get("name", card_id)), 380)
	text(CardRules.describe(db, card), UiTheme.DIM)
	var owners := Arena.eligible_owners(db, GameState.run, card)
	var benched_shown := false
	for o in owners:
		var bench := not active_ids.is_empty() and not active_ids.has(str(o["id"]))
		if bench and not benched_shown:
			benched_shown = true
			text(Strings.t("owner.bench"), UiTheme.DIM)
		var oid := str(o["id"])
		var b := add_button(Strings.t("owner.member") % [str(o["name"]), int(o["deck"]), str(o["hint"])], func() -> void: finish(oid), not bool(o["ok"]), str(o["reason"]))
		b.set_meta("member", oid)
	add_button(Strings.t("owner.collection_only"), func() -> void: finish(""))
	focus_first()

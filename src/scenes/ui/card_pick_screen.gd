## Pick 1 of up to 3 cards (story card rewards, src/core/run/card_rewards.gd),
## or skip for a little money. Returns the card id, or null for skip.
extends "res://src/scenes/ui/modal.gd"

const CardRules := preload("res://src/core/card.gd")
const CardView := preload("res://src/scenes/combat/card_view.gd")

var ids: Array = []
var title_text := ""
var skip_money := 0


func _ready() -> void:
	build(title_text if title_text != "" else Strings.t("cards.pick_title"), Display.base.x * 0.8)
	text(Strings.t("cards.pick_help"), UiTheme.DIM)
	var r := row()
	var db: Dictionary = DataDB.all()
	for id in ids:
		var cid := str(id)
		var card := CardRules.resolve(db, cid, GameState.cards)
		var cv := CardView.new()
		cv.setup(card, CardRules.cost(db, card))
		cv.tooltip_text = str(card.get("text", ""))
		cv.pressed.connect(func() -> void: finish(cid))
		r.add_child(cv)
	add_button(Strings.t("cards.skip") % skip_money if skip_money > 0 else Strings.t("cards.skip_free"), func() -> void: finish(null))
	focus_first()

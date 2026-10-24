## A character's deck in a fight: draw pile, hand, discard. Opening hand 5,
## draw 2 per turn, hand limit 7. Drawing from an empty pile shuffles the discard
## back in and costs Fatigue (1 damage, rising by 1 each reshuffle).
class_name Deck
extends RefCounted

var draw_pile: Array = []
var hand: Array = []
var discard: Array = []
var exhausted: Array = []
var hand_limit := 7
var fatigue_next := 1
var fatigue_step := 1
var reshuffles := 0


## cfg keys (data/stats.json "combat"): handLimit, fatigueStart, fatigueStep.
func _init(card_ids: Array = [], rng: RandomNumberGenerator = null, cfg: Dictionary = {}) -> void:
	hand_limit = int(cfg.get("handLimit", 7))
	fatigue_next = int(cfg.get("fatigueStart", 1))
	fatigue_step = int(cfg.get("fatigueStep", 1))
	draw_pile = card_ids.duplicate()
	if rng != null:
		shuffle_pile(rng)


## Fisher-Yates with the passed seeded RNG. The top of the pile is the end.
func shuffle_pile(rng: RandomNumberGenerator) -> void:
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp


## Draw up to n cards (stops at the hand limit). Returns
## { "drawn": [ids], "fatigue": damage taken from reshuffles }.
func draw(n: int, rng: RandomNumberGenerator) -> Dictionary:
	var drawn: Array = []
	var fatigue := 0
	for i in n:
		if hand.size() >= hand_limit:
			break
		if draw_pile.is_empty():
			if discard.is_empty():
				break
			draw_pile = discard.duplicate()
			discard.clear()
			shuffle_pile(rng)
			fatigue += fatigue_next
			fatigue_next += fatigue_step
			reshuffles += 1
		var id: Variant = draw_pile.pop_back()
		hand.append(id)
		drawn.append(id)
	return { "drawn": drawn, "fatigue": fatigue }


## Move a card from hand to discard (or out of the fight if consumable).
## Returns the card id, or "" for a bad index.
func play(hand_index: int, consumable: bool = false) -> String:
	if hand_index < 0 or hand_index >= hand.size():
		return ""
	var id := str(hand[hand_index])
	hand.remove_at(hand_index)
	if consumable:
		exhausted.append(id)
	else:
		discard.append(id)
	return id


## Discard as fuel for an improvised cast.
func discard_from_hand(hand_index: int) -> String:
	return play(hand_index, false)


func total_cards() -> int:
	return draw_pile.size() + hand.size() + discard.size()

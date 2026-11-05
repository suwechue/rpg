## Card text written from a card's keywords and ops (docs/COMBAT_LAB.md Part 3).
## Templates live in data/strings.json as "card_op.<op>"; {key} is filled from the op.
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const KEYWORDS := ["free", "swift", "heavy", "exhaust", "retain", "charge"]


static func keyword_line(db: Dictionary, card: Dictionary) -> String:
	var parts: Array = []
	if bool(card.get("quick", false)):
		parts.append(Str.t(db, "keyword.quick"))
	for k in KEYWORDS:
		if bool(card.get(k, false)):
			parts.append(Str.t(db, "keyword." + k))
	if str(card.get("followUp", "")) != "":
		parts.append(Str.t(db, "keyword.follow_up") % str(card["followUp"]))
	if str(card.get("freeIf", "")) != "":
		parts.append(Str.t(db, "keyword.free_if_" + str(card["freeIf"])))
	return ". ".join(PackedStringArray(parts)) + ("." if not parts.is_empty() else "")


static func op_line(db: Dictionary, fx: Dictionary) -> String:
	var op := str(fx.get("op", ""))
	var values := {}
	for k in fx:
		var v: Variant = fx[k]
		values[str(k)] = str(int(v)) if v is float and float(v) == floorf(float(v)) else str(v)
	if not values.has("vector"):
		values["vector"] = ""
	else:
		values["vector"] = str(values["vector"]).capitalize() + " "
	return Str.t(db, "card_op." + op).format(values)


## The whole text: keywords first, then each op in order.
static func describe(db: Dictionary, card: Dictionary) -> String:
	var parts: Array = []
	var kw := keyword_line(db, card)
	if kw != "":
		parts.append(kw)
	for e in card.get("effects", []):
		parts.append(op_line(db, e))
	return " ".join(PackedStringArray(parts))

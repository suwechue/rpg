## The Alchemy Techniques (data/techniques.json, data/alchemy.json). Stored
## Formula brews one spell card into a one-use potion a night: it goes in the
## backpack, and anyone can use it as a Quick, at no MP. Volatile Brewing makes
## them a Magnitude stronger with a risk of backfiring (Mutation Mastery removes
## the risk). Grand Reagent brews a top-Magnitude potion once a week.
extends RefCounted

const CardRules := preload("res://src/core/card.gd")
const Inv := preload("res://src/core/items/inventory.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("alchemy", {})


static func has_tech(ch: Dictionary, id: String) -> bool:
	return ch.get("techniques", []).has(id)


## Party members who know Stored Formula.
static func brewers(run: Dictionary) -> Array:
	var out: Array = []
	for ch in [run.get("player", {})] + run.get("roster", []):
		if has_tech(ch, "stored_formula"):
			out.append(ch)
	return out


## "" if this character can brew tonight, or why not.
static func block(db: Dictionary, run: Dictionary, ch: Dictionary, day_count: int) -> String:
	if not has_tech(ch, "stored_formula"):
		return "unknown"
	if int(run.get("brewedDay", -1)) == day_count:
		return "brewed"
	if run.get("backpack", []).size() >= int(Inv.cfg(db).get("backpackSize", 6)):
		return "full"
	return ""


## Spell cards in this character's deck that make a potion (no Constructs,
## Glyphs, Infusions or cards that are already one-use).
static func brewable(db: Dictionary, run: Dictionary, ch: Dictionary) -> Array:
	var out: Array = []
	for id in ch.get("deck", []):
		var c := CardRules.resolve(db, str(id), run.get("cards", {}))
		if not CardRules.is_spell(c) or bool(c.get("consumable", false)) or out.has(str(id)):
			continue
		if str(c.get("form", "")) in cfg(db).get("noBrewForms", []):
			continue
		out.append(str(id))
	return out


static func _step_magnitude(db: Dictionary, mag: String, steps: int) -> String:
	var mags: Array = db.get("vectors", {}).get("magnitudeOrder", ["minor", "standard", "major", "grand"])
	return str(mags[clampi(mags.find(mag) + steps, 0, mags.size() - 1)])


## Grand Reagent is ready this week.
static func grand_ready(run: Dictionary, ch: Dictionary, week: int) -> bool:
	return has_tech(ch, "grand_reagent") and int(run.get("grandWeek", -1)) != week


## Brew a card into a potion in the backpack. Returns the potion's id, or "".
static func brew(db: Dictionary, run: Dictionary, ch: Dictionary, card_id: String, day_count: int, week: int, grand: bool = false) -> String:
	if block(db, run, ch, day_count) != "" or not brewable(db, run, ch).has(card_id):
		return ""
	var c := CardRules.resolve(db, card_id, run.get("cards", {})).duplicate(true)
	var mag := str(c.get("magnitude", "standard"))
	var volatile := has_tech(ch, "volatile_brewing")
	if volatile:
		mag = _step_magnitude(db, mag, 1)
	var use_grand := grand and grand_ready(run, ch, week)
	if use_grand:
		mag = "grand"
		run["grandWeek"] = week
	var n := int(run.get("potionCount", 0)) + 1
	run["potionCount"] = n
	var id := "pot:%d" % n
	c["id"] = id
	c["name"] = str(cfg(db).get("potionName", "%s Potion")) % str(c.get("name", "?"))
	c["magnitude"] = mag
	c["consumable"] = true
	c["quick"] = true
	c["costOverride"] = 0
	c["potion"] = true
	if volatile:
		c["volatile"] = true
	var cards: Dictionary = run.get("cards", {})
	cards[id] = c
	run["cards"] = cards
	var bp: Array = run.get("backpack", [])
	bp.append(id)
	run["backpack"] = bp
	run["brewedDay"] = day_count
	return id

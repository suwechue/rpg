## Card crafting (DESIGN.md Section 8, "Crafting cards"), ported from the Nexus
## invention pipeline:
## 1. A design (Vectors + Form + Magnitude) gives an input vector = direction x power.
## 2. The dominant Vector picks the minigame archetype.
## 3. Performance (0..1) sets how many Properties roll (0 to 2) and adds a
##    Magnitude step on a perfect score.
## 4. Properties are drawn without repeats, weighted by
##    weight x max(0.05, Match(input, signature)) x (1 + Performance), among
##    those whose Gate the input passes.
## Also: extra copies, the shared card collection and deck rules.
class_name Crafting
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const VO := preload("res://src/core/vector_ops.gd")
const DT := preload("res://src/core/data_tables.gd")
const CardRules := preload("res://src/core/card.gd")
const Char := preload("res://src/core/character.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("minigames", {})


## The input vector of a design: its Vector direction scaled by Magnitude power.
static func input_vector(db: Dictionary, vectors: Array, magnitude: String) -> Dictionary:
	var power := float(db.get("vectors", {}).get("magnitudes", {}).get(magnitude, {}).get("power", 0))
	var out := {}
	for v in vectors:
		out[str(v)] = power / float(vectors.size())
	return out


## The minigame archetype for an input (dominant axis; ties by axis order).
static func archetype(db: Dictionary, input: Dictionary) -> String:
	var dom := VO.dominant_axis(input, CardRules.arcane_axes(db))
	for rule in cfg(db).get("archetypes", []):
		if Array(rule.get("vectors", [])).has(dom):
			return str(rule["id"])
	return str(cfg(db).get("defaultArchetype", "precision"))


## How many Properties a Performance score rolls.
static func property_picks(db: Dictionary, performance: float) -> int:
	for row in cfg(db).get("propertyPicks", []):
		if not row.has("below") or performance < float(row["below"]):
			return int(row.get("picks", 0))
	return 0


static func is_perfect(db: Dictionary, performance: float) -> bool:
	return performance >= float(cfg(db).get("perfectAt", 0.95))


## Gate-passing Properties and their weights for this input and Performance.
static func property_weights(db: Dictionary, input: Dictionary, performance: float) -> Dictionary:
	var out := {}
	for p in db.get("properties", {}).get("properties", []):
		if not bool(p.get("cards", true)):
			continue
		if not VO.gate(input, p.get("gate", {})):
			continue
		var cos := maxf(0.05, VO.similarity(input, p.get("signature", {})))
		out[str(p["id"])] = float(p.get("weight", 1.0)) * cos * (1.0 + performance)
	return out


static func roll_properties(db: Dictionary, input: Dictionary, performance: float, rng: RandomNumberGenerator) -> Array:
	var weights := property_weights(db, input, performance)
	var order: Array = []
	for p in db.get("properties", {}).get("properties", []):
		order.append(str(p["id"]))
	return VO.sample_unique(weights, rng, property_picks(db, performance), order)


## Craft a new card design. Returns the card (also stored in run.cards and
## added once to the collection), or {} with "error".
static func craft(db: Dictionary, run: Dictionary, ch: Dictionary, vectors: Array, form: String, magnitude: String, performance: float, rng: RandomNumberGenerator) -> Dictionary:
	var err := CardRules.design_error(db, ch, vectors, form, magnitude)
	if err != "":
		return { "error": err }
	var input := input_vector(db, vectors, magnitude)
	var props := roll_properties(db, input, performance, rng)
	var mag := magnitude
	var stepped := false
	if is_perfect(db, performance):
		mag = CardRules.step_up(db, magnitude, int(ch.get("knowledgeTier", 1)))
		stepped = mag != magnitude
	var dir := {}
	for v in vectors:
		dir[str(v)] = 1.0
	var card := CardRules.make_spell(db, dir, form, mag, props)
	if props.is_empty():
		run["collection"][card["id"]] = int(run["collection"].get(card["id"], 0)) + 1
		card["crafted"] = true
	else:
		run["crafted"] = int(run.get("crafted", 0)) + 1
		var id := "craft_%d" % int(run["crafted"])
		card["id"] = id
		var names: Array = []
		for p in props:
			names.append(str(DT.record(db, "properties", str(p)).get("adjective", "")))
		card["name"] = "%s %s" % [" ".join(PackedStringArray(names)).strip_edges(), card["name"]]
		card["cost"] = CardRules.spell_cost(db, card)
		run["cards"][id] = card
		run["collection"][id] = 1
	card["performance"] = performance
	card["archetype"] = archetype(db, input)
	card["stepped"] = stepped
	return card


## Another copy of a design you own (keeps its Properties, no minigame).
static func copy(run: Dictionary, card_id: String) -> bool:
	if int(run["collection"].get(card_id, 0)) <= 0:
		return false
	run["collection"][card_id] = int(run["collection"][card_id]) + 1
	return true


## Why this deck is not legal for the character, or "".
static func deck_error(db: Dictionary, run: Dictionary, ch: Dictionary, deck: Array) -> String:
	var lv: Dictionary = db.get("leveling", {})
	if deck.size() < int(lv.get("deckMin", 10)):
		return Str.t(db, "crafting.a_deck_needs_at_least") % int(lv.get("deckMin", 10))
	if deck.size() > Char.deck_max(db, ch):
		return Str.t(db, "crafting.this_deck_can_hold_at") % Char.deck_max(db, ch)
	var counts := {}
	for id in deck:
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		if int(counts[id]) > int(lv.get("maxCopies", 3)):
			return Str.t(db, "crafting.no_more_than_copies_of") % int(lv.get("maxCopies", 3))
		if int(counts[id]) > owned(run, ch, str(id)):
			return Str.t(db, "crafting.you_only_own_of") % [owned(run, ch, str(id)), id]
		var card := CardRules.resolve(db, str(id), run.get("cards", {}))
		if card.is_empty():
			return Str.t(db, "crafting.unknown_card") % id
		# Designs you made need the knowledge; named cards (learned, bought, found) don't.
		if CardRules.is_spell(card) and str(id).begins_with(CardRules.SPELL_PREFIX):
			for v in CardRules.ordered_vectors(db, card.get("vectors", {})):
				if not ch.get("knownVectors", []).has(v):
					return Str.t(db, "crafting.doesn_t_know") % [ch.get("name", "?"), str(v).capitalize()]
			if not ch.get("knownForms", []).has(str(card.get("form", ""))):
				return Str.t(db, "crafting.doesn_t_know_the_form") % [ch.get("name", "?"), card.get("form", "")]
	return ""


## Copies of a card available to this character: the shared collection, or
## their own starter cards if they are a party member.
static func owned(run: Dictionary, ch: Dictionary, card_id: String) -> int:
	var n := int(run.get("collection", {}).get(card_id, 0))
	if not ch.get("isPlayer", false):
		var own := 0
		for id in ch.get("starterDeck", ch.get("deck", [])):
			if str(id) == card_id:
				own += 1
		n = maxi(n, own)
	return n


static func set_deck(db: Dictionary, run: Dictionary, ch: Dictionary, deck: Array) -> String:
	var err := deck_error(db, run, ch, deck)
	if err == "":
		ch["deck"] = deck.duplicate()
	return err

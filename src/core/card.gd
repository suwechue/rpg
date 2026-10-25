## Card rules (DESIGN.md Section 8). A card is a Dictionary. Plain spell designs
## have parseable ids ("sp:heat:bolt:standard", "sp:heat+cold:burst:minor"), so
## they never need storing; crafted cards with Properties live in the run's card
## library and are looked up by id.
class_name Card
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const VO := preload("res://src/core/vector_ops.gd")
const DT := preload("res://src/core/data_tables.gd")

const SPELL_PREFIX := "sp:"


static func arcane_axes(db: Dictionary) -> Array:
	return db.get("spaces", {}).get("arcane", {}).get("axes", [])


## Vector axes of a card in the catalog's fixed order.
static func ordered_vectors(db: Dictionary, vectors: Dictionary) -> Array:
	var out: Array = []
	for axis in VO.ordered_axes(vectors, arcane_axes(db)):
		if float(vectors.get(axis, 0.0)) > 0.0:
			out.append(axis)
	return out


static func spell_id(db: Dictionary, vectors: Dictionary, form: String, magnitude: String) -> String:
	return "%s%s:%s:%s" % [SPELL_PREFIX, "+".join(PackedStringArray(ordered_vectors(db, vectors))), form, magnitude]


## A spell design. Two Vectors make a hybrid (an equal Blend).
static func make_spell(db: Dictionary, vectors: Dictionary, form: String, magnitude: String, properties: Array = []) -> Dictionary:
	var axes := ordered_vectors(db, vectors)
	var dir := {}
	for axis in axes:
		dir[axis] = 1.0 / float(axes.size())
	var card := {
		"id": spell_id(db, dir, form, magnitude),
		"name": spell_name(db, dir, form),
		"kind": "spell",
		"vectors": dir,
		"form": form,
		"magnitude": magnitude,
		"properties": properties.duplicate(),
	}
	card["cost"] = spell_cost(db, card)
	return card


static func spell_name(db: Dictionary, vectors: Dictionary, form: String) -> String:
	var names: Dictionary = db.get("vectors", {}).get("names", {})
	var parts: Array = []
	for axis in ordered_vectors(db, vectors):
		parts.append(str(names.get(axis, str(axis).capitalize())))
	var form_rec := DT.record(db, "forms", form)
	return "%s %s" % ["-".join(PackedStringArray(parts)), str(form_rec.get("name", form.capitalize()))]


## Cost = Magnitude cost + Form cost + 1 if hybrid (+ Property cost edits, min 0).
static func spell_cost(db: Dictionary, card: Dictionary) -> int:
	var mags: Dictionary = db.get("vectors", {}).get("magnitudes", {})
	var form_rec := DT.record(db, "forms", str(card.get("form", "")))
	var c := int(mags.get(str(card.get("magnitude", "")), {}).get("cost", 0)) + int(form_rec.get("cost", 0))
	if ordered_vectors(db, card.get("vectors", {})).size() > 1:
		c += int(db.get("vectors", {}).get("hybridExtraCost", 1))
	c += int(property_mods(db, card).get("costDelta", 0))
	return maxi(0, c)


## Merged Property edits on a card: power, powerPct, costDelta, stability, critPct.
static func property_mods(db: Dictionary, card: Dictionary) -> Dictionary:
	var out := {}
	var props: Array = card.get("properties", [])
	if props.is_empty():
		return out
	for p in db.get("properties", {}).get("properties", []):
		if props.has(str(p["id"])):
			for k in p.get("mods", {}):
				out[k] = float(out.get(k, 0.0)) + float(p["mods"][k])
	return out


static func cost(db: Dictionary, card: Dictionary) -> int:
	if str(card.get("kind", "")) == "spell":
		return spell_cost(db, card)
	return int(card.get("cost", 0))


## Improvised cost: ceil(cost x 1.5) + 1.
static func improvise_cost(db: Dictionary, card: Dictionary) -> int:
	var imp: Dictionary = db.get("vectors", {}).get("improvise", {})
	return int(ceil(float(spell_cost(db, card)) * float(imp.get("costMultiplier", 1.5)))) + int(imp.get("flatExtra", 1))


static func power(db: Dictionary, card: Dictionary) -> float:
	var mags: Dictionary = db.get("vectors", {}).get("magnitudes", {})
	var pm := property_mods(db, card)
	var base := float(mags.get(str(card.get("magnitude", "")), {}).get("power", 0)) + float(pm.get("power", 0.0))
	return base * (1.0 + float(pm.get("powerPct", 0.0)))


## Find a card by id: parseable spell ids first, then the run's library, then data.
static func resolve(db: Dictionary, id: String, library: Dictionary = {}) -> Dictionary:
	if library.has(id):
		return library[id]
	if id.ends_with("+"):
		return upgraded(DT.index_under(db, "cards/", "cards").get(id.trim_suffix("+"), {}))
	if id.begins_with(SPELL_PREFIX):
		var parts := id.substr(SPELL_PREFIX.length()).split(":")
		if parts.size() == 3:
			var vectors := {}
			for axis in parts[0].split("+"):
				vectors[axis] = 1.0
			return make_spell(db, vectors, parts[1], parts[2])
	return DT.index_under(db, "cards/", "cards").get(id, {})


## The "+" version of a card: its "upgrade" fields replace the base ones
## (a bigger Magnitude, more power, lower cost, new effects).
static func upgraded(card: Dictionary) -> Dictionary:
	if card.is_empty():
		return {}
	var out := card.duplicate(true)
	for k in card.get("upgrade", {}):
		out[k] = card["upgrade"][k]
	out["id"] = str(card.get("id", "")) + "+"
	out["name"] = str(card.get("name", "")) + "+"
	out.erase("upgrade")
	return out


## Highest Magnitude a Knowledge Tier allows.
static func max_magnitude(db: Dictionary, tier: int) -> String:
	var best := "minor"
	var mags: Dictionary = db.get("vectors", {}).get("magnitudes", {})
	for m in db.get("vectors", {}).get("magnitudeOrder", ["minor", "standard", "major", "grand"]):
		if int(mags.get(m, {}).get("minTier", 99)) <= tier:
			best = str(m)
	return best


static func magnitude_index(db: Dictionary, magnitude: String) -> int:
	return Array(db.get("vectors", {}).get("magnitudeOrder", ["minor", "standard", "major", "grand"])).find(magnitude)


## One Magnitude step up (capped by the tier), for perfect crafts and Breakthroughs.
static func step_up(db: Dictionary, magnitude: String, tier: int) -> String:
	var order: Array = db.get("vectors", {}).get("magnitudeOrder", ["minor", "standard", "major", "grand"])
	var i := order.find(magnitude)
	var cap := order.find(max_magnitude(db, tier))
	if i < 0:
		return magnitude
	return str(order[mini(i + 1, maxi(cap, i))])


## Why a character cannot design this spell, or "" if it is legal.
## Known Vectors are usable at any tier (class kits can start above Tier 1);
## the Knowledge Tier caps Magnitude and which new Vectors and Forms can be learned.
static func design_error(db: Dictionary, ch: Dictionary, vectors: Array, form: String, magnitude: String) -> String:
	if vectors.is_empty() or vectors.size() > 2:
		return Str.t(db, "card.pick_one_vector_or_two")
	for v in vectors:
		if not ch.get("knownVectors", []).has(v):
			return Str.t(db, "card.is_not_a_vector_you") % str(v).capitalize()
	if not ch.get("knownForms", []).has(form):
		return Str.t(db, "card.you_don_t_know_the") % form.capitalize()
	var tier := int(ch.get("knowledgeTier", 1))
	if magnitude_index(db, magnitude) < 0:
		return Str.t(db, "card.unknown_magnitude")
	if magnitude_index(db, magnitude) > magnitude_index(db, max_magnitude(db, tier)):
		return Str.t(db, "card.knowledge_tier_caps_you_at") % [tier, max_magnitude(db, tier).capitalize()]
	return ""


static func is_spell(card: Dictionary) -> bool:
	return str(card.get("kind", "")) == "spell"


## Shield and Aura with Light (or Vitality) heal; Weapon Infusion buffs.
static func heals(card: Dictionary) -> bool:
	if not is_spell(card):
		return str(card.get("action", "")) == "heal"
	var v: Dictionary = card.get("vectors", {})
	var form := str(card.get("form", ""))
	return (form == "shield" or form == "aura") and (v.has("light") or v.has("vitality"))


## Short description for tooltips and the card UI.
static func describe(db: Dictionary, card: Dictionary) -> String:
	if not is_spell(card):
		return str(card.get("text", ""))
	var form_rec := DT.record(db, "forms", str(card.get("form", "")))
	var mags: Dictionary = db.get("vectors", {}).get("magnitudes", {})
	var mag: Dictionary = mags.get(str(card.get("magnitude", "")), {})
	var parts: Array = []
	for axis in ordered_vectors(db, card.get("vectors", {})):
		parts.append(str(db.get("vectors", {}).get("display", {}).get(axis, axis)))
	var text := "%s %s, %s (%d). " % ["/".join(PackedStringArray(parts)), str(form_rec.get("name", "")), str(mag.get("name", "")), int(mag.get("power", 0))]
	var effects: Dictionary = db.get("vectors", {}).get("gridEffects", {})
	for axis in ordered_vectors(db, card.get("vectors", {})):
		text += str(effects.get(axis, "")).split(";")[0] + ". "
	if not card.get("properties", []).is_empty():
		text += Str.t(db, "card.properties") % ", ".join(PackedStringArray(card["properties"]))
	return text.strip_edges()


## A one-line effect for the card face ("Bolt 10", "Heal 12"): short enough
## for a card. Basics and items use their "short" text from data.
static func summary(db: Dictionary, card: Dictionary) -> String:
	if card.has("short"):
		return str(card["short"])
	if not is_spell(card):
		return str(card.get("name", "")).split(" ")[0]
	var form_rec := DT.record(db, "forms", str(card.get("form", "")))
	return "%s %d" % [form_rec.get("name", "?"), roundi(power(db, card))]


## Card art ids to try, most specific first: the card's own art, its first
## Vector's art (spells), then its kind's art.
static func art_ids(db: Dictionary, card: Dictionary) -> Array:
	var out: Array = []
	if card.has("art"):
		out.append(str(card["art"]))
	if card.has("id") and not str(card["id"]).begins_with("sp:"):
		out.append("card_art_%s" % card["id"])
	if is_spell(card):
		var axes := ordered_vectors(db, card.get("vectors", {}))
		if not axes.is_empty():
			out.append("card_art_%s" % axes[0])
	out.append("card_art_%s" % str(card.get("kind", "basic")))
	return out

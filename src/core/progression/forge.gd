## The Card Forge (docs/PATCH_1.md Part 5): fuse two cards into one, salvage a
## card for Scraps, spend Scraps on upgrades and riders. Rules and numbers live
## in data/forge.json and data/riders.json. Works on run["collection"] (counts),
## run["cards"] (designed cards) and run["scraps"] ({ "<vector>": n, "generic": n }).
extends RefCounted

const DT := preload("res://src/core/data_tables.gd")
const CardRules := preload("res://src/core/card.gd")
const Str := preload("res://src/core/strings.gd")

## Card kinds that count as a "technique" for element + technique fusion.
const TECHNIQUE_ACTIONS := ["strike", "effects", "dash"]


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("forge", {})


static func riders(db: Dictionary) -> Dictionary:
	var out := {}
	for r in db.get("riders", {}).get("riders", []):
		out[str(r["id"])] = r
	return out


static func card(db: Dictionary, run: Dictionary, id: String) -> Dictionary:
	return CardRules.resolve(db, id, run.get("cards", {}))


static func _vectors(c: Dictionary) -> Array:
	return c.get("vectors", {}).keys() if not c.get("vectors", {}).is_empty() else c.get("infuse", {}).keys()


## "element": Weapon Infusion or any single-Vector spell. "technique": Lunge,
## Strike-type cards, Throw, Shove, Dash... "spell": a spell (for hybrids).
static func kind_of(db: Dictionary, c: Dictionary) -> String:
	if CardRules.is_spell(c):
		if str(c.get("form", "")) == "weapon_infusion" or c.get("vectors", {}).size() == 1:
			return "element"
		return "spell"
	if TECHNIQUE_ACTIONS.has(str(c.get("action", ""))):
		return "technique"
	return ""


## Why two cards can't be fused, or "".
static func fuse_block(db: Dictionary, run: Dictionary, a_id: String, b_id: String) -> String:
	var coll: Dictionary = run.get("collection", {})
	var need := 2 if a_id == b_id else 1
	if int(coll.get(a_id, 0)) < need or int(coll.get(b_id, 0)) < 1:
		return Str.t(db, "forge.need_both_cards")
	var a := card(db, run, a_id)
	var b := card(db, run, b_id)
	var ka := kind_of(db, a)
	var kb := kind_of(db, b)
	if (ka == "element" and kb == "technique") or (ka == "technique" and kb == "element"):
		return ""
	if CardRules.is_spell(a) and CardRules.is_spell(b) and not (a.get("form", "") == "weapon_infusion" or b.get("form", "") == "weapon_infusion"):
		var axes := {}
		for v in _vectors(a) + _vectors(b):
			axes[v] = true
		if axes.size() < 2:
			return Str.t(db, "forge.same_vector")
		if axes.size() > int(cfg(db).get("maxVectors", 3)):
			return Str.t(db, "forge.too_many_vectors")
		return ""
	return Str.t(db, "forge.dont_fuse")


## The fused card (not yet added): an element-carrying technique, or a hybrid spell.
static func fuse_preview(db: Dictionary, run: Dictionary, a_id: String, b_id: String) -> Dictionary:
	if fuse_block(db, run, a_id, b_id) != "":
		return {}
	var a := card(db, run, a_id)
	var b := card(db, run, b_id)
	var surcharge := int(cfg(db).get("fusionSurcharge", 1))
	var out: Dictionary
	if kind_of(db, a) == "technique" or kind_of(db, b) == "technique":
		var tech := a if kind_of(db, a) == "technique" else b
		var elem := b if tech == a else a
		var axis := str(_vectors(elem)[0]) if not _vectors(elem).is_empty() else "force"
		out = tech.duplicate(true)
		out["infuse"] = { axis: 1.0 }
		out["name"] = "%s %s" % [str(db.get("vectors", {}).get("display", {}).get(axis, axis.capitalize())), str(tech.get("name", ""))]
		out["text"] = str(tech.get("text", "")) + " " + Str.t(db, "forge.carries") % str(db.get("vectors", {}).get("display", {}).get(axis, axis))
	else:
		var v := {}
		for axis in _vectors(a) + _vectors(b):
			v[str(axis)] = 1.0
		var mags: Array = db.get("vectors", {}).get("magnitudeOrder", ["minor", "standard", "major", "grand"])
		var mag := str(a.get("magnitude", "standard")) if mags.find(str(a.get("magnitude", ""))) >= mags.find(str(b.get("magnitude", ""))) else str(b.get("magnitude", "standard"))
		out = CardRules.make_spell(db, v, str(a.get("form", "bolt")), mag)
		out["name"] = combo_name(db, v.keys(), str(out.get("name", "")))
	out["id"] = "fz:%s+%s" % [a_id, b_id]
	out["fused"] = [a_id, b_id]
	out["cost"] = maxi(CardRules.cost(db, a), CardRules.cost(db, b)) + surcharge
	out["costOverride"] = out["cost"]
	out["rarity"] = _best_rarity(db, a, b)
	out["riders"] = []
	return out


## Named combos for Vector pairs (data/forge.json "comboNames"; VD extends them).
static func combo_name(db: Dictionary, axes: Array, fallback: String) -> String:
	var sorted := axes.duplicate()
	sorted.sort()
	return str(cfg(db).get("comboNames", {}).get("+".join(PackedStringArray(sorted)), fallback))


static func _best_rarity(db: Dictionary, a: Dictionary, b: Dictionary) -> String:
	var order: Array = cfg(db).get("rarityOrder", ["common", "uncommon", "rare"])
	var ra := order.find(str(a.get("rarity", "common")))
	var rb := order.find(str(b.get("rarity", "common")))
	return str(order[maxi(0, maxi(ra, rb))])


## Fuse: both sources are used up; the new card joins the collection.
static func fuse(db: Dictionary, run: Dictionary, a_id: String, b_id: String) -> Dictionary:
	var out := fuse_preview(db, run, a_id, b_id)
	if out.is_empty():
		return { "error": fuse_block(db, run, a_id, b_id) }
	_take(run, a_id)
	_take(run, b_id)
	run["cards"][str(out["id"])] = out
	run["collection"][str(out["id"])] = int(run["collection"].get(str(out["id"]), 0)) + 1
	return out


static func _take(run: Dictionary, id: String) -> void:
	var coll: Dictionary = run["collection"]
	coll[id] = int(coll.get(id, 0)) - 1
	if int(coll[id]) <= 0:
		coll.erase(id)
	# A card you no longer own leaves every deck it was in (one copy).
	for ch in [run.get("player", {})] + run.get("roster", []):
		var deck: Array = ch.get("deck", [])
		if deck.count(id) > int(coll.get(id, 0)) and deck.has(id):
			deck.erase(id)


## Scraps a card salvages into: its Vectors' Scraps plus generic Scraps by rarity.
static func salvage_value(db: Dictionary, c: Dictionary) -> Dictionary:
	var out := {}
	var per := int(cfg(db).get("salvage", {}).get("perVector", 2))
	for axis in _vectors(c):
		out[str(axis)] = per
	out["generic"] = int(cfg(db).get("salvage", {}).get("generic", {}).get(str(c.get("rarity", "common")), 1))
	return out


static func salvage(db: Dictionary, run: Dictionary, id: String) -> Dictionary:
	if int(run.get("collection", {}).get(id, 0)) <= 0:
		return { "error": Str.t(db, "forge.need_both_cards") }
	var gain := salvage_value(db, card(db, run, id))
	_take(run, id)
	add_scraps(run, gain)
	return gain


static func add_scraps(run: Dictionary, gain: Dictionary) -> void:
	if not run.has("scraps"):
		run["scraps"] = {}
	for k in gain:
		run["scraps"][k] = int(run["scraps"].get(k, 0)) + int(gain[k])


static func can_pay(run: Dictionary, cost: Dictionary) -> bool:
	var have: Dictionary = run.get("scraps", {})
	for k in cost:
		if int(have.get(k, 0)) < int(cost[k]):
			return false
	return true


static func pay(run: Dictionary, cost: Dictionary) -> void:
	for k in cost:
		run["scraps"][k] = int(run["scraps"].get(k, 0)) - int(cost[k])


## Upgrade with Scraps: the card's "+" version replaces one copy.
static func upgrade_cost(db: Dictionary, c: Dictionary) -> Dictionary:
	var out := { "generic": int(cfg(db).get("upgradeCost", {}).get(str(c.get("rarity", "common")), 3)) }
	for axis in _vectors(c):
		out[str(axis)] = int(cfg(db).get("upgradeVectorScraps", 1))
	return out


static func upgrade(db: Dictionary, run: Dictionary, id: String) -> Dictionary:
	var c := card(db, run, id)
	if c.is_empty() or id.ends_with("+") or not c.has("upgrade") and not CardRules.is_spell(c):
		return { "error": Str.t(db, "forge.cant_upgrade") }
	var cost := upgrade_cost(db, c)
	if int(run.get("collection", {}).get(id, 0)) <= 0 or not can_pay(run, cost):
		return { "error": Str.t(db, "forge.not_enough_scraps") }
	pay(run, cost)
	_take(run, id)
	var up_id := id + "+"
	if CardRules.is_spell(c) and not c.has("upgrade"):
		# Spell designs upgrade by one Magnitude step.
		var up := c.duplicate(true)
		var mags: Array = db.get("vectors", {}).get("magnitudeOrder", ["minor", "standard", "major", "grand"])
		up["magnitude"] = str(mags[mini(mags.find(str(c.get("magnitude", "minor"))) + 1, mags.size() - 1)])
		up["id"] = up_id
		up["name"] = str(c.get("name", "")) + "+"
		up["cost"] = CardRules.spell_cost(db, up)
		run["cards"][up_id] = up
	run["collection"][up_id] = int(run["collection"].get(up_id, 0)) + 1
	return card(db, run, up_id)


## Rider slots: 1 at common, 2 at uncommon, 3 at rare.
static func rider_slots(db: Dictionary, c: Dictionary) -> int:
	return int(cfg(db).get("riderSlots", {}).get(str(c.get("rarity", "common")), 1))


## Scrap cost of the next rider on this card: listed cost, +1 for the 2nd, +2 for the 3rd.
static func rider_cost(db: Dictionary, c: Dictionary, rider_id: String) -> Dictionary:
	var r: Dictionary = riders(db).get(rider_id, {})
	var extra := int(cfg(db).get("riderEscalation", [0, 1, 2])[mini(c.get("riders", []).size(), 2)])
	return { "generic": int(r.get("scraps", 2)) + extra }


static func rider_block(db: Dictionary, run: Dictionary, id: String, rider_id: String) -> String:
	var c := card(db, run, id)
	var have: Array = c.get("riders", [])
	if not riders(db).has(rider_id):
		return Str.t(db, "forge.unknown_rider")
	if have.size() >= rider_slots(db, c):
		return Str.t(db, "forge.no_slots")
	if have.has(rider_id):
		return Str.t(db, "forge.already_has")
	for pair in cfg(db).get("exclusiveRiders", []):
		if (pair as Array).has(rider_id) and (have.has(pair[0]) or have.has(pair[1])):
			return Str.t(db, "forge.exclusive")
	if bool(riders(db)[rider_id].get("singleTargetOnly", false)) and not _single_target(db, c):
		return Str.t(db, "forge.single_only")
	if not can_pay(run, rider_cost(db, c, rider_id)):
		return Str.t(db, "forge.not_enough_scraps")
	return ""


static func _single_target(db: Dictionary, c: Dictionary) -> bool:
	if not CardRules.is_spell(c):
		return true
	return str(DT.record(db, "forms", str(c.get("form", ""))).get("footprint", "")) in ["single_los", "adjacent", "first_in_line"]


## Add a rider: the card becomes its own design (riders raise its MP cost).
static func add_rider(db: Dictionary, run: Dictionary, id: String, rider_id: String) -> Dictionary:
	var err := rider_block(db, run, id, rider_id)
	if err != "":
		return { "error": err }
	var c := card(db, run, id).duplicate(true)
	pay(run, rider_cost(db, c, rider_id))
	_take(run, id)
	var rs: Array = c.get("riders", []).duplicate()
	rs.append(rider_id)
	c["riders"] = rs
	c["id"] = "rd:%s:%s" % [id, "+".join(PackedStringArray(rs))]
	c["cost"] = CardRules.cost(db, card(db, run, id)) + int(riders(db)[rider_id].get("mp", 1))
	c["costOverride"] = c["cost"]
	c["name"] = str(c.get("name", "")) + "*"
	run["cards"][str(c["id"])] = c
	run["collection"][str(c["id"])] = int(run["collection"].get(str(c["id"]), 0)) + 1
	return c

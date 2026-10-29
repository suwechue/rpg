## Relics, consumables and the backpack (user request, Oct 28; data/items.json
## and data/merchant.json). Relics are worn by one character (ch["relics"]) and
## lost if that character goes down in a fight. Consumable goods become item
## cards: in a deck (gone for good once used) or in the party's backpack
## (run["backpack"], usable by anyone in combat). The merchant sells them.
extends RefCounted

const DT := preload("res://src/core/data_tables.gd")
const Fx := preload("res://src/core/run/effects.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("merchant", {})


static func item(db: Dictionary, id: String) -> Dictionary:
	return DT.index_under(db, "items", "items").get(id, {})


static func relics(ch: Dictionary) -> Array:
	return ch.get("relics", [])


## Put a relic on a character. Returns "" or why not.
static func wear(db: Dictionary, ch: Dictionary, id: String) -> String:
	var r: Array = ch.get("relics", [])
	if r.size() >= int(cfg(db).get("relicSlots", 2)):
		return "full"
	r.append(id)
	ch["relics"] = r
	return ""


## A character went down: every relic they wore is lost. Returns the lost ids.
static func lose_relics(ch: Dictionary) -> Array:
	var lost: Array = ch.get("relics", []).duplicate()
	ch["relics"] = []
	return lost


## The merchant's stock: stockSize goods, weighted by rarity (seeded).
static func stock(db: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	var weights: Array = []
	var rw: Dictionary = cfg(db).get("rarityWeights", {})
	for it in DT.records_under(db, "items", "items"):
		if bool(it.get("merchant", false)):
			pool.append(str(it["id"]))
			weights.append(float(rw.get(str(it.get("rarity", "common")), 1)))
	var out: Array = []
	var n := mini(int(cfg(db).get("stockSize", 5)), pool.size())
	while out.size() < n:
		var total := 0.0
		for w in weights:
			total += float(w)
		var roll := rng.randf() * total
		for i in pool.size():
			roll -= float(weights[i])
			if roll <= 0.0 or i == pool.size() - 1:
				out.append(pool[i])
				pool.remove_at(i)
				weights.remove_at(i)
				break
	return out


static func price(db: Dictionary, id: String) -> int:
	return roundi(float(item(db, id).get("price", 10)) * float(cfg(db).get("priceMul", 1.0)))


## What buying needs: "relic" (pick who wears it), "deck" (pick whose deck),
## "backpack" (no pick), or "" for something the merchant doesn't sell.
static func needs(db: Dictionary, id: String) -> String:
	var it := item(db, id)
	match str(it.get("kind", "")):
		"relic":
			return "relic"
		"consumable":
			return str(it.get("use", "deck"))
		"equipment":
			return "gear"
	return ""


## Give a bought item: a relic to `ch`, an item card to `ch`'s deck, or the
## card into the backpack. Returns "" or why not ("full", "backpack_full").
static func give(db: Dictionary, run: Dictionary, ch: Dictionary, id: String) -> String:
	var it := item(db, id)
	match needs(db, id):
		"relic":
			return wear(db, ch, id)
		"deck":
			var deck: Array = ch.get("deck", [])
			deck.append(str(it.get("card", "")))
			ch["deck"] = deck
			return ""
		"gear":
			# TL Part 4: gear goes in the bag; equip it from the Equipment screen.
			Fx.add_item(run, id, 1)
			return ""
		"backpack":
			var bp: Array = run.get("backpack", [])
			if bp.size() >= int(cfg(db).get("backpackSize", 6)):
				return "backpack_full"
			bp.append(str(it.get("card", "")))
			run["backpack"] = bp
			return ""
	return "unknown"


## After a fight: consumable cards a character used leave their deck for good.
static func spend_from_deck(ch: Dictionary, used: Array) -> void:
	var deck: Array = ch.get("deck", [])
	for id in used:
		deck.erase(id)
	ch["deck"] = deck


static func spend_from_backpack(run: Dictionary, used: Array) -> void:
	var bp: Array = run.get("backpack", [])
	for id in used:
		bp.erase(id)
	run["backpack"] = bp

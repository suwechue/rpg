## Shops (data/town/shops.json): prices with the keeper's Greed and your CHA,
## buying services, cards and items, selling, and equipping gear.
class_name TownShop
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const DT := preload("res://src/core/data_tables.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")


static func shop(db: Dictionary, id: String) -> Dictionary:
	return DT.record(db, "town/shops", id)


static func rules(db: Dictionary) -> Dictionary:
	return db.get("town/shops", {}).get("rules", {})


static func item(db: Dictionary, id: String) -> Dictionary:
	return DT.record(db, "items", id)


## Entries on sale this week (fromWeek on the entry or its item).
static func stock(db: Dictionary, run: Dictionary, shop_id: String, week: int) -> Array:
	var out: Array = []
	for e in shop(db, shop_id).get("entries", []):
		var from := int(e.get("fromWeek", 0))
		if str(e.get("type", "")) == "item":
			from = maxi(from, int(item(db, str(e["item"])).get("fromWeek", 0)))
		if week >= from:
			out.append(e)
	return out


## Price = base x (1 + Greed / 200) x (1 - (CHA - 5) x 0.02), at least 1.
static func price(db: Dictionary, run: Dictionary, shop_id: String, entry: Dictionary) -> int:
	var r := rules(db)
	var keeper := str(shop(db, shop_id).get("keeper", ""))
	var greed := float(run.get("npcs", {}).get(keeper, {}).get("disposition", {}).get("greed", db.get("npcs/" + keeper, {}).get("disposition", {}).get("greed", 0)))
	var cha := float(Char.effective_stats(db, run["player"]).get("cha", 5))
	var p := float(entry.get("price", 1)) * (1.0 + greed / float(r.get("greedDivisor", 200)))
	p *= 1.0 - (cha - float(r.get("chaPivot", 5))) * float(r.get("chaStep", 0.02))
	return maxi(1, roundi(p))


static func entry_name(db: Dictionary, entry: Dictionary) -> String:
	if entry.has("name"):
		return str(entry["name"])
	match str(entry.get("type", "")):
		"item":
			return str(item(db, str(entry["item"])).get("name", entry["item"]))
		"card":
			return str(CardRules.resolve(db, str(entry["card"])).get("name", entry["card"]))
	return str(entry.get("id", "?"))


## Buy one entry. Returns { "ok": bool, "lines": [...] }.
static func buy(db: Dictionary, run: Dictionary, shop_id: String, entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not Fx.conditions_met(db, run, entry.get("cond", {}), {}):
		return { "ok": false, "lines": [str(entry.get("lockedHint", Str.t(db, "shop.not_for_you_not_yet")))] }
	var cost := price(db, run, shop_id, entry)
	if cost > int(run.get("money", 0)):
		return { "ok": false, "lines": [Str.t(db, "shop.you_can_t_afford_that") % cost] }
	run["money"] = int(run["money"]) - cost
	var lines: Array = ["-$%d" % cost]
	match str(entry.get("type", "")):
		"service":
			var fx: Dictionary = entry.get("effects", {}).duplicate()
			if bool(fx.get("healInjuries", false)):
				fx.erase("healInjuries")
				for m in run.get("roster", []):
					if int(m.get("injured", 0)) > 0:
						m["injured"] = 0
						lines.append(Str.t(db, "shop.is_patched_up") % m.get("name", "?"))
			if fx.has("hp") and int(fx["hp"]) >= 999:
				fx["hp"] = int(Char.derived(db, run["player"])["maxHp"])
			lines.append_array(Fx.apply(db, run, fx, rng, {}))
			if entry.has("say"):
				lines.push_front(str(entry["say"]))
		"card":
			var cid := str(entry["card"])
			run["collection"][cid] = int(run["collection"].get(cid, 0)) + 1
			var deck: Array = run["player"]["deck"]
			if deck.size() < Char.deck_max(db, run["player"]) and deck.count(cid) < int(db.get("leveling", {}).get("maxCopies", 3)):
				deck.append(cid)
				lines.append(Str.t(db, "shop.added_to_your_deck") % entry_name(db, entry))
			else:
				lines.append(Str.t(db, "shop.added_to_your_collection") % entry_name(db, entry))
		"item":
			var iid := str(entry["item"])
			Fx.add_item(run, iid, 1)
			lines.append(Str.t(db, "shop.got") % entry_name(db, entry))
			var it := item(db, iid)
			if str(it.get("kind", "")) == "equipment" and run["player"]["equipment"].get(str(it.get("slot", ""))) == null:
				equip(db, run, run["player"], iid)
				lines.append(Str.t(db, "shop.equipped"))
	return { "ok": true, "lines": lines }


static func sell_price(db: Dictionary, item_id: String) -> int:
	return maxi(1, roundi(float(item(db, item_id).get("price", 2)) * float(rules(db).get("sellShare", 0.5))))


static func sell(db: Dictionary, run: Dictionary, item_id: String) -> int:
	if int(run.get("inventory", {}).get(item_id, 0)) <= 0:
		return 0
	Fx.add_item(run, item_id, -1)
	var p := sell_price(db, item_id)
	run["money"] = int(run["money"]) + p
	return p


## Put an owned item in its slot; the old one goes back to the inventory.
static func equip(db: Dictionary, run: Dictionary, ch: Dictionary, item_id: String) -> String:
	var it := item(db, item_id)
	if str(it.get("kind", "")) != "equipment":
		return Str.t(db, "shop.you_can_t_equip_that")
	if int(run.get("inventory", {}).get(item_id, 0)) <= 0:
		return Str.t(db, "shop.you_don_t_have_it")
	var slot := str(it.get("slot", ""))
	var old: Variant = ch["equipment"].get(slot)
	Fx.add_item(run, item_id, -1)
	if old != null:
		Fx.add_item(run, str(old), 1)
	ch["equipment"][slot] = item_id
	Char.clamp_pools(db, ch)
	return ""


static func unequip(db: Dictionary, run: Dictionary, ch: Dictionary, slot: String) -> void:
	var old: Variant = ch["equipment"].get(slot)
	if old != null:
		Fx.add_item(run, str(old), 1)
		ch["equipment"][slot] = null
		Char.clamp_pools(db, ch)

## New cards in the story (user request, Oct 29; data/story/card_rewards.json):
## a pick of 3 after you climb out of the Upside-Down (a better one after a
## boss), a rare pick for each mystery deduction, and the library's weekly card
## shelf. Offers reuse the arena's pool (src/core/arena/arena.gd card_offer):
## cards someone in the party can use, leaning to their Vectors and synergies.
extends RefCounted

const Arena := preload("res://src/core/arena/arena.gd")
const CardRules := preload("res://src/core/card.gd")
const Fx := preload("res://src/core/run/effects.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("story/card_rewards", {})


## The arena wave a story week counts as (minWave gates and rarity), plus a bonus.
static func wave_for(db: Dictionary, week: int, bonus: int = 0) -> int:
	var w: Array = cfg(db).get("waveForWeek", [0, 5, 10, 15, 20, 25])
	return int(w[clampi(week, 0, w.size() - 1)]) + bonus


static func party(run: Dictionary) -> Array:
	var out: Array = [run.get("player", {})]
	for m in run.get("roster", []):
		out.append(m)
	return out


## Up to 3 card ids for a source ("floor", "boss", "deduction"), seeded by the
## run, the day and the source so a reload offers the same cards.
static func offer(db: Dictionary, run: Dictionary, week: int, source: String) -> Array:
	var src: Dictionary = cfg(db).get("sources", {}).get(source, {})
	var seed_arena := { "seed": hash("%d:%d:%s" % [int(run.get("seed", 0)), int(run.get("day_count", 0)), source]) }
	return Arena.card_offer(db, seed_arena, party(run), wave_for(db, week, int(src.get("bonus", 0))))


## Money for skipping a pick.
static func skip_money(db: Dictionary, source: String) -> int:
	return int(cfg(db).get("sources", {}).get(source, {}).get("skipMoney", 0))


## Take a card: it waits in pendingCards until you choose whose deck (Flow).
static func take(run: Dictionary, id: String) -> void:
	run["pendingCards"] = run.get("pendingCards", []) + [id]


static func skip(db: Dictionary, run: Dictionary, source: String) -> int:
	var m := skip_money(db, source)
	run["money"] = int(run.get("money", 0)) + m
	return m


## The library shelf this week: [{ id, price }], minus what you bought.
static func shelf(db: Dictionary, run: Dictionary, week: int) -> Array:
	var sc: Dictionary = cfg(db).get("shelf", {})
	var seed_arena := { "seed": hash("%d:shelf:%d" % [int(run.get("seed", 0)), week]) }
	var ids: Array = Arena.card_offer(db, seed_arena, party(run), wave_for(db, week, int(sc.get("bonus", 0))))
	var bought: Array = run.get("shelfBought", {}).get(str(week), [])
	var out: Array = []
	for id in ids.slice(0, int(sc.get("size", 3))):
		if bought.has(str(id)):
			continue
		var rarity := str(CardRules.resolve(db, str(id)).get("rarity", "common"))
		out.append({ "id": str(id), "price": int(sc.get("prices", {}).get(rarity, 20)) })
	return out


## Buy from the shelf. Returns "" or "money" / "gone".
static func buy(db: Dictionary, run: Dictionary, week: int, id: String) -> String:
	for e in shelf(db, run, week):
		if str(e["id"]) != id:
			continue
		if int(run.get("money", 0)) < int(e["price"]):
			return "money"
		run["money"] = int(run.get("money", 0)) - int(e["price"])
		var sb: Dictionary = run.get("shelfBought", {})
		sb[str(week)] = sb.get(str(week), []) + [id]
		run["shelfBought"] = sb
		take(run, id)
		return ""
	return "gone"

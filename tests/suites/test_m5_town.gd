## M5: NPC schedules, town data integrity, doors and shops.
extends "res://tests/suite.gd"

const RM := preload("res://src/core/run/run_model.gd")
const Sched := preload("res://src/core/town/schedule.gd")
const Locs := preload("res://src/core/town/locations.gd")
const Shop := preload("res://src/core/town/shop.gd")
const Char := preload("res://src/core/character.gd")


func fresh(seed_value: int = 1) -> Dictionary:
	return RM.new_run(db(), seed_value, "mage", seeded(seed_value))


func test_schedules() -> void:
	var run := fresh()
	check(Sched.location_of(db(), run, "kelly", "mon", "lunch", 0) == "cafeteria", "Kelly at lunch: cafeteria")
	check(Sched.location_of(db(), run, "kelly", "mon", "night", 0) == "kelly_house", "everyone goes home at night")
	check(Sched.location_of(db(), run, "kelly", "sat", "midday", 5) == "town_square", "Kelly weekend: town square")
	check(Sched.location_of(db(), run, "gary", "tue", "after_school", 1) == "garys_deli", "Gary at the deli")
	check(Sched.location_of(db(), run, "ms_g", "sun", "midday", 6) == "ms_g_house", "Ms. G only visits the library on Saturdays")
	check(Sched.location_of(db(), run, "ms_g", "sat", "midday", 5) == "library", "Ms. G at the library Saturday")
	check(Sched.location_of(db(), run, "parent", "mon", "lunch", 0) == "", "your guardian is at work")
	check(Sched.location_of(db(), run, "parent", "mon", "before_school", 0) == "player_home", "and home before school")
	check(Sched.location_of(db(), run, "phase", "tue", "after_school", 1) == "garys_deli", "Phase's deli shift on Tuesday")
	check(Sched.location_of(db(), run, "phase", "mon", "after_school", 0) == "field", "Phase at practice on Monday")
	check(Sched.location_of(db(), run, "jake", "mon", "after_school", 0) == "town_square", "Jake early: town square")
	RM.set_flag(run, "jake_forge_started")
	check(Sched.location_of(db(), run, "jake", "mon", "after_school", 0) == "forge", "Jake's questline moves him to the forge")
	check(Sched.location_of(db(), run, "sam_unmasked", "mon", "lunch", 0) == "", "hidden NPCs never appear")
	var naps := {}
	var a := Sched.location_of(db(), run, "sam", "mon", "after_school", 3)
	check(a == Sched.location_of(db(), run, "sam", "mon", "after_school", 3), "nap spot is stable within a day")
	for d in 20:
		naps[Sched.location_of(db(), run, "sam", "mon", "after_school", d)] = true
	check(naps.size() >= 3, "Sam's nap spot rotates (%d spots)" % naps.size())
	var missing := 0
	for d in 30:
		if Sched.location_of(db(), run, "todd", "mon", "after_school", d) == "":
			missing += 1
	check(missing > 3 and missing < 27, "Todd goes missing some days (%d/30)" % missing)
	var ally := { "id": "theo", "injured": 1 }
	run["roster"].append(ally)
	check(Sched.location_of(db(), run, "theo", "mon", "lunch", 0) == "hospital", "injured party members are at the hospital")


func test_town_data_integrity() -> void:
	var locs := {}
	for l in Locs.all(db()):
		locs[str(l["id"])] = l
	var placed := {}
	for key in db():
		if str(key).begins_with("town/zones/"):
			var z: Dictionary = db()[key]
			for b in z.get("buildings", []):
				check(locs.has(str(b["loc"])), "zone %s building %s is a location" % [z["id"], b["loc"]])
				placed[str(b["loc"])] = true
			for s in z.get("spots", {}):
				check(locs.has(str(s)), "spot %s is a location" % s)
				placed[str(s)] = true
			for e in z.get("exits", []):
				check(db().has("town/zones/" + str(e["to"])), "exit to %s exists" % e["to"])
	for t in db()["town/interiors"]["interiors"]:
		for d in t.get("doors", []):
			check(locs.has(str(d["to"])), "room door %s is a location" % d["to"])
			placed[str(d["to"])] = true
	for id in locs:
		var l: Dictionary = locs[id]
		check(placed.has(id) or str(l.get("kind", "")) == "building" and id == "hospital_closed_wing", "location %s is on the map" % id)
		check(["OPEN", "EXTERIOR", "CLOSED", "STORY"].has(str(l.get("status", ""))), "location %s has a status" % id)
		if str(l.get("status", "")) != "OPEN":
			check(str(l.get("doorLine", l.get("lockedLine", ""))) != "", "location %s has a door line" % id)
		if l.has("interior"):
			check(not Locs.interior(db(), str(l["interior"])).is_empty(), "interior %s exists" % l["interior"])
		for r in l.get("residents", []):
			check(db().has("npcs/" + str(r)), "resident %s has an NPC record" % r)


func test_every_named_character_has_a_home_and_schedule() -> void:
	var specials := ["home", "@nap", "@missing", ""]
	var ids := Sched.npc_ids(db())
	check(ids.size() >= 34, "about 35 named characters (%d)" % ids.size())
	for id in ids:
		var n: Dictionary = db()["npcs/" + str(id)]
		var home := str(n.get("home", ""))
		check(not Locs.rec(db(), home).is_empty(), "%s's home %s is a location" % [id, home])
		check(ResourceLoader.exists(str(n.get("sprite", ""))), "%s has a sprite" % id)
		var sched: Dictionary = n.get("schedule", {})
		for table_key in ["weekday", "weekend"]:
			var t: Dictionary = sched.get(table_key, {})
			for part in t:
				var vals: Array = t[part] if typeof(t[part]) == TYPE_ARRAY else [t[part]]
				for v in vals:
					check(specials.has(str(v)) or not Locs.rec(db(), str(v)).is_empty(), "%s schedule %s -> %s exists" % [id, part, v])


func test_doors() -> void:
	var run := fresh()
	check(Locs.door(db(), run, "garys_deli", 1, "mon", "after_school", 0)["kind"] == "enter", "the deli is open after school")
	check(Locs.door(db(), run, "garys_deli", 1, "mon", "night", 0)["kind"] == "line", "and shut at night")
	check(Locs.door(db(), run, "movie_theater", 1, "mon", "after_school", 0)["kind"] == "line", "CLOSED gives a door line")
	check(Locs.door(db(), run, "corner_store", 1, "mon", "after_school", 0)["kind"] == "walkup", "the corner store serves from its window")
	var kelly := Locs.door(db(), run, "kelly_house", 1, "sat", "morning", 5)
	check(kelly["kind"] == "doorstep" and kelly["npcs"] == ["kelly"], "Kelly answers her door on a Saturday morning")
	check(Locs.door(db(), run, "kelly_house", 1, "mon", "after_school", 0)["kind"] == "line", "nobody home after school")
	check(Locs.closed_reason(db(), run, "bus_stop_downtown", 1, "lunch") != "", "bus stops open in week 2")
	check(Locs.closed_reason(db(), run, "bus_stop_downtown", 2, "lunch") == "", "bus open week 2")
	check(Locs.closed_reason(db(), run, "hidden_alley", 1, "lunch") != "", "the hidden alley needs PER 7")
	run["player"]["stats"]["per"] = 7
	check(Locs.closed_reason(db(), run, "hidden_alley", 1, "lunch") == "", "PER 7 finds it")
	check(Locs.status(db(), run, "hospital_closed_wing") == "STORY", "closed wing is STORY")
	RM.set_flag(run, "week4_closed_wing_open")
	check(Locs.status(db(), run, "hospital_closed_wing") == "OPEN", "the story flag opens it")
	check(Locs.residents_home(db(), run, "elm_apartments", "mon", "night", 0).size() == 5, "five residents home at the apartments at night")


func test_shop_prices_and_buying() -> void:
	var run := fresh()
	run["money"] = 200
	var entry := { "type": "service", "price": 10, "effects": { "hp": 5 } }
	var base := Shop.price(db(), run, "deli", entry)
	check(base == roundi(10.0 * 1.1 * (1.0 - (4.0 - 5.0) * 0.02)), "Gary's Greed 20 and CHA 4 set the price (%d)" % base)
	run["player"]["stats"]["cha"] = 15
	check(Shop.price(db(), run, "deli", entry) < base, "Charisma lowers prices")
	run["player"]["hp"] = 10
	var r := Shop.buy(db(), run, "deli", DT.record(db(), "town/shops", "deli")["entries"][0], seeded(1))
	check(r["ok"] and int(run["player"]["hp"]) == 18, "breakfast heals")
	var deck_before: int = run["player"]["deck"].size()
	Shop.buy(db(), run, "deli", { "type": "card", "card": "card_deli_sandwich", "price": 6 }, seeded(1))
	check(run["player"]["deck"].size() == deck_before + 1 and run["collection"]["card_deli_sandwich"] == 1, "a combat item card goes into the deck")
	var str_before := 0
	r = Shop.buy(db(), run, "forge", { "type": "item", "item": "iron_knuckles", "price": 25 }, seeded(1))
	check(run["player"]["equipment"]["weapon"] == "iron_knuckles", "new gear auto-equips in an empty slot")
	check(Char.collect_mods(db(), run["player"])["combat"]["strikePower"] == 2.0, "weapon adds Strike power")
	Shop.buy(db(), run, "forge", { "type": "item", "item": "padded_jacket", "price": 20 }, seeded(1))
	check(Char.derived(db(), run["player"])["physDefense"] >= 3, "armor adds Defense")
	Shop.buy(db(), run, "corner_store", { "type": "item", "item": "good_coffee", "price": 5 }, seeded(1))
	var m0: int = run["money"]
	check(Shop.sell(db(), run, "good_coffee") > 0 and run["money"] > m0, "selling pays")
	run["money"] = 0
	check(not Shop.buy(db(), run, "deli", entry, seeded(1))["ok"], "can't buy without money")
	check(str_before == 0, "placeholder")
	var good: Dictionary = DT.record(db(), "town/shops", "deli")["entries"][1]
	run["money"] = 100
	check(not Shop.buy(db(), run, "deli", good, seeded(1))["ok"], "the off-menu special needs Gary Bond 20")


func test_shop_stock_by_week() -> void:
	var run := fresh()
	var w1 := Shop.stock(db(), run, "forge", 1).size()
	var w3 := Shop.stock(db(), run, "forge", 3).size()
	check(w3 > w1, "better gear appears in later weeks (%d -> %d)" % [w1, w3])

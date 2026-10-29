## AC: the Arena Campfire's stations, tickets, deli, meals, training and talk.
extends "res://tests/suite.gd"

const Camp := preload("res://src/core/arena/camp.gd")
const Arena := preload("res://src/core/arena/arena.gd")
const Char := preload("res://src/core/character.gd")


func test_stations_and_upgrades() -> void:
	var kinds: Array = Camp.stations(db(), false).map(func(s: Dictionary) -> String: return str(s["kind"]))
	for k in ["campfire", "companions", "deli", "workbench", "rack", "blacksmith", "training", "gate"]:
		check(kinds.has(k), "the camp has a %s" % k)
	check(not kinds.has("home") and Camp.stations(db(), true).any(func(s: Dictionary) -> bool: return s["kind"] == "home"), "the path home is story-only")
	check(Camp.upgrades(db(), 5).is_empty() and Camp.upgrades(db(), 20).size() == 2, "the camp grows with depth")
	check(Camp.zone(db(), 30)["props"].size() > Camp.zone(db(), 5)["props"].size(), "upgrades add props")


func test_tickets_and_deli() -> void:
	check(Camp.tickets_for(db(), true, false, false) > Camp.tickets_for(db(), false, true, false) and Camp.tickets_for(db(), false, false, true) > Camp.tickets_for(db(), false, false, false), "bosses, elites and clean waves pay more")
	var arena := { "tickets": 20, "wave": 10 }
	var run := {}
	check(Camp.buy(db(), arena, run, "snack_sandwich") == "" and run["backpack"] == ["card_potion_heal"], "a snack goes in the backpack")
	check(Camp.buy(db(), arena, run, "meal_runner") == "" and arena["meal"]["id"] == "meal_runner", "a meal is active")
	check(Camp.buy(db(), arena, run, "meal_hero") == "" and arena["meal"]["id"] == "meal_hero", "one meal at a time")
	check(Camp.meal_mutators(arena).size() == 1, "the meal joins the fights' mutators")
	arena["tickets"] = 0
	check(Camp.buy(db(), arena, run, "snack_soda") == "tickets", "tickets are needed")
	check(Camp.stock(db(), 5, seeded(1)).all(func(i: String) -> bool: return int(Camp.item(db(), i).get("minWave", 0)) <= 5), "early stock skips deep items")


func test_meal_in_combat() -> void:
	const StateScript := preload("res://src/core/combat/combat_state.gd")
	var ch := Char.create(db(), "fighter", seeded(1), { "isPlayer": true })
	var base := StateScript.new(db(), seeded(2), { "layout": { "map": ["P..E"] }, "party": [{ "char": ch.duplicate(true) }], "enemies": [DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)] })
	var fed := StateScript.new(db(), seeded(2), { "layout": { "map": ["P..E"] }, "party": [{ "char": ch.duplicate(true) }], "enemies": [DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)],
		"mutators": [{ "id": "meal", "effects": { "partyMaxHpPct": 0.1, "partyMovement": 1 } }] })
	check(fed.units[0].max_hp > base.units[0].max_hp, "the Hero Sub raises max HP")
	check(fed.move_budget(fed.units[0]) == base.move_budget(base.units[0]) + 1, "the Runner's Wrap adds Movement")


func test_training() -> void:
	var ch := Char.create(db(), "mage", seeded(1), { "isPlayer": true })
	var arena := { "ap": 5, "wave": 5 }
	var s0 := int(ch["stats"]["str"])
	check(int(Camp.train(db(), arena, ch, "str", 0.9)["gain"]) == 1 and int(ch["stats"]["str"]) == s0 + 1 and int(arena["ap"]) == 4, "training costs 1 AP and raises the stat")
	check(Camp.train(db(), arena, ch, "str", 0.9)["why"] == "used", "once per member per camp")
	arena["wave"] = 10
	check(int(Camp.train(db(), arena, ch, "str", 0.1)["gain"]) == 0, "a poor score gains nothing")
	arena["trainGains"] = { str(ch["id"]): 3 }
	arena["wave"] = 15
	check(Camp.train(db(), arena, ch, "str", 1.0)["why"] == "cap", "capped per run")


func test_talk() -> void:
	var arena := {}
	var member := { "id": "dex", "class": "rogue" }
	var seen := {}
	for i in 6:
		seen[Camp.talk_line(db(), arena, member, {}, seeded(i))] = true
	check(seen.size() >= 4, "no repeats until the lines run out (%d different)" % seen.size())
	var hit := Camp.talk_line(db(), {}, member, { "bestHit": true }, seeded(1))
	check(hit.contains("hit"), "reaction lines come first when they fit: %s" % hit)

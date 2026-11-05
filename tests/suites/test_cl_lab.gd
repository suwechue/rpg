## Combat Lab (docs/COMBAT_LAB.md): the Rules view, presets, Lab setups, logs.
extends "res://tests/suite.gd"

const Rules := preload("res://src/core/combat/rules.gd")
const Setup := preload("res://src/core/lab/lab_setup.gd")
const FightLog := preload("res://src/core/lab/fight_log.gd")
const Report := preload("res://src/core/lab/lab_report.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const UP := preload("res://src/core/user_paths.gd")


func test_every_lever_has_a_default_and_a_type() -> void:
	var seen := {}
	for s in Rules.lever_specs(db()):
		var id := str(s.get("id", ""))
		check(id != "" and not seen.has(id), "lever id %s is unique" % id)
		seen[id] = true
		check(s.has("default") and s.has("group") and s.has("name"), "%s has a default, group and name" % id)
		var type := str(s.get("type", ""))
		check(type in ["bool", "int", "float", "enum"], "%s has a known type" % id)
		match type:
			"bool":
				check(s["default"] is bool, "%s default is a bool" % id)
			"enum":
				check(s.get("options", []).has(s["default"]), "%s default is one of its options" % id)
			_:
				check(s["default"] is float or s["default"] is int, "%s default is a number" % id)
	check(seen.size() >= 50, "the Lab has its levers")


func test_presets_only_name_real_levers() -> void:
	var known := {}
	for s in Rules.lever_specs(db()):
		known[str(s["id"])] = true
	for p in Rules.presets(db()):
		for k in p.get("levers", {}):
			check(known.has(str(k)), "preset %s: %s is a lever" % [p["id"], k])
		for k in p.get("fromGame", {}):
			check(known.has(str(k)), "preset %s: fromGame %s is a lever" % [p["id"], k])


func test_rules_view() -> void:
	var cur: RefCounted = Rules.build(db())
	check(cur.preset == "current" and cur.is_current(), "no preset means today's rules")
	check(cur.count("handSize") == int(db()["stats"]["combat"]["drawUpTo"]), "current reads the hand size from the game's data")
	check(cur.count("collisionDamage") == int(db()["stats"]["combat"]["collisionDamage"]), "and collision damage")
	var base: RefCounted = Rules.build(db(), "cl_base")
	check(base.count("actionsPerTurn") == 1 and base.flag("moveSeparate") and base.count("handSize") == 4, "cl_base has the Part 2 defaults")
	var over: RefCounted = Rules.build(db(), "cl_base", { "handSize": 6 })
	check(over.count("handSize") == 6 and over.changed.has("handSize"), "changes sit on top of the preset")
	over.queue("handSize", 2)
	check(over.count("handSize") == 6 and over.has_queued(), "a mid-fight change waits")
	check(over.apply_queued().has("handSize") and over.count("handSize") == 2, "and applies when asked")
	check(not Rules.diff(Rules.values_for(db(), "current"), Rules.values_for(db(), "cl_base")).is_empty(), "the presets differ")


func test_fights_and_presets_are_complete() -> void:
	var ids: Array = Setup.fights(db()).map(func(f: Dictionary) -> String: return str(f["id"]))
	for id in ["ledge_day", "hold_the_line", "thin_ice", "fire_sale", "hand_off", "the_ritual", "crowded_hall", "hollow_mascot", "night_market", "bell_tower", "flood_drill", "duet"]:
		check(ids.has(id), "fight %s exists" % id)
	var pids: Array = Rules.presets(db()).map(func(p: Dictionary) -> String: return str(p["id"]))
	for id in ["current", "cl_base", "cl_puzzle", "cl_cards", "cl_brutal", "cl_plus", "cl_everything"]:
		check(pids.has(id), "preset %s exists" % id)
	check(Rules.values_for(db(), "cl_brutal")["hitHardRarely"] == true and int(Rules.values_for(db(), "cl_brutal")["roundCap"]) == 6, "Brutal hits hard, cap 6")
	check(int(Rules.values_for(db(), "cl_cards")["handSize"]) == 5, "Cards has a hand of 5")
	for f in Setup.fights(db()):
		var built := Setup.build(db(), str(f["id"]), "cl_base")
		var st: Object = StateScript.new(db(), seeded(1), built["setup"])
		check(st.units.filter(func(u: Object) -> bool: return u.team == "enemy").size() == f["enemies"].size(), "%s: every enemy is on the map" % f["id"])
		check(st.units.filter(func(u: Object) -> bool: return u.team == "party" and not bool(u.source.get("object", false))).size() == f["party"].size(), "%s: everyone in the party is on the map" % f["id"])
		var cells := {}
		for u in st.units:
			check(st.grid.in_bounds(u.cell) and not cells.has(u.cell), "%s: %s has its own tile" % [f["id"], u.id])
			cells[u.cell] = true
		for e in f["enemies"]:
			var eid := str(e.get("id", "") if typeof(e) == TYPE_DICTIONARY else e)
			check(DT.index_under(db(), "enemies/", "enemies").has(eid), "%s: %s exists" % [f["id"], eid])
	check(Setup.build(db(), "duet", "cl_base")["setup"]["levers"]["duetCards"] == true, "a fight's suggested levers apply")
	check(not Setup.build(db(), "duet", "current")["setup"]["levers"].has("duetCards"), "but not under current")


func test_lab_setup_never_touches_a_save_and_runs() -> void:
	var f: Dictionary = Setup.fights(db())[0]
	var built := Setup.build(db(), str(f["id"]), "cl_base")
	check(str(built["run"]["mode"]) == "lab", "the Lab plays in a throwaway run")
	var st: Object = StateScript.new(db(), seeded(int(built["setup"]["seed"])), built["setup"])
	check(st.rules.preset == "cl_base" and st.lab_log != null, "the fight knows its preset and keeps a log")
	check(st.units.filter(func(u: Object) -> bool: return u.team == "enemy").size() > 0, "it has enemies")


func test_lab_log_writes_one_line_per_fight() -> void:
	check(UP.sandboxed(), "tests write to the sandbox")
	var dir := UP.of("lab/")
	if FileAccess.file_exists(FightLog.path()):
		DirAccess.remove_absolute(FightLog.path())
	var log := FightLog.new("ledge_day", 7, ["fighter:3"], "cl_base", { "handSize": 4 })
	log.begin_turn("player", 1, ["card_strike", "strike"])
	log.played("card_strike")
	log.observe({ "t": "push" })
	log.observe({ "t": "board_kill" })
	log.observe({ "t": "combo" })
	log.observe({ "t": "damage", "toParty": true, "telegraphed": true, "amount": 3, "absorbed": 1 })
	log.observe({ "t": "damage", "toParty": true, "amount": 2 })
	check(FightLog.append(log.line("win", 3, { "fun": 4, "clever": true })), "the line saves")
	var log2 := FightLog.new("ledge_day", 7, [], "current", {})
	check(FightLog.append(log2.line("lose", 9)), "a second line saves")
	var text := FileAccess.get_file_as_string(FightLog.path())
	check(text.split("\n", false).size() == 2, "one line per fight")
	var lines := FightLog.read_all(dir)
	check(lines.size() == 2 and int(lines[0]["boardKills"]) == 1 and int(lines[0]["telegraphedDamage"]) == 4 and int(lines[0]["untelegraphedDamage"]) == 2, "every line is valid JSON with its counts")
	var sum := Report.summarize(lines + [{ "kind": "ab", "pick": "cl_base" }])
	check(int(sum["cl_base"]["fights"]) == 1 and float(sum["cl_base"]["fun"]) == 4.0 and int(sum["cl_base"]["abWins"]) == 1, "the report sums per preset")
	check(float(sum["current"]["fun"]) < 0.0 and Report.table(sum).contains("cl_base"), "unrated fights show no fun score")
	DirAccess.remove_absolute(FightLog.path())

## TL (docs/TOWN_LIFE.md): the town during school hours, getting caught,
## favors and events, gear, social gaps, combat stubs, polish.
extends "res://tests/suite.gd"

const Locs := preload("res://src/core/town/locations.gd")
const Sched := preload("res://src/core/town/schedule.gd")
const Crowd := preload("res://src/core/town/crowd.gd")
const RM := preload("res://src/core/run/run_model.gd")


func run_() -> Dictionary:
	return RM.new_run(db(), 5, "mage", seeded(5))


## Part 1: a skipped period has places open and people around.
func test_school_hours() -> void:
	check(Locs.expand_hours(db(), ["@schoolHours", "lunch"]) == ["period_1", "period_2", "period_3", "lunch"], "the @schoolHours alias expands")
	var run := run_()
	for part in ["period_1", "period_2", "period_3"]:
		var open := 0
		for l in db()["town/locations"]["locations"]:
			if str(l.get("zone", "")) != "school" and Locs.closed_reason(db(), run, str(l["id"]), 2, part) == "":
				open += 1
		check(open >= 6, "%s: %d places open in town" % [part, open])
		var people := 0
		for id in Sched.npc_ids(db()):
			var loc := Sched.location_of(db(), run, str(id), "tue", part, 8)
			if loc != "" and str(Locs.rec(db(), loc).get("zone", "")) != "school" and not loc.ends_with("_house") and loc != "elm_apartments":
				people += 1
		for zone in ["downtown", "residential", "outskirts"]:
			people += Crowd.generate(db(), run, zone, part, 2, seeded(1)).size()
		check(people >= 8, "%s: %d people around" % [part, people])
	var daytime := 0
	for l in db()["town/locations"]["locations"]:
		for a in l.get("activities", []):
			if bool(a.get("daytime", false)):
				daytime += 1
	check(daytime >= 4, "at least 4 daytime-only activities (%d)" % daytime)
	for id in ["officer_pruitt", "rae", "walt", "mo", "mr_ellis"]:
		check(not db().get("npcs/" + id, {}).is_empty(), "%s exists" % id)


## Part 2: getting caught, parent trust, patrol cones, the attendance streak.
func test_truancy() -> void:
	const Tr := preload("res://src/core/town/truancy.gd")
	var run := run_()
	var square := Tr.risk(db(), run, "town_square", [])
	var alley := Tr.risk(db(), run, "hidden_alley", [])
	check(square > alley, "the square is riskier than the alley")
	check(Tr.risk(db(), run, "park", ["officer_pruitt"]) > Tr.risk(db(), run, "park", []), "Officer Pruitt nearby raises the risk")
	run["skips_week"] = 3
	check(Tr.risk(db(), run, "hidden_alley", []) > alley, "more skips, more risk")
	check(Tr.label(db(), 0.05) == "low" and Tr.label(db(), 0.6) == "high", "risk labels")
	var r := Tr.resolve(db(), run, "take", 5, 0.0, seeded(1))
	check(not r["free"] and run["detention_pending"] and Tr.trust(db(), run) == 40, "taking it: detention and a call home")
	var ran := Tr.resolve(db(), run_(), "run", 5, 0.9, seeded(1))
	check(ran["free"], "a good chase gets away")
	var frees := 0
	for i in 40:
		if Tr.resolve(db(), run_(), "talk", 12, 0.0, seeded(i))["free"]:
			frees += 1
	check(frees > 20, "high Charisma usually talks its way out (%d of 40)" % frees)
	var cov := run_()
	cov["flags"]["ellis_covers"] = true
	check(Tr.resolve(db(), cov, "take", 5, 0.0, seeded(1))["key"] == "truancy.covered", "Mr. Ellis covers for you once")
	var low := run_()
	Tr.change_trust(db(), low, -30)
	check(Tr.night_ap_delta(db(), low) == -1 and low["texts"].any(func(t: Dictionary) -> bool: return t["from"] == "parent"), "low trust: a curfew and a text home")
	var high := run_()
	Tr.change_trust(db(), high, 30)
	check(Tr.allowance(db(), high) > 0, "high trust: an allowance")
	var cone := Tr.cone(db(), Vector2i(5, 4), Vector2i.RIGHT, { Vector2i(8, 4): true })
	check(cone.has(Vector2i(6, 4)) and cone.has(Vector2i(7, 5)) and not cone.has(Vector2i(8, 4)), "patrol cones widen and walls stop them")
	var good := run_()
	good["attendance_week"] = { "physics": 3 }
	var st0 := int(good["player"]["stats"]["int"])
	check(Tr.week_end(db(), good) != "", "a perfect week gives a stat")
	check(Locs.closed_reason(db(), run_(), "hallways", 2, "period_2") == "", "the hallways can be snuck into during class")


## Part 3: town events, the favor board, opened places, visitable houses.
func test_town_content() -> void:
	const Fav := preload("res://src/core/town/favors.gd")
	check(db()["story/town_events"]["stories"].size() >= 15, "at least 15 town events (%d)" % db()["story/town_events"]["stories"].size())
	for s in db()["story/town_events"]["stories"]:
		var ev: Dictionary = s["steps"][0].get("event", {})
		check(ev.get("choices", []).size() >= 2, "%s has a choice" % s["id"])
	check(Fav.all(db()).size() >= 15, "at least 15 favors")
	var run := run_()
	var b1 := Fav.board(db(), run, 2, seeded(1))
	check(b1.size() == int(db()["town/favors"]["perWeek"]) and Fav.board(db(), run, 2, seeded(9)) == b1, "the board is posted once a week")
	Fav.board(db(), run, 3, seeded(2))
	check(int(run["favorBoard"]["week"]) == 3 and run["favorBoard"]["done"].is_empty(), "a new week posts a fresh board")
	var run2 := run_()
	var board2 := Fav.board(db(), run2, 2, seeded(1))
	Fav.complete(run2, str(board2[0]))
	check(not Fav.board(db(), run2, 2, seeded(1)).has(str(board2[0])), "a done favor comes off the board")
	var opened := 0
	for id in ["train_station", "town_museum", "movie_theater"]:
		if str(Locs.rec(db(), id).get("status", "")) == "OPEN":
			opened += 1
	check(opened == 3, "the station, museum and theater are open")
	check(Locs.closed_reason(db(), run_(), "train_station", 2, "after_school") != "" and Locs.closed_reason(db(), run_(), "train_station", 3, "after_school") == "", "the station opens in week 3")
	var houses := 0
	for l in db()["town/locations"]["locations"]:
		if l.has("visitBond"):
			houses += 1
	check(houses >= 4, "at least 4 visitable houses (%d)" % houses)
	var friend := run_()
	check(Locs.door(db(), friend, "theo_house", 2, "tue", "after_school", 3)["kind"] != "enter", "a stranger's house stays shut")
	friend["bonds"]["theo"] = 50.0
	check(Locs.door(db(), friend, "theo_house", 2, "tue", "after_school", 3)["kind"] == "enter", "at Friend Bond you can visit")


## Part 4: gear.
func test_gear() -> void:
	const Gear := preload("res://src/core/items/gear.gd")
	const Fx := preload("res://src/core/run/effects.gd")
	const Char := preload("res://src/core/character.gd")
	const StateScript := preload("res://src/core/combat/combat_state.gd")
	var run := run_()
	var ch: Dictionary = run["player"]
	check(Gear.slots(db(), ch).size() == 3, "three slots at level 1")
	ch["level"] = 6
	check(Gear.slots(db(), ch).has("trinket2"), "a second trinket at level 6")
	ch["level"] = 1
	var mv0 := int(Char.derived(db(), ch)["movement"])
	Fx.add_item(run, "windbreaker", 1)
	check(Gear.compare(db(), run, ch, "windbreaker")["movement"] == 1, "the compare shows light armor's Movement")
	check(Gear.equip(db(), run, ch, "windbreaker") == "" and int(Char.derived(db(), ch)["movement"]) == mv0 + 1, "light armor: +1 Movement")
	Fx.add_item(run, "football_pads", 1)
	Gear.equip(db(), run, ch, "football_pads")
	check(int(Char.derived(db(), ch)["movement"]) == mv0 - 1 and int(ch["gearStats"]["guardShield"]) > 0, "heavy armor: -1 Movement, a bigger Guard")
	check(int(run["inventory"].get("windbreaker", 0)) == 1, "the old piece goes back in the bag")
	Fx.add_item(run, "insulated_coat", 1)
	Gear.equip(db(), run, ch, "insulated_coat")
	check(int(ch["gearStats"]["resist"].get("cold", 0)) == 25, "the Insulated Coat resists Cold")
	Fx.add_item(run, "broom_spear", 1)
	Gear.equip(db(), run, ch, "broom_spear")
	check(int(ch["gearStats"]["weapon"]["reach"]) == 2, "a spear reaches 2")
	var st := StateScript.new(db(), seeded(1), { "layout": { "map": ["P.E."] }, "party": [{ "char": ch }], "enemies": [DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)] })
	var me = st.unit_by_id("player")
	check(st.card_targets(me, { "action": "strike", "builtin": true }).size() == 1, "Strike reaches the enemy 2 tiles away")
	# Forging, upgrades, infusion, durability.
	run["money"] = 500
	Fx.add_item(run, "ore_iron", 10)
	Fx.add_item(run, "ore_ember", 2)
	var rec: Dictionary = db()["gear_recipes"]["recipes"][0]
	check(Gear.forge(db(), run, rec, 0.9) == "" and int(Gear.state(run, str(rec["item"]))["level"]) == 1, "a great hammer score forges a +1 piece")
	check(Gear.upgrade(db(), run, "broom_spear") == "" and int(Gear.state(run, "broom_spear")["level"]) == 1, "upgrade to +1")
	check(Gear.infuse(db(), run, "broom_spear", "heat", "ore_ember") == "" and Gear.state(run, "broom_spear")["infusion"] == "heat", "infuse Heat with ember iron")
	check(Gear.infuse(db(), run, "broom_spear", "cold", "ore_ember") != "", "ember iron can't infuse Cold")
	for i in 3:
		Gear.wear_down(db(), run, ch)
	check(Gear.broken(db(), run, "broom_spear"), "going down three times breaks it")
	check(Gear.repair(db(), run, "broom_spear") == "" and not Gear.broken(db(), run, "broom_spear"), "the blacksmith repairs it")
	check(Gear.ore_drop(db(), 1, seeded(3)) in ["", "ore_iron"], "week 1 drops plain iron")
	run["bonds"]["blacksmith"] = 50.0
	run["bonds"]["walt"] = 40.0
	var coms := Gear.commissions(db(), run)
	check(coms.any(func(c: Dictionary) -> bool: return c["item"] == "walts_compass"), "Walt's compass can be commissioned")
	Fx.add_item(run, "void_glass", 1)
	var walt: Dictionary = coms.filter(func(c: Dictionary) -> bool: return c["item"] == "walts_compass")[0]
	check(Gear.commission(db(), run, walt, 4) == "", "order it")
	check(Gear.collect(run, 5).is_empty() and Gear.collect(run, 6) == ["walts_compass"], "ready two days later")


func test_gear_in_combat() -> void:
	const Gear := preload("res://src/core/items/gear.gd")
	const Fx := preload("res://src/core/run/effects.gd")
	const StateScript := preload("res://src/core/combat/combat_state.gd")
	var run := run_()
	var ch: Dictionary = run["player"]
	Fx.add_item(run, "iron_knuckles", 1)
	Gear.equip(db(), run, ch, "iron_knuckles")
	var plain: Dictionary = DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)
	var armored := plain.duplicate(true)
	armored["affixes"] = ["armored"]
	var st := StateScript.new(db(), seeded(1), { "layout": { "map": ["PE.E"] }, "party": [{ "char": ch }], "enemies": [plain, armored] })
	var me = st.unit_by_id("player")
	var foes: Array = st.units.filter(func(u) -> bool: return u.team == "enemy")
	var vs_plain: float = st._expected_strike(me, foes[0], { "action": "strike", "stat": "str" })
	var vs_armored: float = st._expected_strike(me, foes[1], { "action": "strike", "stat": "str" })
	check(st.weapon(me).get("tags", []).has("blunt"), "knuckles are blunt")
	Gear.unequip(db(), run, ch, "weapon")
	var st0 := StateScript.new(db(), seeded(1), { "layout": { "map": ["PE.E"] }, "party": [{ "char": ch }], "enemies": [plain.duplicate(true), armored.duplicate(true)] })
	var me0 = st0.unit_by_id("player")
	var foes0: Array = st0.units.filter(func(u) -> bool: return u.team == "enemy")
	var r_none: float = st0._expected_strike(me0, foes0[1], { "action": "strike", "stat": "str" }) / maxf(0.01, st0._expected_strike(me0, foes0[0], { "action": "strike", "stat": "str" }))
	check(vs_armored / maxf(0.01, vs_plain) > r_none, "blunt hits Armored harder (%.2f vs %.2f)" % [vs_armored / maxf(0.01, vs_plain), r_none])
	Fx.add_item(run, "mirror_pin", 1)
	Gear.equip(db(), run, ch, "mirror_pin")
	var st2 := StateScript.new(db(), seeded(1), { "layout": { "map": ["PE"] }, "party": [{ "char": ch }], "enemies": [plain.duplicate(true)] })
	var me2 = st2.unit_by_id("player")
	var foe2 = st2.units.filter(func(u) -> bool: return u.team == "enemy")[0]
	var hp0: int = me2.hp
	var fh0: int = foe2.hp
	st2._damage(me2, 5, foe2, "", "hit")
	check(me2.hp == hp0 and foe2.hp < fh0, "the Mirror Pin reflects the first hit")
	st2._damage(me2, 5, foe2, "", "hit")
	check(me2.hp < hp0, "only the first")


func test_party_combo() -> void:
	const StateScript := preload("res://src/core/combat/combat_state.gd")
	var run := run_()
	var ch: Dictionary = run["player"].duplicate(true)
	ch["knownVectors"] = ["heat"]
	var pal: Dictionary = ch.duplicate(true)
	pal["id"] = "dex"
	pal["name"] = "Dex"
	pal["isPlayer"] = false
	pal["knownVectors"] = ["cold"]
	pal.erase("partyBonds")
	var foe: Dictionary = DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)
	for bond in [50, 80]:
		ch["partyBonds"] = { "dex": bond }
		pal["partyBonds"] = { "player": bond }
		var st := StateScript.new(db(), seeded(2), { "layout": { "map": ["PP..E"] }, "party": [{ "char": ch.duplicate(true) }, { "char": pal.duplicate(true) }], "enemies": [foe.duplicate(true)] })
		var me = st.unit_by_id("player")
		var dex = st.unit_by_id("dex")
		st.current = me
		me.actions_left = 2
		if bond < 71:
			check(st.together_options(me).is_empty(), "no party combo below Close Bond")
			continue
		var opts: Array = st.together_options(me)
		check(opts.size() == 1 and str(opts[0]["combo"].get("id", "")) == "thermal_shock", "heat + cold together is Thermal Shock")
		var e = st.units.filter(func(u) -> bool: return u.team == "enemy")[0]
		var hp0: int = e.hp
		check(st.together_targets(me).has(e.cell), "the enemy is a target")
		check(st.cast_together(me, e.cell), "cast together")
		check(e.hp < hp0 or not e.alive(), "the combo hits")
		check(me.actions_left == 1, "it spends one of your Actions")
		check(dex.links.has("owedAction"), "and one of Dex's")
		check(st.combos_cast.has("thermal_shock"), "the combo is discovered")
		check(st.together_options(me).is_empty(), "once per pair per fight")
		st._start_turn(dex)
		check(dex.actions_left == st.actions_per_turn() - 1, "Dex starts the next turn an Action short")


func test_social_gaps() -> void:
	const Phone := preload("res://src/core/social/phone.gd")
	const Truancy := preload("res://src/core/town/truancy.gd")
	const CS := preload("res://src/core/story/cutscenes.gd")
	const RM := preload("res://src/core/run/run_model.gd")
	var d := db()
	for id in ["w1_lunch_friends", "skip_theo", "skip_mara", "skip_dex", "skip_priya"]:
		check(not CS.find(d, id).is_empty() and CS.problems(d, CS.find(d, id)).is_empty(), "%s exists and checks out" % id)
	var lunch: Array = d["story/school_calendar"]["stories"].filter(func(s) -> bool: return str(s["id"]) == "w1_lunch_friends")
	check(lunch.size() == 1 and int(lunch[0]["trigger"]["week"]) == 1 and str(lunch[0]["trigger"]["part"]) == "lunch", "the week 1 lunch scene is on the calendar")
	# Daytime scenes: once, only during school hours.
	var run := run_()
	for n in ["officer_pruitt", "rae", "walt", "mo", "mr_ellis"]:
		var rec: Dictionary = d["npcs/" + n]
		check(not CS.find(d, str(rec.get("daytimeScene", ""))).is_empty(), "%s has a daytime scene" % n)
		check(Truancy.daytime_scene(d, run, rec, "after_school") == "", "not after school")
		check(Truancy.daytime_scene(d, run, rec, "period_2") == "day_" + n, "during school hours")
		check(Truancy.daytime_scene(d, run, rec, "period_3") == "", "only once")
	# Skip invites.
	run = run_()
	run["bonds"] = { "dex": 50.0 }
	var got := false
	for day in 40:
		Phone.night_texts(d, run, day, seeded(day))
		if not run.get("texts", []).filter(func(t) -> bool: return bool(t.get("skipInvite", false))).is_empty():
			got = true
			Phone.accept_skip(run, "dex", day)
			check(Phone.skip_invite_today(run, day) == "", "not today")
			check(Phone.skip_invite_today(run, day + 1) == "dex", "Dex waits tomorrow")
			var b0 := RM.bond(run, "dex")
			check(Phone.skip_with(d, run, "dex") == "skip_dex" and RM.bond(run, "dex") > b0, "skipping with Dex plays his scene and raises Bond")
			check(Phone.skip_invite_today(run, day + 1) == "", "the invite is used up")
			break
	check(got, "a Friend-Bond Core Four member asks you to skip")
	run = run_()
	run["bonds"] = { "dex": 20.0 }
	for day in 40:
		Phone.night_texts(d, run, day, seeded(day))
	check(run.get("texts", []).filter(func(t) -> bool: return bool(t.get("skipInvite", false))).is_empty(), "not below Friend Bond")
	Phone.accept_skip(run, "mara", 3)
	check(Phone.skip_invite_today(run, 6) == "" and not run["skipInvites"].has("mara"), "old invites lapse")


func test_combat_stubs() -> void:
	const StateScript := preload("res://src/core/combat/combat_state.gd")
	var run := run_()
	var ch: Dictionary = run["player"].duplicate(true)
	var idx := DT.index_under(db(), "enemies/", "enemies")
	for id in ["skulker", "watcher_eye"]:
		check(idx.has(id) and bool(idx[id].get("startsHidden", false)), "%s starts hidden" % id)
	# Hidden: untargetable from afar, shown by standing next to it, Light, Reveal or attacking.
	var st := StateScript.new(db(), seeded(3), { "layout": { "map": ["P...E"] }, "party": [{ "char": ch.duplicate(true) }], "enemies": [idx["skulker"].duplicate(true)] })
	var me = st.unit_by_id("player")
	var sk = st.units.filter(func(u) -> bool: return u.team == "enemy")[0]
	check(st.hidden(sk), "the Skulker is hidden")
	st.current = me
	me.actions_left = 2
	check(not st.cantrip_targets(me).has(sk.cell), "and can't be targeted")
	var next_to: Vector2i = sk.cell + Vector2i(-1, 0)
	var old: Vector2i = me.cell
	me.cell = next_to
	check(not st.hidden(sk), "standing next to it shows it")
	me.cell = old
	check(st.hidden(sk), "step away and it's gone again")
	st._effects_script().run(st, me, { "name": "Reveal", "vectors": { "light": 1.0 }, "effects": [{ "op": "reveal", "turns": 1 }] }, me.cell, [])
	check(not st.hidden(sk) and not sk.statuses.has("hidden"), "Reveal shows it for good")
	# Constructs that act.
	var st2 := StateScript.new(db(), seeded(4), { "layout": { "map": ["P....", ".....", "....E"] }, "party": [{ "char": ch.duplicate(true) }], "enemies": [idx["pom_pom_wisp"].duplicate(true)] })
	var me2 = st2.unit_by_id("player")
	var foe = st2.units.filter(func(u) -> bool: return u.team == "enemy")[0]
	check(st2.construct_mode({ "vectors": { "heat": 1.0 } }) == "turret", "Heat builds a turret")
	check(st2.construct_mode({ "vectors": { "motion": 1.0 } }) == "decoy", "Motion builds a decoy")
	check(st2.construct_mode({ "vectors": { "force": 1.0 } }) == "wall", "Force builds a wall")
	var spec := { "name": "Ember Construct", "vectors": { "heat": 1.0 }, "form": st2.form_rec("construct"), "power": 10.0, "mult": 1.0, "heal": false, "ranged": true, "kind": "spell" }
	st2._resolve_spec(me2, spec, foe.cell + Vector2i(-2, 0))
	var turret = st2.unit_at(foe.cell + Vector2i(-2, 0))
	check(turret != null and turret.is_prop() and str(st2.construct_info.get(turret, {}).get("mode", "")) == "turret", "the turret is placed")
	var hp0: int = foe.hp
	st2._construct_turns()
	check(foe.hp < hp0, "the turret fires at the end of the round")
	var dspec := spec.duplicate()
	dspec["vectors"] = { "motion": 1.0 }
	st2._resolve_spec(me2, dspec, Vector2i(1, 0))
	var decoy = st2.unit_at(Vector2i(1, 0))
	check(decoy != null and str(st2.construct_info.get(decoy, {}).get("mode", "")) == "decoy", "the decoy is placed")
	st2.refresh_intents()
	check(st2.construct_info.has(decoy), "the decoy keeps drawing plans after enemies re-plan")


func test_goal_tracker() -> void:
	const Goals := preload("res://src/core/town/goals.gd")
	const Phone := preload("res://src/core/social/phone.gd")
	const Gear := preload("res://src/core/items/gear.gd")
	const Fx := preload("res://src/core/run/effects.gd")
	var d := db()
	var run := run_()
	var g := Goals.build(d, run, { "week": 1, "day": "tue", "part": "period_2", "day_count": 1 })
	for s in Goals.SECTIONS:
		check(g.has(s) and g[s] is Array, "section %s" % s)
	check(not g["places"].is_empty(), "something is open during period 2")
	var after := Goals.build(d, run, { "week": 1, "day": "tue", "part": "night", "day_count": 1 })
	check(str(after["places"]) != str(g["places"]), "open places change with the part")
	check(not g["favors"].is_empty() or not Goals.favors(d, run, 1, "after_school", 1).is_empty(), "the favor board shows up")
	# Leads: two clues that make a deduction.
	var ded: Dictionary = d["mystery"]["deductions"][0]
	run["clues"] = ded["clues"].duplicate()
	check(str(Goals.leads(d, run)).contains("deduction"), "a ready deduction is a lead")
	# Bonds: a skip invite today and a friend near a tier.
	Phone.accept_skip(run, "dex", 1)
	run["bonds"]["kelly"] = 38.0
	var b := Goals.bonds(d, run, 2)
	check(str(b).contains("Dex") and str(b).contains("Kelly"), "Dex waits to skip; Kelly is close to Friend")
	# Gear: an order, loose gear, a broken piece.
	run["orders"] = [{ "item": "garys_cleaver", "ready": 5 }]
	Fx.add_item(run, "windbreaker", 1)
	Gear.state(run, "iron_knuckles")["durability"] = 0
	var gl := str(Goals.gear(d, run, 3))
	check(gl.contains("2 day") and gl.contains("bag") and gl.contains("broken"), "orders, loose gear and broken gear")
	# Run-end summary.
	run["attendance"] = { "math": 3, "pe": 2 }
	run["skips_total"] = 4
	run["skippedWith"] = ["dex", "dex", "theo"]
	run["flags"]["seen_day_walt"] = true
	var ch: Dictionary = run["player"]
	Fx.add_item(run, "windbreaker", 1)
	Gear.equip(d, run, ch, "windbreaker")
	var sm := "\n".join(PackedStringArray(Goals.run_summary(d, run, [ch])))
	check(sm.contains("attended 5") and sm.contains("skipped 4"), "attendance vs skips")
	check(sm.contains("Dex, Theo") and sm.contains("met while skipping: 1"), "what the skips bought")
	check(sm.contains("Windbreaker"), "the gear you finished with")


func _deck_fight(hand: Array, discard: Array) -> Dictionary:
	const StateScript := preload("res://src/core/combat/combat_state.gd")
	var run := run_()
	var ch: Dictionary = run["player"].duplicate(true)
	var foe: Dictionary = DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)
	foe["hp"] = 400
	var st := StateScript.new(db(), seeded(5), { "layout": { "map": ["PE..."] }, "party": [{ "char": ch }], "enemies": [foe] })
	var me = st.unit_by_id("player")
	st.current = me
	me.actions_left = 2
	me.mp = me.max_mp
	me.deck.hand = hand.duplicate()
	me.deck.discard = discard.duplicate()
	return { "st": st, "me": me, "foe": st.units.filter(func(u) -> bool: return u.team == "enemy")[0], "run": run }


func test_deck_trick_cards() -> void:
	const CR := preload("res://src/core/card.gd")
	const FX := preload("res://src/core/combat/card_effects.gd")
	var d := db()
	var ids := ["card_graveyard_shift", "card_echo_strike", "card_last_stand", "card_hoarders_jab", "card_rampage", "card_bonfire",
		"card_discard_volley", "card_second_wind_deck", "card_dig_deep", "card_clean_slate", "card_grim_harvest"]
	for id in ids:
		var c := CR.resolve(d, id)
		check(not c.is_empty(), "%s exists" % id)
		for e in c.get("effects", []):
			check(FX.OPS.has(str(e["op"])), "%s uses a known op" % id)
	var fill := ["card_strike", "card_strike", "card_strike", "card_strike", "card_strike", "card_strike"]
	# Graveyard Shift scales with the discard pile.
	var a := _deck_fight(["card_graveyard_shift"], [])
	var b := _deck_fight(["card_graveyard_shift"], fill)
	var fa: int = a["foe"].hp
	var fb: int = b["foe"].hp
	a["st"].play_card(a["me"], 0, a["foe"].cell)
	b["st"].play_card(b["me"], 0, b["foe"].cell)
	check(fb - b["foe"].hp > fa - a["foe"].hp, "Graveyard Shift hits harder with a full discard pile (%d vs %d)" % [fb - b["foe"].hp, fa - a["foe"].hp])
	# Bonfire exhausts discards for damage.
	var f := _deck_fight(["card_bonfire"], fill)
	var hp0: int = f["foe"].hp
	f["st"].play_card(f["me"], 0, f["foe"].cell)
	check(f["me"].deck.exhausted.size() == 4 and f["foe"].hp < hp0, "Bonfire burns 4 cards for damage")
	# Spent Spells fires the spells in the discard pile.
	var spell_id := ""
	for c in d["cards/starter_cards"]["cards"]:
		if str(c.get("kind", "")) == "spell":
			spell_id = str(c["id"])
			break
	var v := _deck_fight(["card_discard_volley"], [spell_id, spell_id, "card_strike"])
	hp0 = v["foe"].hp
	check(spell_id != "" and v["st"].play_card(v["me"], 0, v["foe"].cell) and v["foe"].hp < hp0, "Spent Spells fires the discarded spells")
	# Second Wind reshuffles; Dig Deep returns the most expensive; Clean Slate cycles; Grim Harvest gives MP.
	var s := _deck_fight(["card_second_wind_deck"], fill)
	s["me"].deck.draw_pile = []
	s["st"].play_card(s["me"], 0, s["me"].cell)
	check(s["me"].deck.discard.size() == 1 and s["me"].deck.hand.size() == 1 and s["me"].deck.reshuffles == 0, "Second Wind shuffles the discard back (no Fatigue) and draws 1")
	var dd := _deck_fight(["card_dig_deep"], ["card_strike", "card_overflow", "card_strike"])
	dd["st"].play_card(dd["me"], 0, dd["me"].cell)
	check(dd["me"].deck.hand.has("card_overflow"), "Dig Deep takes back the most expensive card")
	var cs := _deck_fight(["card_clean_slate", "card_strike", "card_strike"], [])
	cs["me"].deck.draw_pile = fill.duplicate()
	cs["st"].play_card(cs["me"], 0, cs["me"].cell)
	check(cs["me"].deck.hand.size() == 3, "Clean Slate discards 2 and draws 3")
	var gh := _deck_fight(["card_grim_harvest"], fill)
	gh["me"].mp = 0
	gh["st"].play_card(gh["me"], 0, gh["me"].cell)
	check(gh["me"].mp == 2, "Grim Harvest: 7 in the discard pile is 2 MP")
	# Rampage grows.
	var r := _deck_fight(["card_rampage"], [])
	var st = r["st"]
	hp0 = r["foe"].hp
	st.play_card(r["me"], 0, r["foe"].cell)
	var first: int = hp0 - r["foe"].hp
	r["me"].deck.hand = ["card_rampage"]
	r["me"].actions_left = 2
	hp0 = r["foe"].hp
	st.play_card(r["me"], 0, r["foe"].cell)
	check(hp0 - r["foe"].hp > first, "Rampage hits harder the second time")


func test_weapon_card_bonus() -> void:
	const Gear := preload("res://src/core/items/gear.gd")
	const Fx := preload("res://src/core/run/effects.gd")
	var a := _deck_fight(["card_crushing_blow"], [])
	var b := _deck_fight(["card_crushing_blow"], [])
	var ch: Dictionary = b["run"]["player"]
	Fx.add_item(b["run"], "forged_baton", 1)
	Gear.equip(db(), b["run"], ch, "forged_baton")
	b["me"].source["gearStats"] = ch["gearStats"]
	var plain := float(b["st"]._expected_strike(b["me"], b["foe"], { "stat": "str", "mult": 1.8 }))
	b["st"].card_weapon_tag = "blunt"
	var tagged := float(b["st"]._expected_strike(b["me"], b["foe"], { "stat": "str", "mult": 1.8 }))
	b["st"].card_weapon_tag = "blade"
	var wrong := float(b["st"]._expected_strike(b["me"], b["foe"], { "stat": "str", "mult": 1.8 }))
	check(tagged > plain and wrong == plain, "a blunt card gets the baton's bonus; a blade card doesn't (%.1f, %.1f, %.1f)" % [plain, tagged, wrong])
	check(str(preload("res://src/core/card.gd").resolve(db(), "card_crushing_blow").get("weaponTag", "")) == "blunt", "Crushing Blow is blunt")
	check(a["st"].card_weapon_tag == "", "no tag outside a card")


func test_gear_icons() -> void:
	var assets: Dictionary = db()["assets/manifest"]["assets"]
	for it in db()["items"]["items"]:
		if str(it.get("kind", "")) in ["equipment", "ore"]:
			check(assets.has("icon_item_" + str(it["id"])), "%s has an icon" % it["id"])
	for k in ["weapon", "armor", "trinket", "ore", "default"]:
		check(assets.has("icon_item_" + k), "fallback icon_item_%s" % k)
	check(Array(db()["arena/checkpoint"].get("blacksmithServices", [])) == ["upgrade", "infuse", "repair"], "the camp blacksmith offers upgrade, infuse and repair")


func test_story_card_rewards() -> void:
	const CR := preload("res://src/core/run/card_rewards.gd")
	const CardRules := preload("res://src/core/card.gd")
	var d := db()
	var run := run_()
	run["money"] = 100
	check(CR.wave_for(d, 1) == 5 and CR.wave_for(d, 3, 5) == 20, "weeks map to arena waves")
	var floor_pick := CR.offer(d, run, 1, "floor")
	check(floor_pick.size() == 3, "a floor offers 3 cards")
	check(str(floor_pick) == str(CR.offer(d, run, 1, "floor")), "the same day offers the same cards")
	check(str(floor_pick) != str(CR.offer(d, run, 1, "deduction")), "each source rolls its own")
	for id in floor_pick:
		check(int(CardRules.resolve(d, str(id)).get("minWave", 0)) <= 5, "week 1 offers no late cards (%s)" % id)
	CR.take(run, str(floor_pick[0]))
	check(run["pendingCards"].has(str(floor_pick[0])), "a taken card waits for an owner")
	check(CR.skip(d, run, "boss") == 10 and run["money"] == 110, "skipping a boss pick pays $10")
	var shelf := CR.shelf(d, run, 2)
	check(shelf.size() == 3 and int(shelf[0]["price"]) > 0, "the shelf has 3 priced cards")
	var first := str(shelf[0]["id"])
	check(CR.buy(d, run, 2, first) == "" and run["money"] == 110 - int(shelf[0]["price"]), "buying from the shelf costs its price")
	check(CR.shelf(d, run, 2).size() == 2 and CR.buy(d, run, 2, first) == "gone", "a bought card leaves the shelf")
	run["money"] = 0
	check(CR.buy(d, run, 2, str(CR.shelf(d, run, 2)[0]["id"])) == "money", "no money, no card")
	var lib: Array = d["town/locations"]["locations"].filter(func(l) -> bool: return str(l["id"]) == "library")
	check(lib[0]["activities"].any(func(a) -> bool: return bool(a.get("cardShelf", false))), "the library has the card shelf")


func test_effects_card_preview() -> void:
	const CR := preload("res://src/core/card.gd")
	var f := _deck_fight(["card_graveyard_shift"], ["card_strike", "card_strike", "card_strike"])
	var st = f["st"]
	var p: Dictionary = st.preview(f["me"], CR.resolve(db(), "card_graveyard_shift"), f["foe"].cell)
	check(p["hits"].size() == 1 and int(p["hits"][0].get("damage", 0)) > 0, "an effects card previews its damage")
	var hp0: int = f["foe"].hp
	st.play_card(f["me"], 0, f["foe"].cell)
	check(absi((hp0 - f["foe"].hp) - int(p["hits"][0]["damage"])) <= 2, "the preview matches the hit (%d vs %d)" % [hp0 - f["foe"].hp, int(p["hits"][0]["damage"])])
	var b := _deck_fight(["card_bonfire"], ["card_strike", "card_strike"])
	var pb: Dictionary = b["st"].preview(b["me"], CR.resolve(db(), "card_bonfire"), b["foe"].cell)
	check(int(pb["hits"][0].get("damage", 0)) == 8, "Bonfire previews 2 discards x 4")
	var c := _deck_fight(["card_cleave"], [])
	var pc: Dictionary = c["st"].preview(c["me"], CR.resolve(db(), "card_cleave"), c["foe"].cell)
	check(pc["hits"].size() == 1 and pc["cells"].size() >= 1, "Cleave previews its shape")


func test_town_happenings() -> void:
	const StoryRules := preload("res://src/core/story/story.gd")
	const Goals := preload("res://src/core/town/goals.gd")
	const Arena := preload("res://src/core/arena/arena.gd")
	const Locs := preload("res://src/core/town/locations.gd")
	const CR := preload("res://src/core/card.gd")
	var d := db()
	var haps: Array = d["story/town_happenings"]["stories"]
	check(haps.size() >= 12, "a dozen happenings")
	var cards_seen := {}
	var school := 0
	for h in haps:
		check(not Locs.rec(d, str(h["at"]["loc"])).is_empty(), "%s is at a real place" % h["id"])
		for day in h["trigger"]["day"]:
			var parts := StoryRules.part_order(d, str(day))
			check(Array(h["window"]).any(func(p: Variant) -> bool: return parts.has(str(p))), "%s: its window exists on %s" % [h["id"], day])
		for p in h["window"]:
			check(str(p) != "evening", "%s is not during the dungeon" % h["id"])
			if str(p).begins_with("period_"):
				school += 1
		for c in h["steps"][0]["event"]["choices"]:
			if c.get("effects", {}).has("card"):
				var cid := str(c["effects"]["card"])
				check(bool(CR.resolve(d, cid).get("exclusive", false)), "%s is exclusive" % cid)
				cards_seen[cid] = true
	check(school >= 8, "most reward skipping class")
	for c in d["cards/town_exclusive_cards"]["cards"]:
		check(cards_seen.has(str(c["id"])), "%s comes from a happening" % c["id"])
	# Exclusive cards never show up in offers.
	var run := run_()
	for w in [5, 15, 25]:
		for seed_value in 20:
			for id in Arena.card_offer(d, { "seed": seed_value }, [run["player"]], w):
				check(not cards_seen.has(str(id)), "offers skip exclusive cards")
	# The window: only then, and once.
	var ctx := { "week": 1, "day": "tue", "part": "period_1", "day_count": 1 }
	check(StoryRules.due_at(d, run, ctx, "downtown", ["park"]).has("hap_pigeon_hour"), "pigeon hour is on during period 1")
	ctx["part"] = "lunch"
	check(not StoryRules.due_at(d, run, ctx, "downtown", ["park"]).has("hap_pigeon_hour"), "and gone by lunch")
	ctx["part"] = "period_1"
	check(not StoryRules.due_at(d, run, ctx, "downtown", ["library"]).has("hap_pigeon_hour"), "only at the park")
	check(not StoryRules.due_at(d, run, { "week": 1, "day": "wed", "part": "period_1" }, "downtown", ["park"]).has("hap_pigeon_hour"), "only on its days")
	var sat := StoryRules.due_at(d, run, { "week": 1, "day": "sat", "part": "midday" }, "downtown", ["town_square"])
	check(sat.has("hap_busker_duel"), "a window can span weekday and weekend parts")
	var today := StoryRules.happenings_today(d, run, { "week": 1, "day": "tue", "part": "before_school" })
	check(today.any(func(h: Dictionary) -> bool: return str(h["id"]) == "hap_pigeon_hour" and not bool(h["open"])), "the morning sees it coming")
	check(StoryRules.happenings_today(d, run, { "week": 1, "day": "tue", "part": "after_school" }).all(func(h: Dictionary) -> bool: return str(h["id"]) != "hap_pigeon_hour"), "off the list once it is over")
	check(str(Goals.happenings(d, run, ctx)).contains("NOW"), "the goal tracker says what is on now")
	run["flags"]["story_done_hap_pigeon_hour"] = true
	check(not StoryRules.due_at(d, run, ctx, "downtown", ["park"]).has("hap_pigeon_hour"), "it plays once")
	for n in ["juniper", "hank", "lena", "amos", "rosa"]:
		check(d.has("npcs/" + n) and d["assets/manifest"]["assets"].has("npc_%s_walk" % n), "%s is in town" % n)


func test_night_safety_nets() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var run := run_()
	var mk := func(diff: String, night: bool, allies: bool) -> Object:
		var ch: Dictionary = run["player"].duplicate(true)
		var party: Array = [{ "char": ch }]
		if allies:
			var pal: Dictionary = ch.duplicate(true)
			pal["id"] = "dex"
			pal["isPlayer"] = false
			party.append({ "char": pal })
		return preload("res://src/core/combat/combat_state.gd").new(db(), seeded(6), { "layout": { "map": ["PP..E"] }, "party": party, "enemies": [idx["pom_pom_wisp"].duplicate(true)], "difficulty": diff, "ramp": 1.0, "storyNight": night })
	# Normal night: one Last Stand a fight.
	var n: Object = mk.call("normal", true, false)
	var me = n.unit_by_id("player")
	n._damage(me, 9999, null, "", "hit")
	check(n.result == "" and me.hp == 1 and not me.downed and me.shield > 0, "a Normal night's first deadly blow is a Last Stand")
	me.shield = 0
	n._damage(me, 9999, null, "", "hit")
	check(n.result == "lose", "the second one is not")
	# The arena and Hard keep the old rule.
	var a: Object = mk.call("normal", false, false)
	a._damage(a.unit_by_id("player"), 9999, null, "", "hit")
	check(a.result == "lose", "no Last Stand outside nights")
	var h: Object = mk.call("hard", true, false)
	h._damage(h.unit_by_id("player"), 9999, null, "", "hit")
	check(h.result == "lose", "no Last Stand on Hard")
	# Easy night: lost only when nobody stands.
	var e: Object = mk.call("story", true, true)
	e._damage(e.unit_by_id("player"), 9999, null, "", "hit")
	check(e.result == "" and e.unit_by_id("player").downed, "on Easy you go down but the fight goes on")
	e._damage(e.unit_by_id("dex"), 9999, null, "", "hit")
	e.check_end()
	check(e.result == "lose", "and it is lost when nobody stands")


func test_night_hit_cap() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var run := run_()
	var party: Array = [{ "char": run["player"].duplicate(true) }]
	var foes: Array = [idx["pom_pom_wisp"].duplicate(true)]
	var st: Object = preload("res://src/core/combat/combat_state.gd").new(db(), seeded(7), { "layout": { "map": ["PE"] }, "party": party, "enemies": foes, "difficulty": "hard", "ramp": 1.0, "storyNight": true })
	var me = st.unit_by_id("player")
	var foe = st.units.filter(func(u) -> bool: return u.team == "enemy")[0]
	var hp0: int = me.hp
	st._damage(me, 9999, foe, "", "hit")
	check(me.hp > 0 and hp0 - me.hp <= ceili(float(me.max_hp) * 0.6), "a night hit on Hard takes at most 60% of max HP")
	var hp1: int = me.hp
	st._damage(me, 3, null, "", "hazard")
	check(me.hp == hp1 - 3, "the cap is only for enemy hits")
	var arena: Object = preload("res://src/core/combat/combat_state.gd").new(db(), seeded(7), { "layout": { "map": ["PE"] }, "party": party, "enemies": foes, "difficulty": "hard", "ramp": 1.0 })
	var ame = arena.unit_by_id("player")
	var afoe = arena.units.filter(func(u) -> bool: return u.team == "enemy")[0]
	var ahp: int = ame.hp
	arena._damage(ame, 9999, afoe, "", "hit")
	check(ame.hp > 0 and ahp - ame.hp <= ceili(float(ame.max_hp) * 0.8), "the arena's cap is looser: 80% on Hard")


func test_hidden_can_not_stall() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var run := run_()
	var st: Object = preload("res://src/core/combat/combat_state.gd").new(db(), seeded(8), { "layout": { "map": ["P......E"] }, "party": [{ "char": run["player"].duplicate(true) }], "enemies": [idx["skulker"].duplicate(true)] })
	var sk = st.units.filter(func(u) -> bool: return u.team == "enemy")[0]
	check(st.hidden(sk), "it starts hidden")
	var guard := 0
	while st.round_num < int(db()["combat_rules"]["hiddenRounds"]) + 1 and guard < 60 and st.result == "":
		st.end_turn() if st.current.team == "party" else preload("res://src/core/combat/enemy_ai.gd").take_turn(st, st.current)
		guard += 1
	check(not sk.statuses.has("hidden") or not sk.alive(), "it is out by round %d" % st.round_num)


func test_tests_use_a_sandbox() -> void:
	const UP := preload("res://src/core/user_paths.gd")
	check(UP.sandboxed() and UP.of("run_save.json").contains("test_sandbox"), "test runs never touch the player's files")


func _tech_fight(techs: Array, enemy: String = "pom_pom_wisp", vectors: Array = []) -> Dictionary:
	var run := run_()
	var ch: Dictionary = run["player"].duplicate(true)
	ch["techniques"] = techs
	if not vectors.is_empty():
		ch["knownVectors"] = vectors
	var foe: Dictionary = DT.index_under(db(), "enemies/", "enemies")[enemy].duplicate(true)
	foe["hp"] = 500
	var st: Object = preload("res://src/core/combat/combat_state.gd").new(db(), seeded(9), { "layout": { "map": ["P....", ".....", "...E."] }, "party": [{ "char": ch }], "enemies": [foe] })
	var me = st.unit_by_id("player")
	st.current = me
	me.actions_left = 2
	me.mp = me.max_mp
	return { "st": st, "me": me, "foe": st.units.filter(func(u) -> bool: return u.team == "enemy")[0], "run": run, "ch": ch }


func test_no_technique_is_a_placebo() -> void:
	for t in db()["techniques"]["techniques"]:
		check(not bool(t.get("planned", false)), "%s can be learned" % t["id"])
	# Every mod a Technique names is read somewhere in the rules.
	var src := ""
	for p in ["res://src/core/combat/combat_state.gd", "res://src/core/combat/resolver.gd", "res://src/core/combat/card_effects.gd", "res://src/core/character.gd", "res://src/core/effects.gd", "res://src/core/combat/enemy_ai.gd", "res://src/core/combat/unit.gd", "res://src/core/progression/leveling.gd", "res://src/core/dungeon/night.gd", "res://src/core/arena/arena.gd", "res://src/core/card.gd", "res://src/core/combat/forms.gd"]:
		src += FileAccess.get_file_as_string(p)
	for t in db()["techniques"]["techniques"]:
		for key in t.get("mods", {}).get("combat", {}):
			check(src.contains(str(key)), "%s: combat mod %s is read by the rules" % [t["id"], key])
	# Efficient Forging really cuts the cost.
	var CR := preload("res://src/core/card.gd")
	var con := { "id": "x", "name": "X", "kind": "spell", "vectors": { "force": 1.0 }, "form": "construct", "magnitude": "minor" }
	var a := _tech_fight([])
	var b := _tech_fight(["efficient_forging"])
	check(int(b["st"].card_cost(b["me"], con)) == maxi(0, int(a["st"].card_cost(a["me"], con)) - 1), "Efficient Forging: Constructs cost 1 less")
	# Reactive Casting fires once a round when an enemy steps next to you.
	var r := _tech_fight(["reactive_casting"], "pom_pom_wisp", ["heat"])
	var hp0: int = r["foe"].hp
	r["foe"].cell = r["me"].cell + Vector2i(1, 0)
	r["st"]._reactive_cantrips(r["foe"])
	check(r["foe"].hp < hp0, "Reactive Casting hits an enemy that steps next to you")
	hp0 = r["foe"].hp
	r["st"]._reactive_cantrips(r["foe"])
	check(r["foe"].hp == hp0, "only once a round")
	# Cards from Techniques.
	var ch := _tech_fight([])["ch"] as Dictionary
	ch["level"] = 20
	ch["pendingTechniques"] = ["x"]
	check(preload("res://src/core/progression/leveling.gd").choose_technique(db(), ch, "deep_calculation") and ch["deck"].has("card_deep_calculation"), "Deep Calculation adds its card")
	var dc := _tech_fight([])
	dc["me"].deck.hand = ["card_deep_calculation"]
	dc["me"].mp = 0
	dc["st"].play_card(dc["me"], 0, dc["me"].cell)
	check(dc["me"].mp == dc["me"].max_mp, "and it fills MP")
	check(dc["me"].deck.exhausted.has("card_deep_calculation"), "once per fight")
	var sat := _tech_fight([], "pom_pom_wisp", ["corrosion"])
	sat["me"].deck.hand = ["card_saturate"]
	check(sat["st"].play_card(sat["me"], 0, Vector2i(2, 1)) and sat["st"].grid.toxic.size() >= 4, "Saturate soaks the area")


func test_construct_techniques() -> void:
	var spec := func(st: Object, axis: String) -> Dictionary:
		return { "name": "Test Construct", "vectors": { axis: 1.0 }, "form": st.form_rec("construct"), "power": 10.0, "mult": 1.0, "heal": false, "ranged": true, "kind": "spell" }
	# Living Foundry: a Force Construct would be a wall; the first is a strong turret.
	var f := _tech_fight(["living_foundry"])
	f["st"]._resolve_spec(f["me"], spec.call(f["st"], "force"), f["foe"].cell + Vector2i(-2, 0))
	var prop = f["st"].unit_at(f["foe"].cell + Vector2i(-2, 0))
	check(str(f["st"].construct_info[prop]["mode"]) == "turret", "Living Foundry: the first Construct is a turret")
	var hp0: int = f["foe"].hp
	f["st"]._construct_turns()
	var strong: int = hp0 - f["foe"].hp
	check(strong > 0, "and it fires")
	f["st"]._resolve_spec(f["me"], spec.call(f["st"], "force"), Vector2i(1, 0))
	check(str(f["st"].construct_info[f["st"].unit_at(Vector2i(1, 0))]["mode"]) == "wall", "only the first")
	# Overcharged Construct: a wall pulses at adjacent enemies.
	var o := _tech_fight(["overcharged_construct"])
	o["st"]._resolve_spec(o["me"], spec.call(o["st"], "force"), o["foe"].cell + Vector2i(-1, 0))
	hp0 = o["foe"].hp
	o["st"]._construct_turns()
	check(o["foe"].hp < hp0, "Overcharged Construct pulses")
	# Modular Imbuement: the next Strike leaves a Glyph.
	var m := _tech_fight(["modular_imbuement"], "pom_pom_wisp", ["heat"])
	m["st"]._resolve_spec(m["me"], { "name": "Inf", "vectors": { "heat": 1.0 }, "form": m["st"].form_rec("weapon_infusion"), "power": 8.0, "mult": 1.0, "heal": false, "ranged": false, "kind": "spell" }, m["me"].cell)
	m["foe"].cell = m["me"].cell + Vector2i(1, 0)
	check(m["st"].strike(m["me"], m["foe"].cell) and m["st"].glyphs.size() == 1, "Modular Imbuement: the Strike leaves a Glyph")


func test_alchemy() -> void:
	const Alch := preload("res://src/core/items/alchemy.gd")
	const CR := preload("res://src/core/card.gd")
	var d := db()
	var run := run_()
	var ch: Dictionary = run["player"]
	var spell := ""
	for c in d["cards/vector_cards"]["cards"]:
		if str(c.get("kind", "")) == "spell" and str(c.get("form", "")) == "bolt" and not c.has("effects"):
			spell = str(c["id"])
			break
	ch["deck"] = [spell, "card_strike"]
	check(Alch.block(d, run, ch, 1) == "unknown", "brewing needs Stored Formula")
	ch["techniques"] = ["stored_formula"]
	check(Alch.block(d, run, ch, 1) == "" and Alch.brewable(d, run, ch) == [spell], "only spells can be brewed")
	var id := Alch.brew(d, run, ch, spell, 1, 1)
	var pot := CR.resolve(d, id, run["cards"])
	check(id != "" and run["backpack"].has(id) and bool(pot["consumable"]) and bool(pot["quick"]), "the potion goes in the backpack")
	check(CR.cost(d, pot) == 0, "and costs no MP")
	check(Alch.brew(d, run, ch, spell, 1, 1) == "" and Alch.block(d, run, ch, 1) == "brewed", "once a night")
	ch["techniques"] = ["stored_formula", "volatile_brewing", "grand_reagent"]
	var strong := CR.resolve(d, Alch.brew(d, run, ch, spell, 2, 1), run["cards"])
	check(bool(strong.get("volatile", false)) and str(strong["magnitude"]) != str(CR.resolve(d, spell)["magnitude"]), "Volatile Brewing: a Magnitude higher")
	var grand := CR.resolve(d, Alch.brew(d, run, ch, spell, 3, 1, true), run["cards"])
	check(str(grand["magnitude"]) == "grand" and not Alch.grand_ready(run, ch, 1) and Alch.grand_ready(run, ch, 2), "Grand Reagent: top Magnitude, once a week")
	# Using one in a fight.
	var f := _tech_fight([], "pom_pom_wisp", ["heat"])
	var lib: Dictionary = { "pot:9": pot }
	f["st"].library.merge(lib, true)
	f["st"].backpack = ["pot:9"]
	var hp0: int = f["foe"].hp
	var mp0: int = f["me"].mp
	check(f["st"].use_backpack(f["me"], 0) and f["foe"].hp < hp0 and f["me"].mp == mp0, "a potion hits the nearest enemy for no MP")
	# Backfire, and Mutation Mastery.
	var v := pot.duplicate()
	v["volatile"] = true
	var lost := 0
	var safe := 0
	for s in 40:
		var a := _tech_fight([], "pom_pom_wisp", ["heat"])
		a["st"].rng.seed = s
		var h0: int = a["me"].hp
		a["st"]._use_potion(a["me"], v)
		lost += 1 if a["me"].hp < h0 else 0
		var b := _tech_fight(["mutation_mastery"], "pom_pom_wisp", ["heat"])
		b["st"].rng.seed = s
		var h1: int = b["me"].hp
		b["st"]._use_potion(b["me"], v)
		safe += 1 if b["me"].hp < h1 else 0
	check(lost > 0 and safe == 0, "volatile potions can backfire (%d of 40); never with Mutation Mastery" % lost)
	# The Alchemist can be reached now.
	check(d["techniques"]["techniques"].any(func(t) -> bool: return str(t["id"]) == "stored_formula" and not t.has("planned")), "Stored Formula, the Alchemist's requirement, can be learned")


func test_damage_type_fluency() -> void:
	var f := _tech_fight(["damage_type_fluency"], "hall_rusher", ["force", "binding"])
	var card := { "id": "t", "vectors": { "force": 1.0 }, "form": "bolt", "magnitude": "minor", "kind": "spell" }
	var out: Dictionary = f["st"]._fluent(f["me"], card, f["foe"].cell)
	check(out["vectors"].has("binding"), "a Force spell at a Binding-weak enemy turns to Binding")
	check(f["st"]._fluent(f["me"], card, f["foe"].cell)["vectors"].has("force"), "once a turn")
	var g := _tech_fight([], "hall_rusher", ["force", "binding"])
	check(g["st"]._fluent(g["me"], card, g["foe"].cell)["vectors"].has("force"), "not without the Technique")

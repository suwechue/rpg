## M7: signature, floors, boss floor, room logic, rewards.
extends "res://tests/suite.gd"

const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Sig := preload("res://src/core/dungeon/signature.gd")
const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const Night := preload("res://src/core/dungeon/night.gd")
const Char := preload("res://src/core/character.gd")


func fresh(seed_value: int = 1) -> Dictionary:
	return RM.new_run(db(), seed_value, "mage", seeded(seed_value))


func count_types(f: Dictionary) -> Dictionary:
	var out := {}
	for r in f["rooms"]:
		out[r["type"]] = int(out.get(r["type"], 0)) + 1
	return out


func test_signature_shifts_with_town_events() -> void:
	var run := fresh()
	check(Sig.dominant(db(), run, 2) == "cold", "week 2 leans Cold")
	Fx.apply(db(), run, { "signature": { "heat": 10 } }, seeded(1), {})
	check(Sig.dominant(db(), run, 2) == "heat", "a town event can tip the week toward Heat")
	check(Sig.hint(db(), run, 2) != "", "a hint describes the leaning, not the numbers")
	run["signature"] = {}
	var w := Sig.enemy_weights(db(), run, 1, "normal")
	check(w.has("pom_pom_wisp") and not w.has("hollow_mascot"), "week 1 normals only")
	check(float(w["megaphone_mimic"]) > float(w["detention_slip"]), "Force/Light week favors Force enemies over Binding ones")


func test_weekday_floors() -> void:
	var run := fresh(3)
	var expect := { "mon": 6, "tue": 7, "wed": 8, "thu": 9 }
	for day in expect:
		var f := Gen.generate(db(), run, 2, str(day))
		check(f["rooms"].size() == int(expect[day]), "%s has %d rooms in all" % [day, expect[day]])
		var t := count_types(f)
		check(t.get("start", 0) == 1 and t.get("exit", 0) == 1 and t.get("rest", 0) == 1, "%s has a start, an exit and a rest room" % day)
		var cells := {}
		for r in f["rooms"]:
			cells[Vector2i(int(r["cell"][0]), int(r["cell"][1]))] = true
		check(cells.size() == f["rooms"].size(), "%s rooms don't overlap" % day)
		for r in f["rooms"]:
			if r["type"] != "start":
				check(not Gen.neighbors(f, r).is_empty(), "%s room %d is connected" % [day, r["id"]])
	check(count_types(Gen.generate(db(), run, 2, "tue")).get("elite", 0) == 1, "Tuesday adds an elite")
	var wed := count_types(Gen.generate(db(), run, 2, "wed"))
	check(wed.get("event", 0) == 1 and wed.get("treasure", 0) == 1, "Wednesday adds an event and a treasure room")
	var thu := count_types(Gen.generate(db(), run, 2, "thu"))
	check(thu.get("elite", 0) == 2 and thu.get("merchant", 0) == 1, "Thursday: 2 elites and a merchant")
	var a := Gen.generate(db(), run, 2, "wed")
	var b := Gen.generate(db(), fresh(3), 2, "wed")
	check(JSON.stringify(a) == JSON.stringify(b), "same seed, same floor")
	check(JSON.stringify(a) != JSON.stringify(Gen.generate(db(), fresh(4), 2, "wed")), "different seed, different floor")
	for r in Gen.generate(db(), run, 1, "tue")["rooms"]:
		check(r["enemies"].size() <= 2, "week 1 fights have at most 2 enemies")


func test_boss_floor_returning_fled_first() -> void:
	var run := fresh(5)
	run["encounter_log"] = [
		{ "week": 1, "day": "mon", "room": 1, "enemies": ["pom_pom_wisp"], "result": "win" },
		{ "week": 1, "day": "tue", "room": 2, "enemies": ["locker_lurker", "detention_slip"], "result": "flee" },
		{ "week": 1, "day": "wed", "room": 3, "enemies": ["megaphone_mimic"], "result": "win" },
		{ "week": 0, "day": "wed", "room": 3, "enemies": ["frost_wolf"], "result": "flee" } ]
	var f := Gen.generate(db(), run, 1, "fri")
	check(f["boss"] and count_types(f).get("boss", 0) == 1, "Friday is the boss floor")
	var ret: Array = []
	for r in f["rooms"]:
		if r.get("returning", false):
			ret.append(r)
	check(ret.size() == 3, "3 returning encounters")
	check(ret[0]["enemies"] == ["locker_lurker", "detention_slip"] and ret[0]["fled"], "the one you fled comes back first")
	check(float(ret[0]["scale"]) > float(ret[1]["scale"]), "and stronger")
	var types: Array = []
	for r in f["rooms"]:
		types.append(r["type"])
	check(types.find("rest") < types.find("boss") and types.find("boss") < types.find("exit"), "rest, then boss, then the exit")
	check(f["rooms"][types.find("boss")]["enemies"] == ["hollow_mascot"], "week 1 boss is The Hollow Mascot")


func test_party_scaling() -> void:
	var room := { "type": "combat", "enemies": ["pom_pom_wisp", "megaphone_mimic", "locker_lurker", "detention_slip"], "scale": 1.0 }
	check(Night.fight_enemies(db(), room, 1).size() == 2, "solo: half the enemies")
	check(Night.fight_enemies(db(), room, 4).size() == 4, "full party: all of them")
	check(float(Night.fight_enemies(db(), room, 1)[0]["scale"]) < 1.0, "and weaker")
	var boss := { "type": "boss", "enemies": ["hollow_mascot"] }
	check(Night.fight_enemies(db(), boss, 1).size() == 1, "the boss always comes")


func test_rest_treasure_shards() -> void:
	var run := fresh(7)
	run["player"]["hp"] = 1
	run["player"]["mp"] = 0
	var room := { "type": "rest" }
	Night.rest(db(), run, room)
	var d := Char.derived(db(), run["player"])
	check(run["player"]["hp"] == d["maxHp"] and run["player"]["mp"] == d["maxMp"] and room["cleared"], "rest restores HP and MP")
	var m0: int = run["money"]
	Night.open_treasure(db(), run, { "type": "treasure" }, 1, seeded(2))
	check(run["money"] > m0, "treasure pays")
	run["player"]["knownVectors"] = ["heat"]
	Night.add_shard(db(), run, "cold")
	Night.add_shard(db(), run, "cold")
	check(not run["player"]["knownVectors"].has("cold"), "two shards aren't enough")
	Night.add_shard(db(), run, "cold")
	check(run["player"]["knownVectors"].has("cold"), "three Cold shards teach Cold")
	Night.add_shard(db(), run, "corrosion")
	Night.add_shard(db(), run, "corrosion")
	Night.add_shard(db(), run, "corrosion")
	check(not run["player"]["knownVectors"].has("corrosion"), "Tier 3 shards wait for Knowledge Tier 3")


func test_after_combat_logs_and_rewards() -> void:
	var run := fresh(8)
	var room := { "id": 2, "type": "combat", "enemies": ["pom_pom_wisp"] }
	Night.after_combat(db(), run, room, { "result": "flee" }, 1, "tue", seeded(1))
	check(run["encounter_log"].size() == 1 and run["encounter_log"][0]["result"] == "flee" and room["fled"], "fleeing is logged for Friday")
	var boss_room := { "id": 9, "type": "boss", "enemies": ["hollow_mascot"] }
	Night.after_combat(db(), run, boss_room, { "result": "win" }, 1, "fri", seeded(1))
	check(run["encounter_log"].size() == 1, "boss fights aren't logged as returning encounters")
	var forms0: int = run["player"]["knownForms"].size()
	var lines := Night.boss_reward(db(), run, 1, seeded(1))
	check(RM.flag(run, "week1_cleared") and run["player"]["knownForms"].size() == forms0 + 1, "clearing week 1 teaches a Form and sets the flag")
	check(lines.size() >= 2, "the reward is narrated")
	Night.boss_reward(db(), run, 2, seeded(1))
	check(int(run["player"]["knowledgeTier"]) == 2, "week 2's boss raises the Knowledge Tier")


func test_hollow_mascot_phases() -> void:
	var boss: Dictionary = DT.index_under(db(), "enemies/", "enemies")["hollow_mascot"]
	check(boss["phases"].size() == 3 and boss["tier"] == "boss", "three phases")
	check(ResourceLoader.exists(str(boss["sprite"])), "boss sprite exists")
	var st = preload("res://src/core/combat/combat_state.gd").new(db(), seeded(1), {
		"layout": DT.record(db(), "rooms/combat_layouts", "boss_stage"), "party": [{ "char": fresh(1)["player"] }], "enemies": [boss.duplicate(true)], "boss": true })
	var m = null
	for u in st.units:
		if u.boss:
			m = u
	st._damage(m, 40, null, "", "test")
	check(m.phase_index == 1, "below 66% HP: phase 2")
	var summoned := 0
	for u in st.units:
		if u.team == "enemy" and not u.boss:
			summoned += 1
	check(summoned == 1, "it summons a Pom-Pom Wisp")
	st._damage(m, 25, null, "", "test")
	check(m.phase_index == 2 and m.movement == 4, "below 33%: the final phase")
	check(not st.can_flee(), "no fleeing the boss")

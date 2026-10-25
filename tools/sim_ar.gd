## Balance tool (not a test) for docs/ARENA.md Part 4b: week 1 fights built
## from encounter templates, AI on both sides, each fight from full HP/MP.
## Reports win rate and rounds for a full party that reads telegraphs, one
## that ignores them, a solo player, and the week 1 boss, per turn mode.
## Run: godot --headless --path . -s res://tools/sim_ar.gd [-- --runs=40 --week=1 --modes=all]
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Enc := preload("res://src/core/dungeon/encounters.gd")
const Night := preload("res://src/core/dungeon/night.gd")
const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const Bonds := preload("res://src/core/social/bonds.gd")
const Char := preload("res://src/core/character.gd")
const Lv := preload("res://src/core/progression/leveling.gd")

const ALLIES := ["theo", "mara", "dex"]
static var INTENTS := {}


func _initialize() -> void:
	var db := DT.tables()
	var runs := 40
	var week := 1
	var modes: Array = ["move_or_act"]
	var diffs: Array = ["normal", "hard"]
	for a in OS.get_cmdline_user_args():
		var kv := str(a).trim_prefix("--").split("=")
		if kv[0] == "runs":
			runs = int(kv[1])
		elif kv[0] == "week":
			week = int(kv[1])
		elif kv[0] == "modes" and kv[1] == "all":
			modes = db["combat_rules"]["turnModes"]
		elif kv[0] == "difficulty":
			diffs = [kv[1]]
	print("week %d, %d fights per row (normal fights from templates; boss from the week's boss room)" % [week, runs])
	print("%-14s %-18s %8s %8s %8s %8s" % ["mode", "case", "win%", "rounds", "dmg/fight", "hits/fight"])
	for diff in diffs:
		for mode in modes:
			print("-- %s --" % diff)
			for case in [["full, reads", 4, 1.2, false], ["full, ignores", 4, 0.0, false], ["solo, reads", 1, 1.2, false], ["full, boss", 4, 1.2, true]]:
				var wins := 0
				var rounds := 0
				var taken := 0
				var hits := 0
				for s in runs:
					var r := fight(db, week, 5000 + s, int(case[1]), float(case[2]), bool(case[3]), str(mode), str(diff))
					if r["win"]:
						wins += 1
					rounds += int(r["rounds"])
					taken += int(r["taken"])
					hits += int(r["hits"])
				print("%-14s %-18s %7d%% %8.1f %9.1f %9.1f" % [mode, case[0], roundi(100.0 * wins / runs), float(rounds) / runs, float(taken) / runs, float(hits) / runs])
	print("intent kinds planned: ", INTENTS)
	quit()


## One fight: a party of `size` (player + allies, level by week), the AI
## dodging telegraphs with `dodge` weight, against a template fight or the boss.
static func fight(db: Dictionary, week: int, seed_value: int, size: int, dodge: float, boss: bool, mode: String, difficulty: String = "normal") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var classes := ["mage", "fighter", "rogue", "healer", "bard"]
	var run := RM.new_run(db, seed_value, classes[seed_value % classes.size()], rng)
	for i in size - 1:
		run["bonds"][ALLIES[i]] = 50.0
		Bonds.recruit(db, run, ALLIES[i], rng)
	var level := 1 + (week - 1) * 2 + (1 if boss else 0)
	for p in [run["player"]] + run["roster"]:
		while int(p["level"]) < level:
			Lv.add_xp(db, p, Lv.xp_to_next(db, int(p["level"])), rng)
		Lv.auto_perks(db, p)
		Char.full_restore(db, p)
	var room: Dictionary
	if boss:
		var f := Gen.generate(db, run, week, "fri")
		for r in f["rooms"]:
			if str(r["type"]) == "boss":
				room = r
	else:
		var enc := Enc.build(db, run, week, "combat", rng)
		room = { "id": seed_value, "type": "combat", "enemies": enc["enemies"], "roles": enc["roles"], "affixes": enc["affixes"],
			"formation": enc["formation"], "reinforcements": enc["reinforcements"], "scale": float(db["dungeon"]["weekScale"][week]),
			"layout": Gen.pick_layout(db, "school", rng, bool(enc["big"]), str(enc["layoutTag"])) }
	var fs := Night.fight_setup(db, room, size)
	var party: Array = [{ "char": run["player"], "ai": true }]
	for pid in run["party_ids"]:
		party.append({ "char": RM.character(run, str(pid)), "ai": true })
	var st := StateScript.new(db, rng, { "layout": DT.record(db, "rooms/combat_layouts", str(room.get("layout", "open_field"))), "party": party,
		"enemies": fs["enemies"], "boss": boss, "formation": fs["formation"], "roles": fs["roles"], "reinforcements": fs["reinforcements"],
		"turnMode": mode, "difficulty": difficulty, "ai": { "dodgeWeight": dodge } })
	var g := 0
	var taken := 0
	var hits := 0
	while st.result == "" and g < 800:
		AI.take_turn(st, st.current)
		for e in st.take_events():
			if str(e["t"]) == "intent":
				INTENTS[str(e["kind"])] = int(INTENTS.get(str(e["kind"]), 0)) + 1
			if str(e["t"]) == "damage":
				var t := st.unit_by_id(str(e["unit"]))
				if t != null and t.team == "party":
					taken += int(e["amount"])
					hits += 1
		g += 1
	return { "win": st.result == "win", "rounds": st.round_num, "taken": taken, "hits": hits }

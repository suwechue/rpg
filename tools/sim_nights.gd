## Balance tool (not a test): simulates whole dungeon nights headless with the
## AI playing the party, and prints survival per class and day.
## Run: godot --headless --path . -s res://tools/sim_nights.gd
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Night := preload("res://src/core/dungeon/night.gd")
const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const Bonds := preload("res://src/core/social/bonds.gd")


## One night: fight every combat/elite/boss room in order, rest at rest rooms.
## Returns { "alive": bool, "fights": n, "xp": n, "hpEnd": ratio }.
static func night(db: Dictionary, run: Dictionary, week: int, day: String, rng: RandomNumberGenerator) -> Dictionary:
	var f := Night.start(db, run, week, day)
	var idx := DT.index_under(db, "enemies/", "enemies")
	var fights := 0
	var xp := 0
	for room in f["rooms"]:
		var t := str(room["type"])
		if t == "rest":
			Night.rest(db, run, room)
			continue
		if not t in ["combat", "elite", "boss"]:
			continue
		var enemies: Array = Night.fight_enemies(db, room, Night.party_size(run))
		var party: Array = [{ "char": run["player"], "ai": true }]
		for pid in run["party_ids"]:
			party.append({ "char": RM.character(run, str(pid)), "ai": true })
		var st := StateScript.new(db, rng, { "layout": DT.record(db, "rooms/combat_layouts", str(room["layout"])), "party": party, "enemies": enemies, "boss": t == "boss" })
		var g := 0
		while st.result == "" and g < 500:
			AI.take_turn(st, st.current)
			g += 1
		var s := st.finish()
		fights += 1
		if s["result"] != "win":
			return { "alive": false, "fights": fights, "xp": xp, "hpEnd": 0.0, "diedIn": t }
		xp += int(s["xp"])
		for p in [run["player"]] + run["roster"]:
			Lv.add_xp(db, p, int(s["xp"]), rng)
			Lv.auto_perks(db, p)
	return { "alive": true, "fights": fights, "xp": xp, "hpEnd": float(run["player"]["hp"]) }


func _initialize() -> void:
	var db := DT.tables()
	var days := ["mon", "tue", "wed", "thu", "fri"]
	var args := OS.get_cmdline_user_args()
	var allies := 0
	for a in args:
		if str(a).begins_with("--allies="):
			allies = int(str(a).split("=")[1])
	for cls in ["mage", "fighter", "rogue", "healer", "bard"]:
		var line := "%-8s" % cls
		for day in ["tue", "wed", "thu", "fri"]:
			var alive := 0
			var n := 20
			for s in n:
				var rng := RandomNumberGenerator.new()
				rng.seed = 7000 + s
				var run := RM.new_run(db, 7000 + s, cls, rng)
				for i in allies:
					var ids := ["theo", "mara", "dex", "priya"]
					run["bonds"][ids[i]] = 50.0
					Bonds.recruit(db, run, ids[i], rng)
				# a week of growth before this night: levels by day index
				var lvl := 1 + days.find(day)
				for p in [run["player"]] + run["roster"]:
					while int(p["level"]) < lvl:
						Lv.add_xp(db, p, Lv.xp_to_next(db, int(p["level"])), rng)
					Lv.auto_perks(db, p)
					preload("res://src/core/character.gd").full_restore(db, p)
				if night(db, run, 1, day, rng)["alive"]:
					alive += 1
			line += "  %s %2d/%d" % [day, alive, n]
		print(line)
	quit()

## Balance tool (not a test): simulates whole dungeon nights headless with the
## AI playing the party, and prints survival per class and day.
## Run: godot --headless --path . -s res://tools/sim_nights.gd
## Campaign mode (Oct 29 balance pass): -- --campaign --difficulty=normal --allies=3 --n=20
## plays weeks 1 to 5 (Tue to Fri nights) in order with XP carried over and the
## real difficulty and weekly ramp, and prints night survival per week and how
## many campaigns finish.
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Night := preload("res://src/core/dungeon/night.gd")
const Gen := preload("res://src/core/dungeon/floor_generator.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const Bonds := preload("res://src/core/social/bonds.gd")
const CR := preload("res://src/core/run/card_rewards.gd")


## One night: fight every combat/elite/boss room in order, rest at rest rooms.
## Returns { "alive": bool, "fights": n, "xp": n, "hpEnd": ratio }.
static func night(db: Dictionary, run: Dictionary, week: int, day: String, rng: RandomNumberGenerator, diff: String = "") -> Dictionary:
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
		var fs := Night.fight_setup(db, room, Night.party_size(run))
		var enemies: Array = fs["enemies"]
		var party: Array = [{ "char": run["player"], "ai": true }]
		for pid in run["party_ids"]:
			party.append({ "char": RM.character(run, str(pid)), "ai": true })
		var start_hp := int(run["player"]["hp"])
		var setup := { "layout": DT.record(db, "rooms/combat_layouts", str(room["layout"])), "party": party, "enemies": enemies, "boss": t == "boss",
			"formation": fs["formation"], "roles": fs["roles"], "reinforcements": fs["reinforcements"] }
		if diff != "":
			setup["difficulty"] = diff
			setup["ramp"] = StateScript.ramp_for(db, week, 0)
			setup["storyNight"] = true
			run["combat_difficulty"] = diff
		var st := StateScript.new(db, rng, setup)
		var g := 0
		while st.result == "" and g < 500:
			AI.take_turn(st, st.current)
			g += 1
		if st.round_num > 30 and OS.get_cmdline_user_args().has("--trace"):
			var who: Array = []
			for u in st.units:
				if not u.is_prop() and u.alive():
					who.append("%s(%s) hp%d/%d sh%d mp%d @%s st=%s" % [u.name, u.team, u.hp, u.max_hp, u.shield, u.mp, str(u.cell), str(u.statuses.keys())])
			print("LONG w%d %s %s rounds=%d result=%s cur=%s | %s" % [week, day, t, st.round_num, st.result, st.current.name if st.current != null else "-", " ; ".join(PackedStringArray(who))])
		var s := st.finish()
		fights += 1
		if s["result"] != "win" and OS.get_cmdline_user_args().has("--trace"):
			var hits: Array = []
			for ev in st.events:
				if str(ev.get("t", "")) == "damage" and str(ev.get("unit", "")) == "player":
					hits.append("%s:%d" % [str(ev.get("cause", "")) + "/" + str(ev.get("vector", "")), int(ev.get("amount", 0))])
			var foes: Array = enemies.map(func(e: Variant) -> String: return str(e.get("id", e)) if e is Dictionary else str(e))
			print("DEATH w%d %s %s room#%d rounds=%d startHp=%d/%d lvl=%d foes=%s hits=%s" % [week, day, t, fights, st.round_num, start_hp, int(preload("res://src/core/character.gd").derived(db, run["player"])["maxHp"]), int(run["player"]["level"]), str(foes), str(hits)])
		if s["result"] != "win":
			return { "alive": false, "fights": fights, "xp": xp, "hpEnd": 0.0, "diedIn": t }
		xp += int(s["xp"])
		Night.after_fight(db, run)
		for p in [run["player"]] + run["roster"]:
			Lv.add_xp(db, p, int(s["xp"]), rng)
			Lv.auto_perks(db, p)
	return { "alive": true, "fights": fights, "xp": xp, "hpEnd": float(run["player"]["hp"]) }


## Weeks 1 to 5, Tue to Fri, in order; XP carries over; full HP each morning.
static func campaign(db: Dictionary, cls: String, seed_value: int, diff: String, allies: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RM.new_run(db, seed_value, cls, rng)
	var ids := ["theo", "mara", "dex", "priya"]
	for i in allies:
		run["bonds"][ids[i]] = 50.0
		Bonds.recruit(db, run, ids[i], rng)
	var nights := 0
	# --fromweek=N starts later, already levelled (quick looks at late fights).
	var from_week := 1
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--fromweek="):
			from_week = int(str(a).split("=")[1])
	for p in [run["player"]] + run["roster"]:
		while int(p["level"]) < 1 + (from_week - 1) * 4:
			Lv.add_xp(db, p, Lv.xp_to_next(db, int(p["level"])), rng)
		Lv.auto_perks(db, p)
	for week in range(from_week, 6):
		for day in ["tue", "wed", "thu", "fri"]:
			for p in [run["player"]] + run["roster"]:
				preload("res://src/core/character.gd").full_restore(db, p)
			# Gear by week (data/gear.json simTiers), as a player would buy and forge it.
			for p in [run["player"]] + run["roster"]:
				preload("res://src/core/combat/balance_report.gd")._wear(db, p, week - 1)
				preload("res://src/core/character.gd").full_restore(db, p)
			var r := night(db, run, week, day, rng, diff)
			# The card pick on the way out goes to whoever can use it.
			if bool(r["alive"]):
				run["day_count"] = int(run.get("day_count", 0)) + 1
				var picks: Array = CR.offer(db, run, week, "boss" if day == "fri" else "floor")
				if not picks.is_empty():
					var who := str(preload("res://src/core/arena/arena.gd").auto_owner(db, run, preload("res://src/core/card.gd").resolve(db, str(picks[0]))))
					if who != "":
						(RM.character(run, who)["deck"] as Array).append(str(picks[0]))
			if not bool(r["alive"]):
				return { "nights": nights, "week": week, "day": day, "level": int(run["player"]["level"]), "diedIn": str(r.get("diedIn", "")) }
			nights += 1
	return { "nights": nights, "week": 6, "level": int(run["player"]["level"]) }


func _campaigns(db: Dictionary, args: Array) -> void:
	var diff := "normal"
	var allies := 3
	var n := 10
	for a in args:
		var kv := str(a).trim_prefix("--").split("=")
		if kv.size() < 2:
			continue
		match kv[0]:
			"difficulty":
				diff = kv[1]
			"allies":
				allies = int(kv[1])
			"n":
				n = int(kv[1])
	print("Campaign, %s, %d allies, %d runs per class" % [diff, allies, n])
	var total_done := 0
	var total := 0
	var deaths_by_week := [0, 0, 0, 0, 0, 0, 0]
	var nights_lived := 0
	for cls in ["mage", "fighter", "rogue", "healer", "bard"]:
		var done := 0
		var reached: Array = []
		for s in n:
			var r := campaign(db, cls, 9100 + s, diff, allies)
			nights_lived += int(r["nights"])
			total += 1
			if int(r["week"]) >= 6:
				done += 1
			else:
				deaths_by_week[int(r["week"])] += 1
			reached.append("w%d%s L%d" % [int(r["week"]), str(r.get("day", "")).substr(0, 2), int(r["level"])])
		total_done += done
		print("%-8s finished %d/%d  %s" % [cls, done, n, " ".join(PackedStringArray(reached))])
	var nights_tried := nights_lived + (total - total_done)
	print("All: %d/%d campaigns finished; night survival %.1f%%; deaths by week %s" % [total_done, total, 100.0 * float(nights_lived) / float(maxi(1, nights_tried)), str(deaths_by_week.slice(1, 6))])


func _initialize() -> void:
	var db := DT.tables()
	if OS.get_cmdline_user_args().has("--campaign"):
		_campaigns(db, OS.get_cmdline_user_args())
		quit()
		return
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

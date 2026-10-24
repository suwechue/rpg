## Balance tool (not a test): week 1 fights back to back with a duo party
## (player + one ally, AI on both sides). Prints win rate, average rounds per
## fight and MP left after fights 1 and 2, per class.
## Run: godot --headless --path . -s res://tools/sim_fights.gd [-- --runs=20]
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Night := preload("res://src/core/dungeon/night.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const Bonds := preload("res://src/core/social/bonds.gd")
const Char := preload("res://src/core/character.gd")


func _initialize() -> void:
	var db := DT.tables()
	var runs := 20
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--runs="):
			runs = int(str(a).split("=")[1])
	var layouts := ["open_field", "locker_hall", "bleachers"]
	var foes := [["pom_pom_wisp", "megaphone_mimic"], ["bleacher_creeper", "locker_lurker"], ["spirit_stick", "detention_slip"]]
	var idx := DT.index_under(db, "enemies/", "enemies")
	print("class    wins     rounds  mp1   mp2   maxMp")
	for cls in ["mage", "fighter", "rogue", "healer", "bard"]:
		var wins := 0
		var fights := 0
		var rounds := 0
		var mp1 := 0.0
		var mp2 := 0.0
		var max_mp := 0
		for s in runs:
			var rng := RandomNumberGenerator.new()
			rng.seed = 9100 + s
			var run := RM.new_run(db, 9100 + s, cls, rng)
			run["bonds"]["theo"] = 50.0
			Bonds.recruit(db, run, "theo", rng)
			max_mp = int(Char.derived(db, run["player"])["maxMp"])
			for f in 3:
				var party: Array = [{ "char": run["player"], "ai": true }]
				for pid in run["party_ids"]:
					party.append({ "char": RM.character(run, str(pid)), "ai": true })
				var enemies: Array = []
				for e in foes[(s + f) % foes.size()]:
					enemies.append(idx[e].duplicate(true))
				var layout := DT.record(db, "rooms/combat_layouts", layouts[(s + f) % layouts.size()])
				var st := StateScript.new(db, rng, { "layout": layout, "party": party, "enemies": enemies })
				var g := 0
				while st.result == "" and g < 600:
					AI.take_turn(st, st.current)
					g += 1
				var sm := st.finish()
				fights += 1
				rounds += int(sm["rounds"])
				var pct := float(run["player"].get("mp", 0)) / float(maxi(1, max_mp))
				if f == 0:
					mp1 += pct
				elif f == 1:
					mp2 += pct
				if sm["result"] != "win":
					break
				wins += 1
				Night.recover(db, run, float(db["dungeon"].get("afterFightHpPct", 0.0)))
		print("%-8s %3d/%-3d  %5.1f   %3d%%  %3d%%  %d" % [cls, wins, fights, float(rounds) / float(maxi(1, fights)),
			roundi(100.0 * mp1 / float(runs)), roundi(100.0 * mp2 / float(runs)), max_mp])
	quit()

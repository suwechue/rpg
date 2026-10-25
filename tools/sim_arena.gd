## Balance tool (not a test): the AI plays the Endless Arena until the party
## falls (or a wave cap), and reports the average wave reached per class and
## party size, plus where runs end (wave and hazard set).
## Run: godot --headless --path . -s res://tools/sim_arena.gd [-- --runs=10 --cap=30 --sizes=1,4]
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const Arena := preload("res://src/core/arena/arena.gd")
const Party := preload("res://src/core/arena/arena_party.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")


func _initialize() -> void:
	var db := DT.tables()
	var runs := 10
	var cap := 30
	var sizes := [1, 4]
	for a in OS.get_cmdline_user_args():
		var kv := str(a).trim_prefix("--").split("=")
		match kv[0]:
			"runs":
				runs = int(kv[1])
			"cap":
				cap = int(kv[1])
			"sizes":
				sizes = Array(kv[1].split(",")).map(func(x: String) -> int: return int(x))
	var deaths_by_wave := {}
	var deaths_by_hazard := {}
	print("%-8s %-5s %8s %8s" % ["class", "party", "avgWave", "best"])
	for size in sizes:
		for cls in ["mage", "fighter", "rogue", "healer", "bard"]:
			var total := 0
			var best := 0
			for s in runs:
				var r := play(db, 8000 + s, cls, int(size), cap)
				total += int(r["cleared"])
				best = maxi(best, int(r["cleared"]))
				if not r["survived"]:
					deaths_by_wave[r["diedOn"]] = int(deaths_by_wave.get(r["diedOn"], 0)) + 1
					deaths_by_hazard[r["hazard"]] = int(deaths_by_hazard.get(r["hazard"], 0)) + 1
			print("%-8s %-5d %8.1f %8d" % [cls, size, float(total) / runs, best])
	print("runs ended on wave: ", deaths_by_wave)
	print("runs ended on hazard set: ", deaths_by_hazard)
	quit()


## One arena run. Returns { "cleared", "survived", "diedOn", "hazard" }.
static func play(db: Dictionary, seed_value: int, cls: String, size: int, cap: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := Party.preset_run(db, seed_value, cls, size, 3, rng)
	var arena := Arena.new_arena(seed_value, false)
	for wave in range(1, cap + 1):
		arena["wave"] = wave
		var setup := Arena.setup_for_wave(db, arena, wave)
		var party: Array = []
		for ch in Party.party(run):
			if int(ch.get("hp", 0)) > 0:
				party.append({ "char": ch, "ai": true })
		setup["party"] = party
		var st := StateScript.new(db, rng, setup)
		var g := 0
		while st.result == "" and g < 900:
			AI.take_turn(st, st.current)
			g += 1
		var sm := st.finish()
		if str(sm["result"]) != "win":
			return { "cleared": wave - 1, "survived": false, "diedOn": wave, "hazard": str(setup["layout"].get("hazard", "")) }
		Arena.wave_won(db, arena, { "rounds": int(sm["rounds"]) })
		for ch in Party.party(run):
			ch["hp"] = maxi(1, int(ch.get("hp", 1)))
		Arena.breather(db, Party.party(run))
		if Arena.is_checkpoint(db, wave):
			Arena.checkpoint(db, arena)
			if Arena.spend(db, arena, "rest"):
				Arena.rest(db, Party.party(run))
			if not arena["offered"].is_empty():
				Arena.choose_mutator(arena, str(arena["offered"][0]["id"]))
	return { "cleared": cap, "survived": true, "diedOn": -1, "hazard": "" }

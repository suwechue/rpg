## Lab Tuner (docs/LAB_TUNER.md): the sweep runner, the AI players, the fun
## metrics and score, the search and the shortlist.
extends "res://tests/suite.gd"

const Sweep := preload("res://src/core/lab/sweep.gd")
const Plan := preload("res://src/core/lab/tuner/plan.gd")
const Metrics := preload("res://src/core/lab/tuner/metrics.gd")
const Search := preload("res://src/core/lab/tuner/search.gd")
const Tuned := preload("res://src/core/lab/tuner/tuned_presets.gd")
const Report := preload("res://src/core/lab/tuner/tune_report.gd")
const Play := preload("res://src/core/lab/play_text.gd")
const Rules := preload("res://src/core/combat/rules.gd")
const Player := preload("res://src/core/lab/players/player.gd")
const Legal := preload("res://src/core/lab/players/legal.gd")
const Sim := preload("res://src/core/lab/players/sim.gd")
const Eval := preload("res://src/core/lab/players/evaluator.gd")
const Setup := preload("res://src/core/lab/lab_setup.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")

const VOLATILE := ["at", "seconds", "usec"]


func _strip(line: Dictionary) -> Dictionary:
	var out := line.duplicate(true)
	for k in VOLATILE:
		out.erase(k)
	return out


# --- Part 1: the runner -----------------------------------------------------------

func test_same_cell_same_result() -> void:
	var cell := { "fight": "ledge_day", "preset": "cl_base", "seed": 3, "profile": "novice" }
	var a := _strip(Sweep.run_fight(db(), cell))
	var b := _strip(Sweep.run_fight(db(), cell))
	check(JSON.stringify(a) == JSON.stringify(b), "the same plan and seed give the same line")
	check(str(a.get("result", "")) in ["win", "lose", "stall"], "a sweep line has a result")
	check(a.has("levers") and a.has("turns") == false and a.has("ai") and a.has("boardKills"), "a sweep line has the Lab log fields, the lever set and the AI turns")
	check(str(a.get("key", "")) == Sweep.cell_key(cell), "a line carries its cell key")


func test_cell_keys_survive_json() -> void:
	var cell := { "fight": "thin_ice", "preset": "cl_base", "levers": { "handSize": 5, "enemyHpMul": 1.5 }, "seed": 2, "profile": "expert" }
	var back: Dictionary = JSON.parse_string(JSON.stringify(cell))
	check(Sweep.cell_key(cell) == Sweep.cell_key(back), "2 and 2.0 give the same key, so a resumed run skips what it played")


func test_stalls_are_results() -> void:
	var d := db().duplicate()
	var t: Dictionary = d["lab/tuner"].duplicate(true)
	t["stallRounds"] = 1
	d["lab/tuner"] = t
	var line := Sweep.run_fight(d, { "fight": "hollow_mascot", "preset": "cl_base", "seed": 1, "profile": "random" })
	check(str(line["result"]) == "stall", "a fight past the stall limit ends as a stall, not a crash (got %s)" % line["result"])
	var m := Metrics.summarize([line], t)
	check(float(m["stallShare"]) > 0.0 and Metrics.fun_score(m, t)["dq"], "a stall counts against the lever set")


func test_resume_and_jobs() -> void:
	var plan := { "presets": ["cl_base", "current"], "fights": ["ledge_day", "thin_ice"], "seeds": 3, "profiles": ["expert", "random"] }
	var cells := Plan.grid_cells(db(), plan)
	check(cells.size() == 2 * 2 * 3 * 2, "a grid plan has fights x presets x seeds x profiles cells")
	var done := {}
	for i in 5:
		done[Sweep.cell_key(cells[i])] = true
	check(Plan.pending(cells, done).size() == cells.size() - 5, "a resumed run skips the cells already played")
	var seen := {}
	var total := 0
	for j in 4:
		for c in Plan.share(cells, j, 4):
			seen[Sweep.cell_key(c)] = int(seen.get(Sweep.cell_key(c), 0)) + 1
			total += 1
	check(total == cells.size() and seen.size() == cells.size(), "jobs split the cells with none left out or doubled")
	var a := [{ "key": "x", "v": 1 }, { "key": "y", "v": 1 }]
	var b := [{ "key": "y", "v": 2 }, { "key": "z", "v": 2 }]
	var merged := Plan.merge([a, b])
	check(merged.size() == 3 and int(merged[1]["v"]) == 1, "merging jobs keeps each cell once")


func test_screening_flips_one_lever() -> void:
	var plan := { "bases": ["cl_base"], "skipGroups": ["feel"], "numeric": { "handSize": [3, 5] } }
	var vars := Plan.screen_variants(db(), plan)
	check(str(vars[0]["lever"]) == "" and vars[0]["levers"].is_empty(), "screening plays the base too")
	var hand := vars.filter(func(v: Dictionary) -> bool: return str(v["lever"]) == "handSize")
	check(hand.size() == 2, "a numeric lever tries the plan's values, not the base's own")
	var fog := vars.filter(func(v: Dictionary) -> bool: return str(v["lever"]) == "fog")
	check(fog.size() == 1 and bool(fog[0]["value"]), "a switch flips")
	check(vars.all(func(v: Dictionary) -> bool: return v["levers"].size() <= 1), "one lever at a time")
	var cells := Plan.screen_cells(db(), { "bases": ["cl_base"], "levers": ["iceSlide"], "fights": ["ledge_day", "crowded_hall"], "seeds": 1, "profiles": ["random"] })
	var ice := cells.filter(func(c: Dictionary) -> bool: return c["levers"].has("iceSlide"))
	check(not ice.is_empty() and ice.all(func(c: Dictionary) -> bool: return str(c["fight"]) == "thin_ice"), "a lever plays only the fights it lists")


func test_sweep_plans_are_valid() -> void:
	for id in ["baseline", "screening", "pairs", "search", "shortlist"]:
		var p: Dictionary = db().get("lab/sweeps/" + id, {})
		check(not p.is_empty() and str(p.get("id", "")) == id, "plan %s exists" % id)
		check(str(p.get("kind", "")) in ["grid", "screen", "pairs", "search"], "plan %s has a kind" % id)
	var base: Dictionary = db()["lab/sweeps/baseline"]
	check(base["presets"].size() == 7 and int(base["seeds"]) == 30 and base["profiles"].size() == 4, "the baseline is every preset, 30 seeds, 4 players")


# --- Part 2: the AI players -------------------------------------------------------

func test_four_profiles() -> void:
	for p in Player.PROFILES:
		check(not Player.profile(db(), p).is_empty(), "profile %s is in data/lab/players.json" % p)
	check(not Eval.cfg(db()).get("weights", {}).is_empty(), "the shared state score has weights in data")


## Expert beats greedy beats random on today's rules (wins, then HP left).
func test_skill_order_on_current() -> void:
	var score := {}
	for p in ["expert", "greedy", "random"]:
		var s := 0.0
		for f in ["ledge_day", "crowded_hall", "fire_sale"]:
			for seed_value in [1, 2]:
				var line := Sweep.run_fight(db(), { "fight": f, "preset": "current", "seed": seed_value, "profile": p })
				s += (1.0 if str(line["result"]) == "win" else 0.0) + float(line["partyHpLeft"]) - float(line["rounds"]) * 0.02
		score[p] = s
	check(float(score["expert"]) > float(score["greedy"]), "expert beats greedy on current (%s)" % str(score))
	check(float(score["greedy"]) > float(score["random"]), "greedy beats random on current (%s)" % str(score))


func _party_turn_state(fight_id: String) -> Object:
	var built := Setup.build(db(), fight_id, "cl_base")
	var st: Object = StateScript.new(db(), seeded(5), built["setup"])
	st.no_undo = true
	var guard := 0
	while st.current.team != "party" and guard < 50:
		AI.take_turn(st, st.current)
		guard += 1
	return st


func test_players_never_read_hidden_information() -> void:
	var st := _party_turn_state("ledge_day")
	var prof := Player.profile(db(), "expert")
	var a: Dictionary = Player.plan_turn(st, st.current, prof, seeded(1))
	var before := Sim.save(st)
	for x in st.units:
		if x.deck != null:
			x.deck.draw_pile.shuffle()
			x.deck.draw_pile.reverse()
	st.rng.seed = 987654
	st.rng.randi()
	var b: Dictionary = Player.plan_turn(st, st.current, prof, seeded(1))
	check(Legal.line_key(a["line"]) == Legal.line_key(b["line"]) and str(a["line"]) == str(b["line"]), "scrambling the deck order and the dice doesn't change the expert's choice")
	Sim.restore(st, before)
	var hand_before: Array = st.current.deck.hand.duplicate()
	Player.plan_turn(st, st.current, prof, seeded(1))
	check(st.current.deck.hand == hand_before and st.result == "", "planning leaves the fight as it was")


func test_legal_steps_apply() -> void:
	var st := _party_turn_state("fire_sale")
	var u: Object = st.current
	var steps := Legal.steps(st, u)
	check(steps.any(func(s: Dictionary) -> bool: return str(s["kind"]) == "end"), "ending the turn is always a step")
	var snap := Sim.save(st)
	var worked := 0
	for s in steps:
		if str(s["kind"]) in ["move", "card", "strike"]:
			Sim.restore(st, snap)
			worked += 1 if Legal.apply(st, u, s) else 0
	Sim.restore(st, snap)
	check(worked > 0, "listed moves and cards can be played")
	check(Legal.line_key([{ "kind": "move", "cell": Vector2i(1, 1) }, { "kind": "strike", "target": Vector2i(2, 1) }]) == "strike@2,1", "a line's key is what it plays, not where it walked")


func test_snapshot_round_trip() -> void:
	var st := _party_turn_state("ledge_day")
	var u: Object = st.current
	var snap := Sim.save(st)
	var cell: Vector2i = u.cell
	var hp: Array = st.units.map(func(x: Object) -> int: return x.hp)
	for s in Legal.steps(st, u):
		if str(s["kind"]) == "move":
			Legal.apply(st, u, s)
			break
	Sim.restore(st, snap)
	check(u.cell == cell and st.units.map(func(x: Object) -> int: return x.hp) == hp, "a restored snapshot puts the fight back")


# --- Part 3: the metrics -----------------------------------------------------------

func _line(prof: String, result: String, extra: Dictionary = {}) -> Dictionary:
	var l := { "profile": prof, "result": result, "fight": "ledge_day", "rounds": 4, "boss": false, "threatened": 10, "telegraphedDamage": 4, "kills": 4, "boardKills": 1,
		"teamwork": 2, "minPartyHp": 0.5, "comeback": false, "plays": { "lab_spark": 2, "lab_shove": 2 }, "opening": "a|b",
		"ai": [{ "load": 10, "values": [5.0, 4.8, 4.6, 1.0] }, { "load": 6, "values": [5.0, 1.0] }] }
	l.merge(extra, true)
	return l


func test_metrics_on_a_hand_built_log() -> void:
	var t: Dictionary = db()["lab/tuner"]
	var lines := [
		_line("expert", "win", { "minPartyHp": 0.2 }), _line("expert", "win"), _line("expert", "lose", { "rounds": 6 }), _line("expert", "win", { "opening": "c|d" }),
		_line("novice", "win"), _line("novice", "lose"), _line("greedy", "lose"), _line("random", "lose"),
	]
	var m := Metrics.summarize(lines, t)
	check_near(float(m["expertWin"]), 0.75, "expert win rate")
	check_near(float(m["noviceWin"]), 0.5, "novice win rate")
	check_near(float(m["randomWin"]), 0.0, "random win rate")
	# Turn 1: values 5.0, 4.8, 4.6 are within 10% of 5.0: 3 real choices; turn 2: 1.
	check_near(float(m["realChoices"]), 2.0, "real choices per turn")
	check_near(float(m["obviousShare"]), 0.5, "obvious turns (the second turn's best leads by 80%)")
	check_near(float(m["optionLoad"]), 8.0, "option load")
	check_near(float(m["closeWins"]), 1.0 / 3.0, "close wins among expert wins")
	check_near(float(m["rounds"]), 4.5, "rounds per fight")
	check_near(float(m["agency"]), 0.6, "telegraphed damage avoided: 1 - 16/40")
	check_near(float(m["boardUse"]), 0.25, "board kills share")
	check_near(float(m["teamwork"]), 2.0, "teamwork per fight")
	check_near(float(m["dominantCard"]), 0.5, "the most-played card's share in wins")
	check_near(float(m["dominantLine"]), 2.0 / 3.0, "the most common winning opening")
	check_near(float(m["variety"]), 1.0, "two cards played evenly: full variety")
	check_near(Metrics.entropy({ "a": 4 }), 0.0, "one card only: no variety")


func test_fun_score_reads_tuner_json() -> void:
	var t: Dictionary = db()["lab/tuner"].duplicate(true)
	var m := { "expertWin": 0.9, "noviceWin": 0.6, "greedyWin": 0.3, "randomWin": 0.05, "realChoices": 3.0, "obviousShare": 0.2, "optionLoad": 20.0,
		"dominantCard": 0.2, "dominantLine": 0.4, "closeWins": 0.3, "rounds": 4.0, "bossRounds": -1.0, "agency": 0.6, "boardUse": 0.3, "teamwork": 3.0, "variety": 0.8, "stallShare": 0.0 }
	var full := Metrics.fun_score(m, t)
	check_near(float(full["score"]), 1.0, "every metric on target scores 1")
	check(not full["dq"], "nothing disqualifies it")
	var worse := m.duplicate()
	worse["realChoices"] = 1.0
	check(float(Metrics.fun_score(worse, t)["score"]) < 1.0, "off target scores lower")
	t["metrics"]["realChoices"]["target"] = [1.0, 2.0]
	check_near(float(Metrics.fun_score(worse, t)["score"]), 1.0, "the targets come from tuner.json")
	var cheat := m.duplicate()
	cheat["randomWin"] = 0.5
	check(Metrics.fun_score(cheat, t)["dq"], "random winning half its fights disqualifies a set")
	cheat = m.duplicate()
	cheat["expertWin"] = 0.5
	check(Metrics.fun_score(cheat, t)["dq"], "an expert under 70% disqualifies a set")
	var cx := Metrics.complexity(db(), { "fog": true, "facing": true })
	check(cx > 0.0 and float(Metrics.fun_score(m, t, cx)["score"]) < 1.0, "turning levers on costs complexity")
	check_near(Metrics.complexity(db(), { "fog": false }), 0.0, "levers that are off cost nothing")


# --- Part 4: search and shortlist ----------------------------------------------------

func test_search_improves_a_toy_problem() -> void:
	var space := [{ "lever": "a", "values": [1, 2, 3] }, { "lever": "b", "values": [true, false] }, { "lever": "c", "values": [1, 2, 3, 4] },
		{ "lever": "d", "values": [true, false] }, { "lever": "e", "values": ["x", "y"] }]
	var goal := { "a": 3, "b": true, "c": 2, "d": false, "e": "y" }
	var toy := func(lv: Dictionary) -> float:
		var s := 0.0
		for k in goal:
			s += 1.0 if lv.has(k) and str(lv[k]) == str(goal[k]) else 0.0
		return s / 5.0
	var state := Search.start(space, "toy", [{}])
	var rng := seeded(4)
	var first := -1.0
	for g in 20:
		var scored: Array = []
		for c in Search.propose(state, 6, rng):
			scored.append({ "levers": c, "score": toy.call(c), "dq": false })
		Search.absorb(state, scored)
		if g == 0:
			first = float(state["pop"][0]["score"])
	check(float(state["pop"][0]["score"]) > first, "the search finds better sets than its first generation (%.2f -> %.2f)" % [first, float(state["pop"][0]["score"])])
	check(float(state["pop"][0]["score"]) >= 0.8, "it gets close to the toy optimum")


func test_shortlist_differs() -> void:
	var sets: Array = []
	for i in 12:
		var lv := { "a": i % 3, "b": i % 2 == 0, "c": i % 4, "d": i, "e": i % 5 }
		sets.append({ "levers": lv, "score": 1.0 - float(i) * 0.01, "dq": false })
	var short := Search.shortlist(sets, 5, 3)
	check(short.size() >= 3, "a shortlist forms")
	for i in short.size():
		for j in range(i + 1, short.size()):
			check(Search.distance(short[i]["levers"], short[j]["levers"]) >= 3, "shortlisted sets are at least 3 levers apart")
	var dq := [{ "levers": { "a": 1 }, "score": 0.9, "dq": true }, { "levers": { "a": 2, "b": 1, "c": 1 }, "score": 0.2, "dq": false }]
	check(Search.shortlist(dq, 1, 1)[0]["score"] == 0.2, "a disqualified set never outranks an allowed one")


func test_tuned_presets_rewrite_only_generated() -> void:
	var text := FileAccess.get_file_as_string("res://data/lab/presets.json")
	var short := [{ "levers": { "fog": true, "enemyHpMul": 1.5 }, "score": 0.5 }, { "levers": { "facing": true }, "score": 0.4 }]
	var out := Tuned.write(text, Tuned.presets_for(db(), "cl_puzzle", short))
	var data: Variant = JSON.parse_string(out)
	check(typeof(data) == TYPE_DICTIONARY, "the presets file stays valid JSON")
	var ids: Array = data["presets"].map(func(p: Dictionary) -> String: return str(p["id"]))
	check(ids.has("current") and ids.has("cl_everything") and ids.has("tuned_1") and ids.has("tuned_2"), "hand-made presets stay, tuned ones join")
	var t1: Dictionary = data["presets"][ids.find("tuned_1")]
	check(bool(t1["generated"]) and bool(t1["levers"]["fog"]) and bool(t1["levers"]["instability"]) == false, "a tuned preset is its base plus its levers, marked generated")
	check(str(t1["text"]).contains("Fog on"), "a tuned preset says what makes it different")
	var again := Tuned.write(out, Tuned.presets_for(db(), "cl_puzzle", short.slice(0, 1)))
	var ids2: Array = (JSON.parse_string(again)["presets"] as Array).map(func(p: Dictionary) -> String: return str(p["id"]))
	check(ids2.has("tuned_1") and not ids2.has("tuned_2"), "writing again replaces the old tuned presets")
	check(out.contains(Tuned._entry(text, "cl_base")), "hand-made presets keep their own text")


func test_card_index_cache() -> void:
	var d := DT.tables("res://data")
	var idx := DT.index_under(d, "cards/", "cards")
	check(is_same(idx, DT.index_under(d, "cards/", "cards")), "the card index is built once per data set")
	check(idx.is_read_only(), "the cached index can't be changed by accident")
	d["cards/zz_test"] = { "cards": [{ "id": "zz_new_card" }] }
	check(DT.index_under(d, "cards/", "cards").has("zz_new_card"), "a new card table rebuilds the index")
	(d["cards/zz_test"]["cards"] as Array).append({ "id": "zz_second" })
	check(DT.index_under(d, "cards/", "cards").has("zz_second"), "a table that gains a record rebuilds the index")


func test_report_writes_a_section() -> void:
	var t: Dictionary = db()["lab/tuner"]
	var m := Metrics.summarize([_line("expert", "win"), _line("random", "lose")], t)
	var row := { "metrics": m, "score": Metrics.fun_score(m, t) }
	var sums := {
		"baseline": { "fights": 2, "at": "now", "groups": { "preset:cl_base": row, "preset:current": row } },
		"screening": { "fights": 4, "effects": [{ "base": "cl_base", "lever": "fog", "value": true, "delta": { "realChoices": 0.5, "noviceWin": -0.2 }, "score": 0.6, "base_score": 0.5, "verdict": "helps", "dq": false, "reasons": [] }] },
		"pairs": { "base": "cl_base", "top": [{}], "fights": 4, "pairs": [{ "levers": { "fog": true, "facing": true }, "score": 0.7, "aScore": 0.6, "bScore": 0.55, "verdict": "good together", "dq": false }] },
		"search": { "base": "cl_base", "tried": 10, "generations": 2, "finals": [{}], "space": [{ "lever": "fog" }], "shortlist": [{ "levers": { "fog": true }, "score": 0.6, "dq": false, "parties": { "balanced": row }, "fightWins": { "ledge_day": 0.9 } }] },
	}
	var cards := [{ "persona": "newcomer", "preset": "cl_base", "fight": "ledge_day", "fun": 4, "options": 3, "clever": true }]
	var sec := Report.section(db(), sums, cards, "2026-11-07")
	check(sec.begins_with("## Tuning run, 2026-11-07"), "a section is dated")
	for want in ["### Baseline", "| cl_base |", "### Lever effects", "Fog = true", "real choices per turn goes up by 0.5", "### Pairs", "good together", "**tuned_1**", "ledge_day 90%", "### Agent rating cards", "newcomer (persona)"]:
		check(sec.contains(want), "the section has %s" % want)
	var file := Report.append("", sec)
	check(file.begins_with("# Lab Tuning") and file.contains(sec), "a new report starts with its title")
	var twice := Report.append(file, sec.replace("2026-11-07", "2026-11-08"))
	check(twice.contains("2026-11-07") and twice.contains("2026-11-08"), "a second run adds a section and keeps the first")


# --- Part 5: lab_play ------------------------------------------------------------------

func test_lab_play_replays_the_same() -> void:
	var inputs := ["4", "1"]
	var a := Play.render(db(), Play.replay(db(), "thin_ice", "cl_puzzle", 4, inputs), "cl_puzzle")
	var b := Play.render(db(), Play.replay(db(), "thin_ice", "cl_puzzle", 4, inputs), "cl_puzzle")
	check(a == b and a.contains("Your options"), "replaying the same inputs prints the same screen")


func test_lab_play_options_are_the_legal_moves() -> void:
	var r := Play.replay(db(), "ledge_day", "cl_puzzle", 2, [])
	var st: Object = r["st"]
	var opts := Play.options(st)
	check(opts.size() > 2 and str(opts[-1]["step"]["kind"]) == "end", "options end with ending the turn")
	var snap := Sim.save(st)
	var u: Object = st.current
	var bad := 0
	for o in opts:
		Sim.restore(st, snap)
		if not Legal.apply(st, u, o["step"]):
			bad += 1
	Sim.restore(st, snap)
	check(bad == 0, "every numbered option can be played (%d refused)" % bad)
	var legal := Legal.steps(st, u).size()
	check(opts.size() <= legal, "options come from the legal steps")


func test_lab_play_previews_match() -> void:
	var fights := [["ledge_day", 2], ["crowded_hall", 1], ["fire_sale", 3]]
	var compared := 0
	var mismatched: Array = []
	for fs in fights:
		var inputs: Array = []
		for step in 6:
			var r := Play.replay(db(), str(fs[0]), "cl_puzzle", int(fs[1]), inputs)
			var st: Object = r["st"]
			if st.result != "":
				break
			var opts := Play.options(st)
			var pick := -1
			for i in opts.size():
				var k := str(opts[i]["step"]["kind"])
				if k in ["card", "strike"] and str(opts[i]["preview"]).contains("HP"):
					pick = i
					break
			if pick < 0:
				pick = 0 if opts.size() > 1 else opts.size() - 1
			var before := Play._picture(st)
			var who: Object = st.current
			var r2 := Play.replay(db(), str(fs[0]), "cl_puzzle", int(fs[1]), inputs + [str(pick + 1)])
			var st2: Object = r2["st"]
			var kind := str(opts[pick]["step"]["kind"])
			if st2.current == st2.unit_by_id(who.id) and kind != "end" and st2.result == "":
				var after := Play._diff(st2, st2.current, _repoint(before, st, st2), Play._picture(st2), kind in ["move", "climb"])
				compared += 1
				if "; ".join(PackedStringArray(after)) != str(opts[pick]["preview"]):
					mismatched.append("%s: '%s' vs '%s'" % [opts[pick]["label"], opts[pick]["preview"], "; ".join(PackedStringArray(after))])
			inputs.append(str(pick + 1))
	check(compared >= 5, "previews were compared (%d)" % compared)
	check(mismatched.is_empty(), "the printed preview is what happens: %s" % str(mismatched))


## A picture taken in one replay, keyed by the same units in another replay.
func _repoint(pic: Dictionary, from: Object, to: Object) -> Dictionary:
	var units := {}
	for x in pic["units"]:
		var y: Object = to.unit_by_id(x.id)
		if y != null:
			units[y] = pic["units"][x]
	return { "units": units, "tiles": pic["tiles"], "surge": pic["surge"] }


func test_lab_play_refuses_politely() -> void:
	var tool: GDScript = load("res://tools/lab_play.gd")
	var odd: String = tool.run(db(), "ledge_day", "cl_base", 1, [], "dance")
	check(odd.begins_with("Sorry, I don't know the command"), "an unknown command gets a polite answer")
	var far: String = tool.run(db(), "ledge_day", "cl_base", 1, ["999"], "")
	check(far.begins_with("Sorry") and far.contains("no option 999"), "an option that doesn't exist gets a polite answer")
	var nofight: String = tool.run(db(), "nowhere", "cl_base", 1, [], "")
	check(nofight.contains("no fight called"), "an unknown fight gets a polite answer")
	check(str(tool.run(db(), "ledge_day", "cl_plus", 1, [], "explain fog")).contains("Fog"), "explain prints a lever's text")
	check(str(tool.run(db(), "ledge_day", "cl_plus", 1, [], "rules")).contains("Choose your order"), "the rules list the preset's extras")
	check(str(tool.run(db(), "ledge_day", "cl_base", 1, [], "show discard")).contains("discard"), "show discard works")
	var undo: Dictionary = Play.replay(db(), "ledge_day", "cl_base", 1, ["u"])
	check(str(undo["notes"]).contains("Undo"), "undo with nothing to undo says why")



func test_lab_play_named_steps() -> void:
	var r := Play.replay(db(), "ledge_day", "cl_puzzle", 2, [])
	var st: Object = r["st"]
	var opts := Play.options(st)
	var move_i := -1
	for i in opts.size():
		if str(opts[i]["step"]["kind"]) == "move":
			move_i = i
			break
	var c: Vector2i = opts[move_i]["step"]["cell"]
	var by_num := Play.render(db(), Play.replay(db(), "ledge_day", "cl_puzzle", 2, [str(move_i + 1)]), "cl_puzzle")
	var by_name := Play.render(db(), Play.replay(db(), "ledge_day", "cl_puzzle", 2, ["m%d.%d" % [c.x, c.y]]), "cl_puzzle")
	check(by_num == by_name, "a named move does what its number does")
	check(Play.find_named(st, opts, "e") == opts.size(), "e ends the turn")
	var bad := Play.replay(db(), "ledge_day", "cl_puzzle", 2, ["m99.99"])
	check(str(bad["error"]).contains("can't move there"), "a named step that isn't possible says so")
	check(Play.render(db(), Play.replay(db(), "ledge_day", "cl_puzzle", 2, []), "cl_puzzle", true).contains("Moves (number:step"), "brief mode lists moves on one line")


# --- Part 6: the shortlist A/B series ---------------------------------------------------

func test_ab_series_follows_the_winner() -> void:
	var S: GDScript = load("res://src/core/lab/lab_session.gd")
	var steps := [{ "fight": "thin_ice", "a": "tuned_1", "b": "tuned_2" }, { "fight": "hollow_mascot", "a": "winner", "b": "tuned_3" }]
	check(S.start_series(steps), "a series starts")
	check(S.fight_id == "thin_ice" and S.ab_preset() == "tuned_1", "it starts with the first pair on its fight")
	var next: Dictionary = S.next_in_series("tuned_2")
	check(str(next.get("a", "")) == "tuned_2" and str(next.get("b", "")) == "tuned_3" and S.fight_id == "hollow_mascot", "the winner meets the next preset on the next fight")
	check(S.next_in_series("tuned_3").is_empty(), "the series ends after the last pair")
	S.start_series(steps)
	check(str(S.next_in_series("").get("a", "")) == "tuned_1", "a tie keeps the first preset")
	S.reset_ab()
	var plan: Dictionary = db()["lab/lab"].get("abShortlist", {})
	if not plan.is_empty():
		for st in plan.get("steps", []):
			for k in ["a", "b"]:
				check(str(st[k]) == "winner" or not Rules.preset_rec(db(), str(st[k])).is_empty(), "the shortlist series names real presets (%s)" % st[k])


func test_lab_report_shows_human_agent_machine() -> void:
	const LR := preload("res://src/core/lab/lab_report.gd")
	var human := LR.summarize([{ "kind": "fight", "preset": "tuned_1", "result": "win", "rounds": 4, "rating": { "fun": 5 } }])
	var text := LR.combined(human, [{ "preset": "tuned_1", "fun": 3 }, { "preset": "cl_base", "fun": 2 }], { "tuned_1": { "score": 0.61, "dq": false }, "cl_base": { "score": 0.4, "dq": true } })
	check(text.contains("you:fun") and text.contains("agent:fun") and text.contains("machine"), "the table has your, the agents' and the machine's columns")
	check(text.contains("5.0") and text.contains("3.0") and text.contains("0.61") and text.contains("0.40!"), "each column shows its number")


func test_difficulty_ladder() -> void:
	var finals := [{ "levers": { "keywordsOn": false, "surge": false, "enemyDamageMul": 4 }, "score": 0.5 },
		{ "levers": { "keywordsOn": false, "surge": false, "enemyHpMul": 3 }, "score": 0.6 },
		{ "levers": { "facing": true, "fog": true, "enemyHpMul": 2 }, "score": 0.4 }]
	var plan := { "difficultyLevers": ["enemyDamageMul", "enemyHpMul"], "fromFinals": 2, "minRuleDistance": 2, "extraRuleSets": [{}] }
	var rules := Search.ladder_rules(finals, plan)
	check(rules.size() == 3 and not rules[0].has("enemyHpMul"), "the finalists' rules lose their difficulty levers")
	check(bool(rules[1].get("facing", false)) and rules[2].is_empty(), "near-copies are dropped and the plan's extra sets join")
	var sets := Search.ladder_sets(rules, [{ "enemyHpMul": 1.5 }, { "enemyHpMul": 2 }])
	check(sets.size() == 6 and int(sets[1]["enemyHpMul"]) == 2 and not bool(sets[0]["surge"]), "every rule set meets every level")


func test_scaled_difficulty_pick() -> void:
	var line := func(f: String, who: String, res: String) -> Dictionary: return { "fight": f, "profile": who, "result": res }
	var st := Search.scale_stats([line.call("a", "expert", "win"), line.call("a", "expert", "loss"), line.call("a", "random", "stall")])
	check(is_equal_approx(float(st["a"]["expert"]), 0.5) and int(st["a"]["stalls"]) == 1 and int(st["a"]["n"]) == 3, "a scan's lines become win shares and stalls per fight")
	var row := func(e: float, r: float, s: int = 0) -> Dictionary: return { "expert": e, "random": r, "stalls": s, "n": 12 }
	var rungs := [{ "enemyHpMul": 1 }, { "enemyHpMul": 2 }, { "enemyHpMul": 3 }]
	var by := [{ "easy": row.call(1.0, 0.9), "hard": row.call(0.6, 0.0), "stally": row.call(1.0, 0.5, 2) },
		{ "easy": row.call(1.0, 0.1), "hard": row.call(0.3, 0.0), "stally": row.call(0.9, 0.1) },
		{ "easy": row.call(0.85, 0.0), "hard": row.call(0.1, 0.0), "stally": row.call(0.7, 0.0) }]
	var p := Search.scale_pick(by, rungs, { "minExpert": 0.8, "maxRandom": 0.15 })
	check(int(p["easy"]["rung"]) == 2 and bool(p["easy"]["fit"]), "the hardest step the expert still wins is picked")
	check(int(p["stally"]["rung"]) == 1, "a step with stalls is passed over")
	check(int(p["hard"]["rung"]) == 0 and not bool(p["hard"]["fit"]), "with no fitting step the expert's best one is used and flagged")
	var forced := Search.scale_pick(by, rungs, { "minExpert": 0.8, "maxRandom": 0.15, "force": { "easy": 0 } })
	check(int(forced["easy"]["rung"]) == 0 and int(forced["stally"]["rung"]) == 1, "the plan can set a fight's step by hand")


func test_scaled_difficulty_applies_per_fight() -> void:
	var d := db().duplicate()
	d["lab/fight_scales"] = { "scales": { "cl_base": { "ledge_day": { "enemyHpMul": 3.0 } } } }
	var on := Setup.build(d, "ledge_day", "cl_base", { "fightScaled": true })
	check(is_equal_approx(on["rules"].num("enemyHpMul"), 3.0), "a scaled preset uses its step for the fight")
	var other := Setup.build(d, "fire_sale", "cl_base", { "fightScaled": true })
	check(is_equal_approx(other["rules"].num("enemyHpMul", 1.0), 1.0), "a fight with no step is unchanged")
	var hand := Setup.build(d, "ledge_day", "cl_base", { "fightScaled": true, "enemyHpMul": 2.0 })
	check(is_equal_approx(hand["rules"].num("enemyHpMul"), 2.0), "a change made by hand still wins")
	var off := Setup.build(d, "ledge_day", "cl_base")
	check(is_equal_approx(off["rules"].num("enemyHpMul", 1.0), 1.0), "off by default")


func test_failed_presets_are_marked() -> void:
	var rec: Array = Tuned.presets_for(db(), "cl_base", [{ "levers": { "surge": false }, "score": 0.5, "dq": true, "reasons": ["stalls"] }, { "levers": { "fog": true }, "score": 0.4, "dq": false }])
	check(not bool(rec[0].get("passed", true)) and str(rec[0]["text"]).begins_with("Did not pass") and rec[0]["failed"].has("stalls"), "a preset that failed the limits says so")
	check(not rec[1].has("failed"), "a passing preset is not marked")


func test_text_explains_what_happened() -> void:
	var lines: Array = Play._log_lines([{ "t": "damage", "unit": "x", "amount": 9, "cause": "pit" }, { "t": "down", "unit": "x" }, { "t": "log", "text": "Hello" }])
	check(lines[0] == "Someone takes 9 damage (pit)" and lines[1] == "Someone goes down" and lines[2] == "Hello", "damage and knockdowns reach the log")
	var st := _fired_state({ "keywordsOn": false })
	var shown: Dictionary = st.card_as_shown({ "name": "A", "swift": true, "quick": true })
	check(not shown.has("swift") and shown.has("quick"), "switched-off keywords leave the text")


func _fired_state(levers: Dictionary) -> Object:
	var built := Setup.build(db(), "ledge_day", "cl_base", levers)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	return (load("res://src/core/combat/combat_state.gd") as GDScript).new(db(), rng, built["setup"])


func test_fired_up() -> void:
	var st := _fired_state({ "firedUp": true, "firedUpShare": 0.5, "firedUpCap": 4 })
	var hero: Object = st.units.filter(func(u: Object) -> bool: return u.team == "party")[0]
	var foe: Object = st.units.filter(func(u: Object) -> bool: return u.team == "enemy")[0]
	check(st.fired_up_bonus(1) == 1 and st.fired_up_bonus(4) == 2 and st.fired_up_bonus(99) == 4, "the bonus is a share of the hit, at least 1, up to the cap")
	foe.max_hp = 50
	foe.hp = 50
	hero.max_hp = 50
	hero.hp = 50
	st._damage(hero, 4, foe, "", "direct")
	check(not hero.links.has("fired_up"), "only an enemy hit fires a hero up")
	st._gain_fired_up(hero, 4)
	check(hero.links.has("fired_up"), "a hit taken fires the hero up")
	var hp: int = foe.hp
	st._damage(foe, 2, hero, "", "reflect")
	check(foe.hp == hp - 2 and hero.links.has("fired_up"), "only attacks use the bonus")
	st._damage(foe, 2, hero, "", "hit")
	check(foe.hp < hp - 2 - st.rules.scaled(2.0) + 1 and not hero.links.has("fired_up"), "the next attack hits harder and spends it")
	var off := _fired_state({})
	var h2: Object = off.units.filter(func(u: Object) -> bool: return u.team == "party")[0]
	off._gain_fired_up(h2, 4)
	check(not h2.links.has("fired_up"), "off by default")


func test_enemy_actions_lever_plays() -> void:
	var cell := { "group": "x", "fight": "ledge_day", "preset": "cl_base", "levers": { "enemyActions": 2 }, "seed": 1, "profile": "random", "party": "balanced" }
	var line: Dictionary = Sweep.run_fight(db(), cell)
	check(["win", "lose", "stall"].has(str(line["result"])), "a fight with two enemy actions plays to the end")


func test_blind_panel_text() -> void:
	var d := db()
	var rec: Dictionary = Rules.preset_rec(d, "ref_unfair")
	var text := "RULES FOR PRESET ref_unfair\n%s\n%s" % [str(rec["text"]), str(rec["name"])]
	var out := Play.blind(d, text, "ref_unfair", "Dogwood")
	check(not out.contains("ref_unfair") and not out.contains(str(rec["text"])) and not out.contains(str(rec["name"])) and out.contains("Dogwood"), "a blind panel hides which preset this is")
	var q: Dictionary = d["lab/panels/quick"]
	check((q["aliases"] as Dictionary).size() == 4 and (q["personas"] as Array).size() * 4 * (q["fights"] as Array).size() == int(q["budget"]["fights"]), "the quick panel fits its fight budget")


## Lab Tuner sweeps (docs/LAB_TUNER.md Parts 1 and 4): plays a plan's fights
## headless with the AI players and writes one JSON line per fight to
## user://lab/sweeps/<plan>/<run>.jsonl, then a summary next to it.
## Run: godot --headless --path . -s res://tools/lab_sweep.gd -- --plan=res://data/lab/sweeps/baseline.json
## Options: --jobs=N (parallel processes; default the plan's, else the CPU count),
## --fresh (start a new run instead of resuming the unfinished one),
## --budget=minutes (overrides the plan's time budget), --generations=N (a search's
## generation cap, e.g. to resume a stopped search straight into its final check).
## A stopped run resumes where it left off: run the same command again.
## Plan kinds: grid (named presets), screen (one lever at a time), pairs (the top
## levers from a screening run, two at a time), search (an evolutionary search,
## then a robustness check and the tuned_1..5 shortlist in data/lab/presets.json).
extends SceneTree

const DT := preload("res://src/core/data_tables.gd")
const Sweep := preload("res://src/core/lab/sweep.gd")
const Plan := preload("res://src/core/lab/tuner/plan.gd")
const Metrics := preload("res://src/core/lab/tuner/metrics.gd")
const Search := preload("res://src/core/lab/tuner/search.gd")
const Tuned := preload("res://src/core/lab/tuner/tuned_presets.gd")
const Rules := preload("res://src/core/combat/rules.gd")

var db: Dictionary = {}
var args := {}
var deadline := 0.0
var jobs := 1


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a).trim_prefix("--")
		var eq := s.find("=")
		args[s.substr(0, eq) if eq >= 0 else s] = s.substr(eq + 1) if eq >= 0 else "1"
	db = DT.tables("res://data")
	if args.has("worker"):
		_worker()
		quit(0)
		return
	var path := str(args.get("plan", ""))
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	if typeof(plan) != TYPE_DICTIONARY:
		printerr("lab_sweep: pass --plan=res://data/lab/sweeps/<plan>.json")
		quit(1)
		return
	jobs = int(args.get("jobs", plan.get("jobs", OS.get_processor_count())))
	var budget := float(args.get("budget", plan.get("budgetMinutes", 120)))
	deadline = Time.get_unix_time_from_system() + budget * 60.0
	var dir := run_dir(str(plan["id"]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var run := _run_id(dir)
	print("lab_sweep: plan %s (%s), run %s, %d jobs, budget %.0f min" % [plan["id"], plan.get("kind", "grid"), run, jobs, budget])
	var t0 := Time.get_ticks_msec()
	var summary := {}
	match str(plan.get("kind", "grid")):
		"grid":
			summary = _grid(plan, dir, run, Plan.grid_cells(db, plan))
		"screen":
			summary = _screen(plan, dir, run)
		"pairs":
			summary = _pairs(plan, dir, run)
		"search":
			summary = _search(plan, dir, run)
		"ladder":
			summary = _ladder(plan, dir, run)
		"scaled":
			summary = _scaled(plan, dir, run)
	summary["plan"] = plan["id"]
	summary["kind"] = plan.get("kind", "grid")
	summary["run"] = run
	summary["at"] = Time.get_datetime_string_from_system()
	summary["minutes"] = snappedf(float(Time.get_ticks_msec() - t0) / 60000.0, 0.1)
	summary["jobs"] = jobs
	var f := FileAccess.open(dir + run + ".summary.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, "  "))
	f.close()
	if bool(summary.get("complete", true)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "current.txt"))
		print("lab_sweep: done in %.1f min. Summary: %s" % [summary["minutes"], ProjectSettings.globalize_path(dir + run + ".summary.json")])
	else:
		print("lab_sweep: stopped by the time budget. Run the same command again to resume.")
	quit(0)


static func run_dir(plan_id: String) -> String:
	return Plan.run_dir(plan_id)


## The unfinished run to resume, or a new one.
func _run_id(dir: String) -> String:
	var cur := dir + "current.txt"
	if not args.has("fresh") and FileAccess.file_exists(cur):
		var id := FileAccess.get_file_as_string(cur).strip_edges()
		if id != "":
			return id
	var id := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var f := FileAccess.open(cur, FileAccess.WRITE)
	f.store_string(id)
	f.close()
	return id


# --- Running cells --------------------------------------------------------------

## Play every cell not yet in the run file, in parallel. Returns the lines for these cells.
func run_cells(dir: String, run: String, cells: Array, label: String = "") -> Array:
	var out_path := dir + run + ".jsonl"
	var have := Plan.read_lines(out_path)
	var todo := Plan.pending(cells, Plan.done_keys(have))
	if not todo.is_empty() and Time.get_unix_time_from_system() < deadline:
		print("  %s%d fights to play (%d already done)" % ["" if label == "" else label + ": ", todo.size(), cells.size() - todo.size()])
		var n := mini(jobs, maxi(1, todo.size() / 4))
		var cells_path := dir + run + ".cells.json"
		var cf := FileAccess.open(cells_path, FileAccess.WRITE)
		cf.store_string(JSON.stringify(todo))
		cf.close()
		var t0 := Time.get_ticks_msec()
		if n <= 1:
			_play(todo, dir + run + ".part0.jsonl")
		else:
			var pids: Array = []
			for i in n:
				pids.append(OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/lab_sweep.gd", "--",
					"--worker=%d" % i, "--jobs=%d" % n, "--cells=" + cells_path, "--out=" + dir + run + ".part%d.jsonl" % i, "--deadline=%d" % int(deadline)]))
			var last := 0
			while pids.any(func(p: int) -> bool: return OS.is_process_running(p)):
				OS.delay_msec(1000)
				var done := 0
				for i in n:
					done += _count_lines(dir + run + ".part%d.jsonl" % i)
				if done - last >= maxi(20, todo.size() / 10):
					last = done
					var secs := float(Time.get_ticks_msec() - t0) / 1000.0
					print("    %d / %d (%.1f fights/s)" % [done, todo.size(), float(done) / maxf(0.1, secs)])
		var parts: Array = [have]
		for i in maxi(1, n):
			var p := dir + run + ".part%d.jsonl" % i
			parts.append(Plan.read_lines(p))
		var merged := Plan.merge(parts)
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		for rec in merged:
			f.store_line(JSON.stringify(rec))
		f.close()
		for i in maxi(1, n):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + run + ".part%d.jsonl" % i))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cells_path))
		var played := merged.size() - have.size()
		print("    played %d in %.0f s (%.1f fights/s)" % [played, float(Time.get_ticks_msec() - t0) / 1000.0, float(played) / maxf(0.1, float(Time.get_ticks_msec() - t0) / 1000.0)])
		have = merged
	var want := {}
	for c in cells:
		want[Sweep.cell_key(c)] = true
	return have.filter(func(r: Dictionary) -> bool: return want.has(str(r.get("key", ""))))


func _count_lines(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_file_as_string(path).count("\n")


func _play(cells: Array, out_path: String) -> void:
	var done := Plan.done_keys(Plan.read_lines(out_path))
	for c in cells:
		if Time.get_unix_time_from_system() >= deadline:
			return
		if done.has(Sweep.cell_key(c)):
			continue
		Plan.append_line(out_path, Sweep.run_fight(db, c))


func _worker() -> void:
	deadline = float(args.get("deadline", Time.get_unix_time_from_system() + 3600.0))
	var cells: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args["cells"])))
	if typeof(cells) != TYPE_ARRAY:
		return
	for c in cells:
		_fix_types(c)
	_play(Plan.share(cells, int(args["worker"]), int(args["jobs"])), str(args["out"]))


## JSON brings numbers back as floats: seeds are ints.
static func _fix_types(c: Dictionary) -> void:
	c["seed"] = int(c.get("seed", 1))


# --- Metrics --------------------------------------------------------------------

func _score_groups(lines: Array, levers_of: Dictionary) -> Dictionary:
	var t := Metrics.cfg(db)
	var out := {}
	var groups := Plan.by_group(lines)
	for g in groups:
		var m := Metrics.summarize(groups[g], t)
		var lv: Dictionary = levers_of.get(g, {})
		var cx := Metrics.complexity(db, lv)
		out[g] = { "metrics": m, "score": Metrics.fun_score(m, t, cx) }
	return out


func _complete(cells: Array, lines: Array) -> bool:
	return lines.size() >= cells.size()


func _grid(plan: Dictionary, dir: String, run: String, cells: Array) -> Dictionary:
	var lines := run_cells(dir, run, cells)
	var levers_of := {}
	for p in plan.get("presets", []):
		var lv := Rules.values_for(db, str(p))
		lv.merge(plan.get("levers", {}), true)
		levers_of["preset:" + str(p)] = lv
	return { "groups": _score_groups(lines, levers_of), "complete": _complete(cells, lines), "fights": lines.size() }


func _screen(plan: Dictionary, dir: String, run: String) -> Dictionary:
	var cells := Plan.screen_cells(db, plan)
	var lines := run_cells(dir, run, cells)
	var variants := Plan.screen_variants(db, plan)
	var levers_of := {}
	for v in variants:
		var lv := Rules.values_for(db, str(v["base"]))
		lv.merge(v["levers"], true)
		levers_of[str(v["group"])] = lv
	var groups := _score_groups(lines, levers_of)
	var metrics_by := {}
	var scores := {}
	for g in groups:
		metrics_by[g] = groups[g]["metrics"]
		scores[g] = groups[g]["score"]
	# Each lever against its base on the same fights: the base's row for a variant
	# is its lines on that variant's fights only.
	var by_group := Plan.by_group(lines)
	var t := Metrics.cfg(db)
	for v in variants:
		if str(v["lever"]) == "":
			continue
		var fights := Plan.variant_fights(db, plan, v)
		var bg := "screen:%s" % v["base"]
		var mine: Array = by_group.get(bg, []).filter(func(r: Dictionary) -> bool: return fights.has(str(r.get("fight", ""))))
		var key := "%s@%s" % [bg, ",".join(PackedStringArray(fights))]
		if not metrics_by.has(key):
			var m := Metrics.summarize(mine, t)
			metrics_by[key] = m
			scores[key] = Metrics.fun_score(m, t, Metrics.complexity(db, levers_of.get(bg, {})))
		v["baseGroup"] = key
	return { "groups": groups, "effects": Search.effects(variants, metrics_by, scores, t), "complete": _complete(cells, lines), "fights": lines.size() }


## The latest finished summary of another plan.
func latest_summary(plan_id: String) -> Dictionary:
	return Plan.latest_summary(plan_id)


## The base the screening liked better (or the plan's).
func _pick_base(plan: Dictionary, screen: Dictionary) -> String:
	var want := str(plan.get("base", "auto"))
	if want != "auto":
		return want
	var best := ""
	var best_score := -INF
	for g in screen.get("groups", {}):
		if str(g).begins_with("screen:") and not str(g).contains("|"):
			var sc: Dictionary = screen["groups"][g]["score"]
			var v := float(sc["score"]) - (10.0 if bool(sc["dq"]) else 0.0)
			if v > best_score:
				best_score = v
				best = str(g).trim_prefix("screen:")
	return best if best != "" else "cl_base"


func _pairs(plan: Dictionary, dir: String, run: String) -> Dictionary:
	var screen := latest_summary(str(plan.get("from", "screening")))
	if screen.is_empty():
		printerr("lab_sweep: run the screening plan first")
		return { "complete": false }
	var base := _pick_base(plan, screen)
	var top := Search.top_levers(screen.get("effects", []), int(plan.get("top", 12)), base)
	var sets := Search.pair_sets(top, base)
	var cells := Plan.set_cells(db, sets, plan)
	var lines := run_cells(dir, run, cells)
	var levers_of := {}
	for s in sets:
		var lv := Rules.values_for(db, base)
		lv.merge(s["levers"], true)
		levers_of[str(s["group"])] = lv
	var groups := _score_groups(lines, levers_of)
	var single := {}
	for r in screen.get("effects", []):
		if str(r["base"]) == base:
			single["%s=%s" % [r["lever"], str(r["value"])]] = float(r["score"])
	var base_score := float(screen["groups"].get("screen:" + base, {}).get("score", {}).get("score", 0.0))
	var rows: Array = []
	var eps := float(Metrics.cfg(db).get("effectEpsilon", 0.02))
	for s in sets:
		if not groups.has(s["group"]):
			continue
		var a_score := float(single.get("%s=%s" % [s["a"], str(s["levers"][s["a"]])], base_score))
		var b_score := float(single.get("%s=%s" % [s["b"], str(s["levers"][s["b"]])], base_score))
		var ps := float(groups[s["group"]]["score"]["score"])
		rows.append({ "a": s["a"], "b": s["b"], "levers": s["levers"], "score": ps, "aScore": a_score, "bScore": b_score,
			"verdict": Search.pair_verdict(ps, a_score, b_score, eps), "dq": groups[s["group"]]["score"]["dq"] })
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["score"]) > float(y["score"]))
	return { "base": base, "top": top, "pairs": rows, "groups": groups, "complete": _complete(cells, lines), "fights": lines.size() }


func _search(plan: Dictionary, dir: String, run: String) -> Dictionary:
	var screen := latest_summary(str(plan.get("from", "screening")))
	if screen.is_empty():
		printerr("lab_sweep: run the screening plan first")
		return { "complete": false }
	var base := _pick_base(plan, screen)
	var base_values := Rules.values_for(db, base)
	var top := Search.top_levers(screen.get("effects", []), int(plan.get("top", 15)), base)
	var space: Array = []
	var in_space := {}
	for r in top:
		var spec := Plan.lever_spec(db, str(r["lever"]))
		var vals: Array = Plan.screen_values(db, plan, spec, base_values.get(str(r["lever"])))
		if not vals.is_empty():
			space.append({ "lever": str(r["lever"]), "values": vals })
			in_space[str(r["lever"])] = true
	for extra in plan.get("alwaysLevers", []):
		if not in_space.has(str(extra["lever"])):
			space.append(extra)
	var seeds: Array = [{}]
	var pairs := latest_summary(str(plan.get("pairsFrom", "pairs")))
	for p in pairs.get("pairs", []).slice(0, int(plan.get("seedPairs", 4))):
		if not bool(p["dq"]):
			seeds.append(p["levers"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plan.get("seed", 1))
	var state := Search.start(space, base, seeds)
	var scored_all: Array = []
	var search_cfg: Dictionary = plan.get("searchCells", {})
	var gens := int(args.get("generations", plan.get("generations", 30)))
	var per_gen := int(plan.get("population", 12))
	var gen_times: Array = []
	var complete := true
	while int(state["gen"]) < gens:
		var left := deadline - Time.get_unix_time_from_system()
		var final_need := float(plan.get("finalMinutes", 40)) * 60.0
		var avg := 0.0
		for g in gen_times:
			avg += float(g)
		avg = avg / float(gen_times.size()) if not gen_times.is_empty() else 0.0
		if left < final_need + avg:
			break
		var g0 := Time.get_ticks_msec()
		var cands := Search.propose(state, per_gen, rng)
		var sets: Array = []
		for c in cands:
			sets.append({ "group": "cand:" + Search.set_key(c), "base": base, "levers": c })
		var cells := Plan.set_cells(db, sets, search_cfg)
		var lines := run_cells(dir, run, cells, "generation %d" % (int(state["gen"]) + 1))
		var scored := _score_sets(sets, lines, base_values)
		Search.absorb(state, scored, int(plan.get("keep", 24)))
		scored_all.append_array(scored)
		gen_times.append(float(Time.get_ticks_msec() - g0) / 1000.0)
		var best: Dictionary = state["pop"][0]
		print("  generation %d: best %.3f%s %s" % [state["gen"], float(best["score"]), " (disqualified)" if bool(best["dq"]) else "", Search.set_key(best["levers"])])
	# Robustness: the best few, distinct by at least one lever, on every fight and party.
	var finals := Search.shortlist(state["pop"], int(plan.get("finalCount", 8)), 1, base_values)
	var final_cfg: Dictionary = plan.get("finalCells", {})
	var final_rows: Array = []
	for fset in finals:
		var parties: Array = final_cfg.get("parties", ["balanced"])
		var per_party := {}
		var all_lines: Array = []
		for party in parties:
			var pc := final_cfg.duplicate()
			pc["parties"] = [party]
			var cells := Plan.set_cells(db, [{ "group": "final:%s|%s" % [Search.set_key(fset["levers"]), party], "base": base, "levers": fset["levers"] }], pc)
			var lines := run_cells(dir, run, cells, "final %s" % party)
			complete = complete and lines.size() >= cells.size()
			all_lines.append_array(lines)
			var lv := base_values.duplicate()
			lv.merge(fset["levers"], true)
			var m := Metrics.summarize(lines, Metrics.cfg(db))
			per_party[party] = { "metrics": m, "score": Metrics.fun_score(m, Metrics.cfg(db), Metrics.complexity(db, lv)) }
		final_rows.append(_robust(fset, per_party, all_lines))
	var short := Search.shortlist(final_rows, int(plan.get("shortlist", 5)), int(plan.get("minDistance", 3)), base_values)
	# Only sets that passed the full check can be shortlisted.
	short = Search.shortlist(final_rows.filter(func(r: Dictionary) -> bool: return not bool(r["dq"])), int(plan.get("shortlist", 5)), int(plan.get("minDistance", 3)), base_values)
	if complete and not bool(plan.get("dryRun", false)):
		_write_tuned(base, short)
	return { "base": base, "space": space, "generations": state["gen"], "population": state["pop"], "tried": scored_all.size(), "finals": final_rows,
		"shortlist": short, "complete": complete, "genSeconds": gen_times }


## Replace the generated presets with this shortlist (none if nothing passed).
func _write_tuned(base: String, short: Array) -> void:
	var path := ProjectSettings.globalize_path("res://data/lab/presets.json")
	var text := Tuned.write(FileAccess.get_file_as_string(path), Tuned.presets_for(db, base, short))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("  wrote %d tuned presets to data/lab/presets.json" % short.size())


## After a search whose finalists failed the full check: the same rules at milder
## difficulty levels, on every fight and party. Only sets that pass are shortlisted.
func _ladder(plan: Dictionary, dir: String, run: String) -> Dictionary:
	var source := latest_summary(str(plan.get("from", "search")))
	if source.is_empty():
		printerr("lab_sweep: run the search plan first")
		return { "complete": false }
	var base := str(source.get("base", "cl_puzzle"))
	var base_values := Rules.values_for(db, base)
	var rules := Search.ladder_rules(source.get("finals", []), plan, base_values)
	var sets := Search.ladder_sets(rules, plan.get("levels", []))
	print("  %d rule sets x %d difficulty levels" % [rules.size(), plan.get("levels", []).size()])
	var cfg: Dictionary = plan.get("cells", {})
	var rows: Array = []
	var complete := true
	for lv in sets:
		var per_party := {}
		var all_lines: Array = []
		for party in cfg.get("parties", ["balanced"]):
			var pc := cfg.duplicate()
			pc["parties"] = [party]
			var cells := Plan.set_cells(db, [{ "group": "ladder:%s|%s" % [Search.set_key(lv), party], "base": base, "levers": lv }], pc)
			var lines := run_cells(dir, run, cells, str(party))
			complete = complete and lines.size() >= cells.size()
			all_lines.append_array(lines)
			var full := base_values.duplicate()
			full.merge(lv, true)
			var m := Metrics.summarize(lines, Metrics.cfg(db))
			per_party[party] = { "metrics": m, "score": Metrics.fun_score(m, Metrics.cfg(db), Metrics.complexity(db, full)) }
		var row := _robust({ "levers": lv }, per_party, all_lines)
		rows.append(row)
		print("  %.3f%s %s" % [float(row["score"]), " (fails: %s)" % str(row["reasons"]).left(120) if bool(row["dq"]) else " PASSES", Search.set_key(lv)])
	var short := Search.shortlist(rows.filter(func(r: Dictionary) -> bool: return not bool(r["dq"])), int(plan.get("shortlist", 5)), int(plan.get("minDistance", 3)), base_values)
	if complete:
		_write_tuned(base, short)
	return { "base": base, "rules": rules, "finals": rows, "shortlist": short, "space": [], "tried": rows.size(), "generations": 0, "complete": complete }


## Scaled difficulty: scan every fight at every difficulty step, pick one step per
## fight, then check those picks on new seeds with every profile and party. The picks
## are saved (and presets written) only for sets that pass the full check.
func _scaled(plan: Dictionary, dir: String, run: String) -> Dictionary:
	var source := latest_summary(str(plan.get("from", "search")))
	if source.is_empty():
		printerr("lab_sweep: run the search plan first")
		return { "complete": false }
	var base := str(source.get("base", "cl_puzzle"))
	var base_values := Rules.values_for(db, base)
	var rules := Search.ladder_rules(source.get("finals", []), plan, base_values)
	var rungs: Array = plan.get("rungs", [])
	var check: Dictionary = plan.get("check", {})
	var rows: Array = []
	var complete := true
	for rule in rules:
		var key := Search.set_key(rule)
		var by_rung: Array = []
		for i in rungs.size():
			var lv: Dictionary = (rule as Dictionary).duplicate()
			lv.merge(rungs[i], true)
			var cells := Plan.set_cells(db, [{ "group": "scan:%s|%d" % [key, i], "base": base, "levers": lv }], plan.get("scan", {}))
			var lines := run_cells(dir, run, cells, "step %d" % i)
			complete = complete and lines.size() >= cells.size()
			by_rung.append(Search.scale_stats(lines))
		var picks := Search.scale_pick(by_rung, rungs, plan.get("pick", {}))
		var names: Array = picks.keys()
		names.sort()
		for f in names:
			print("  %s: step %d, expert %d%%, random %d%%%s" % [f, int(picks[f]["rung"]), roundi(float(picks[f]["expert"]) * 100.0), roundi(float(picks[f]["random"]) * 100.0), "" if bool(picks[f]["fit"]) else " (no step fits)"])
		var per_party := {}
		var all_lines: Array = []
		var full := base_values.duplicate()
		full.merge(rule, true)
		for party in check.get("parties", ["balanced"]):
			var pc := check.duplicate()
			pc["parties"] = [party]
			var cells: Array = []
			for f in names:
				var lv: Dictionary = (rule as Dictionary).duplicate()
				lv.merge(picks[f]["levers"], true)
				cells.append_array(Plan.cells_for(db, "check:%s|%s" % [key, party], base, lv, pc, [f]))
			var lines := run_cells(dir, run, cells, str(party))
			complete = complete and lines.size() >= cells.size()
			all_lines.append_array(lines)
			var m := Metrics.summarize(lines, Metrics.cfg(db))
			per_party[party] = { "metrics": m, "score": Metrics.fun_score(m, Metrics.cfg(db), Metrics.complexity(db, full)) }
		var named: Dictionary = (rule as Dictionary).duplicate()
		named["fightScaled"] = true
		var row := _robust({ "levers": named }, per_party, all_lines)
		row["picks"] = picks
		rows.append(row)
		print("  %.3f%s %s" % [float(row["score"]), " (fails: %s)" % str(row["reasons"]) if bool(row["dq"]) else " PASSES", Search.set_key(named)])
	var short := Search.shortlist(rows.filter(func(r: Dictionary) -> bool: return not bool(r["dq"])), int(plan.get("shortlist", 5)), int(plan.get("minDistance", 3)), base_values)
	if short.is_empty() and bool(plan.get("keepBestIfNonePass", false)):
		# Marked as not passing in the preset's data and text (Tuned.presets_for).
		short = Search.shortlist(rows, int(plan.get("shortlist", 5)), int(plan.get("minDistance", 3)), base_values)
	if complete:
		_write_scales(short)
		_write_tuned(base, short)
	return { "base": base, "rules": rules, "finals": rows, "shortlist": short, "space": [], "tried": rows.size(), "generations": 0, "complete": complete }


## The per-fight steps of the shortlisted sets, keyed by the preset ids they become.
func _write_scales(short: Array) -> void:
	var scales := {}
	for i in short.size():
		var table := {}
		for f in short[i]["picks"]:
			table[f] = short[i]["picks"][f]["levers"]
		scales[Tuned.PREFIX + str(i + 1)] = table
	var path := ProjectSettings.globalize_path("res://data/lab/fight_scales.json")
	var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out: Dictionary = old if typeof(old) == TYPE_DICTIONARY else {}
	out["scales"] = scales
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", false) + "\n")
	f.close()


func _score_sets(sets: Array, lines: Array, base_values: Dictionary) -> Array:
	var out: Array = []
	for s in sets:
		var mine: Array = []
		var lv := base_values.duplicate()
		lv.merge(s["levers"], true)
		var want := Search.set_key(s["levers"])
		for rec in lines:
			if Search.set_key(rec.get("leverSet", {})) == want:
				mine.append(rec)
		var m := Metrics.summarize(mine, Metrics.cfg(db))
		var sc := Metrics.fun_score(m, Metrics.cfg(db), Metrics.complexity(db, lv))
		out.append({ "levers": s["levers"], "score": sc["score"], "dq": sc["dq"], "reasons": sc["reasons"], "metrics": m })
	return out


## A finalist across parties: its worst party's score, disqualified if any party
## is, or if the expert loses too often in any one fight.
func _robust(fset: Dictionary, per_party: Dictionary, lines: Array) -> Dictionary:
	var worst := INF
	var dq := false
	var reasons: Array = []
	for p in per_party:
		var sc: Dictionary = per_party[p]["score"]
		worst = minf(worst, float(sc["score"]))
		if bool(sc["dq"]):
			dq = true
			for r in sc["reasons"]:
				reasons.append("%s: %s" % [p, r])
	var lim := float(Metrics.cfg(db).get("hardLimits", {}).get("minFightExpertWin", 0.5))
	var per_fight := {}
	for rec in lines:
		if str(rec.get("profile", "")) != "expert":
			continue
		var f := str(rec.get("fight", ""))
		if not per_fight.has(f):
			per_fight[f] = [0, 0]
		per_fight[f][0] += 1 if str(rec.get("result", "")) == "win" else 0
		per_fight[f][1] += 1
	var fight_wins := {}
	for f in per_fight:
		var share := float(per_fight[f][0]) / float(maxi(1, per_fight[f][1]))
		fight_wins[f] = snappedf(share, 0.01)
		if share < lim:
			dq = true
			reasons.append("expert wins %d%% of %s" % [roundi(share * 100.0), f])
	var m := Metrics.summarize(lines, Metrics.cfg(db))
	return { "levers": fset["levers"], "score": snappedf(worst, 0.001), "dq": dq, "reasons": reasons, "parties": per_party, "fightWins": fight_wins, "metrics": m }

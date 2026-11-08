## Sweep plans (docs/LAB_TUNER.md Parts 1 and 4): a plan in data/lab/sweeps/
## turns into cells, one headless fight each. Also the result files: one JSON
## line per fight, resumable (cells already in the file are skipped) and merged
## from parallel jobs. Files only, no nodes.
extends RefCounted

const Setup := preload("res://src/core/lab/lab_setup.gd")
const Rules := preload("res://src/core/combat/rules.gd")
const Sweep := preload("res://src/core/lab/sweep.gd")
const UserPaths := preload("res://src/core/user_paths.gd")

const PROFILES := ["expert", "novice", "greedy", "random"]


static func fights_of(db: Dictionary, spec: Variant) -> Array:
	if typeof(spec) == TYPE_ARRAY:
		return spec
	var out: Array = []
	for f in Setup.fights(db):
		out.append(str(f["id"]))
	return out


static func seeds_of(spec: Variant) -> Array:
	if typeof(spec) == TYPE_ARRAY:
		return spec
	var out: Array = []
	for i in maxi(1, int(spec)):
		out.append(i + 1)
	return out


## Every cell for one lever set: fights x seeds x profiles x parties.
static func cells_for(db: Dictionary, group: String, preset: String, levers: Dictionary, plan: Dictionary, fights: Variant = null) -> Array:
	var out: Array = []
	for f in fights_of(db, plan.get("fights", "all") if fights == null else fights):
		for s in seeds_of(plan.get("seeds", 1)):
			for p in plan.get("profiles", PROFILES):
				for party in plan.get("parties", ["balanced"]):
					out.append({ "group": group, "fight": str(f), "preset": preset, "levers": levers, "seed": int(s), "profile": str(p), "party": str(party) })
	return out


## A grid plan: named presets.
static func grid_cells(db: Dictionary, plan: Dictionary) -> Array:
	var out: Array = []
	for p in plan.get("presets", []):
		out.append_array(cells_for(db, "preset:" + str(p), str(p), plan.get("levers", {}), plan))
	return out


static func lever_spec(db: Dictionary, id: String) -> Dictionary:
	for s in Rules.lever_specs(db):
		if str(s["id"]) == id:
			return s
	return {}


## The values screening tries for a lever, other than the base's own.
static func screen_values(db: Dictionary, plan: Dictionary, spec: Dictionary, base_value: Variant) -> Array:
	var id := str(spec["id"])
	var given: Dictionary = plan.get("numeric", {})
	var out: Array = []
	match str(spec.get("type", "")):
		"bool":
			out = [not bool(base_value)]
		"enum":
			for o in spec.get("options", []):
				if str(o) != str(base_value):
					out.append(o)
		"int", "float":
			if given.has(id):
				out = given[id]
			else:
				var lo := float(spec.get("min", 0))
				var hi := float(spec.get("max", 1))
				for f in [0.0, 0.5, 1.0]:
					var v: float = lo + (hi - lo) * f
					out.append(roundi(v) if str(spec["type"]) == "int" else snappedf(v, float(spec.get("step", 0.05))))
			out = out.filter(func(v: Variant) -> bool: return str(v) != str(base_value) and float(v) != float(base_value))
	return out


## Screening: from each base, flip one lever (or try its values) at a time.
## Returns [{ group, base, lever, value, levers }]; the base itself is lever "".
static func screen_variants(db: Dictionary, plan: Dictionary) -> Array:
	var out: Array = []
	var skip_groups: Array = plan.get("skipGroups", [])
	var skip: Array = plan.get("skipLevers", [])
	var only: Variant = plan.get("levers", "all")
	for base in plan.get("bases", ["cl_base"]):
		var values := Rules.values_for(db, str(base))
		out.append({ "group": "screen:%s" % base, "base": str(base), "lever": "", "value": null, "levers": {} })
		for spec in Rules.lever_specs(db):
			var id := str(spec["id"])
			if skip_groups.has(str(spec.get("group", ""))) or skip.has(id):
				continue
			if typeof(only) == TYPE_ARRAY and not (only as Array).has(id):
				continue
			for v in screen_values(db, plan, spec, values.get(id)):
				out.append({ "group": "screen:%s|%s=%s" % [base, id, str(v)], "base": str(base), "lever": id, "value": v, "levers": { id: v } })
	return out


## The fights a screening variant plays: its lever's own, or the plan's.
static func variant_fights(db: Dictionary, plan: Dictionary, v: Dictionary) -> Array:
	if str(v["lever"]) != "":
		var spec := lever_spec(db, str(v["lever"]))
		if spec.has("fights"):
			return spec["fights"]
	return fights_of(db, plan.get("fights", "all"))


## Screening cells. Each base also plays every fight a lever names, so a lever
## is always compared with its base on the same fights.
static func screen_cells(db: Dictionary, plan: Dictionary) -> Array:
	var out: Array = []
	var base_fights := {}
	for v in screen_variants(db, plan):
		var fights := variant_fights(db, plan, v)
		if str(v["lever"]) != "":
			out.append_array(cells_for(db, str(v["group"]), str(v["base"]), v["levers"], plan, fights))
		if not base_fights.has(v["base"]):
			base_fights[v["base"]] = {}
		for f in fights:
			base_fights[v["base"]][str(f)] = true
	for b in base_fights:
		out.append_array(cells_for(db, "screen:%s" % b, str(b), {}, plan, (base_fights[b] as Dictionary).keys()))
	return out


## Cells for a list of lever sets: [{ group, base, levers }].
static func set_cells(db: Dictionary, sets: Array, plan: Dictionary) -> Array:
	var out: Array = []
	for s in sets:
		out.append_array(cells_for(db, str(s["group"]), str(s["base"]), s["levers"], plan))
	return out


# --- Result files ---------------------------------------------------------------

static func read_lines(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	for row in FileAccess.get_file_as_string(path).split("\n", false):
		var rec: Variant = JSON.parse_string(row)
		if typeof(rec) == TYPE_DICTIONARY:
			out.append(rec)
	return out


static func append_line(path: String, rec: Dictionary) -> void:
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_line(JSON.stringify(rec))
	f.close()


static func done_keys(lines: Array) -> Dictionary:
	var out := {}
	for rec in lines:
		out[str(rec.get("key", ""))] = true
	return out


## The cells a run still has to play.
static func pending(cells: Array, done: Dictionary) -> Array:
	return cells.filter(func(c: Dictionary) -> bool: return not done.has(Sweep.cell_key(c)))


## The share of cells this job plays (job i of n).
static func share(cells: Array, job: int, jobs: int) -> Array:
	var out: Array = []
	for i in cells.size():
		if i % maxi(1, jobs) == job:
			out.append(cells[i])
	return out


## Lines from every job, each cell once (the first copy wins).
static func merge(parts: Array) -> Array:
	var out: Array = []
	var seen := {}
	for part in parts:
		for rec in part:
			var k := str(rec.get("key", ""))
			if seen.has(k):
				continue
			seen[k] = true
			out.append(rec)
	return out


## Lines grouped by their "group" label.
static func by_group(lines: Array) -> Dictionary:
	var out := {}
	for rec in lines:
		var g := str(rec.get("group", ""))
		if not out.has(g):
			out[g] = []
		out[g].append(rec)
	return out


# --- Finished runs ----------------------------------------------------------------

static func run_dir(plan_id: String) -> String:
	return UserPaths.of("lab/sweeps/") + plan_id + "/"


## The latest finished summary of a plan ({} if none).
static func latest_summary(plan_id: String) -> Dictionary:
	var dir := run_dir(plan_id)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		return {}
	var names: Array = Array(DirAccess.get_files_at(dir)).filter(func(n: String) -> bool: return n.ends_with(".summary.json"))
	names.sort()
	names.reverse()
	for n in names:
		var s: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + str(n)))
		if typeof(s) == TYPE_DICTIONARY and bool(s.get("complete", false)):
			return s
	return {}


## Every agent rating card: user://lab/agents/<persona>/<preset>/<fight>.json.
static func agent_cards() -> Array:
	var out: Array = []
	var root := UserPaths.of("lab/agents/")
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root)):
		return out
	for persona in DirAccess.get_directories_at(root):
		for preset in DirAccess.get_directories_at(root + persona):
			for f in DirAccess.get_files_at(root + persona + "/" + preset):
				if not str(f).ends_with(".json"):
					continue
				var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(root + persona + "/" + preset + "/" + f))
				if typeof(rec) == TYPE_DICTIONARY:
					rec["persona"] = str(persona)
					rec["preset"] = str(preset)
					rec["fight"] = str(f).get_basename()
					out.append(rec)
	return out


## preset -> fun score from the latest finished shortlist run, else the baseline.
static func machine_scores() -> Dictionary:
	var out := {}
	for plan_id in ["baseline", "shortlist"]:
		var s := latest_summary(plan_id)
		for g in s.get("groups", {}):
			if str(g).begins_with("preset:"):
				var sc: Dictionary = s["groups"][g].get("score", {})
				out[str(g).trim_prefix("preset:")] = { "score": float(sc.get("score", 0.0)), "dq": bool(sc.get("dq", false)) }
	return out


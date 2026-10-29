## The shared effects vocabulary for events, dialogue outcomes, shops and story
## beats. An effects Dictionary is data; apply() edits the run and returns
## human-readable lines. Keys:
##   statXp {stat: bars}, stats {stat: n}, affinity {axis: w}, grade n (needs
##   ctx.professor) or gradeFor {prof: n}, bond {npc: n}, flag "x" or [...],
##   unflag, hp n, mp n, money n, item "id" or {id: n}, card "id", kellyRisk n,
##   learnVector "axis", learnForm "form", xp n, signature {axis: w},
##   counter {name: n}, disposition {npc: {axis: n}}, narratorBond n, sigHint (week hint), ap n (GameState applies it), narrate "text".
class_name Effects
extends RefCounted

const Str := preload("res://src/core/strings.gd")
const Mystery := preload("res://src/core/story/mystery.gd")

const RM := preload("res://src/core/run/run_model.gd")
const Char := preload("res://src/core/character.gd")
const Lv := preload("res://src/core/progression/leveling.gd")
const VO := preload("res://src/core/vector_ops.gd")
const DT := preload("res://src/core/data_tables.gd")


static func apply(db: Dictionary, run: Dictionary, fx: Dictionary, rng: RandomNumberGenerator, ctx: Dictionary = {}) -> Array:
	var lines: Array = []
	var p: Dictionary = run["player"]
	var mul := float(ctx.get("gainMul", 1.0))
	for stat in fx.get("statXp", {}):
		var r := RM.train_stat(db, p, str(stat), float(fx["statXp"][stat]) * mul)
		if int(r["gained"]) > 0:
			lines.append("%s +%d!" % [str(stat).to_upper(), int(r["gained"])])
		else:
			lines.append(Str.t(db, "effects.training_1f_0f") % [str(stat).to_upper(), float(r["bar"]), float(r["need"])])
	for stat in fx.get("stats", {}):
		var hi := int(db.get("stats", {}).get("statMax", 20))
		p["stats"][stat] = clampi(int(p["stats"].get(stat, 1)) + int(fx["stats"][stat]), 1, hi)
		lines.append("%s %+d" % [str(stat).to_upper(), int(fx["stats"][stat])])
	if fx.has("affinity"):
		var scaled := {}
		for axis in fx["affinity"]:
			scaled[axis] = float(fx["affinity"][axis]) * mul
		RM.nudge_affinity(db, p, scaled)
	if fx.has("grade") and ctx.has("professor"):
		_grade(db, run, str(ctx["professor"]), float(fx["grade"]) * (mul if float(fx["grade"]) > 0 else 1.0), lines)
	for prof in fx.get("gradeFor", {}):
		_grade(db, run, str(prof), float(fx["gradeFor"][prof]), lines)
	for npc in fx.get("bond", {}):
		change_bond(db, run, str(npc), float(fx["bond"][npc]), lines)
	var flags: Variant = fx.get("flag", [])
	if typeof(flags) == TYPE_STRING:
		flags = [flags]
	for f in flags:
		RM.set_flag(run, str(f))
	var unflags: Variant = fx.get("unflag", [])
	if typeof(unflags) == TYPE_STRING:
		unflags = [unflags]
	for f in unflags:
		run["flags"].erase(str(f))
	if fx.has("hp"):
		var d := Char.derived(db, p)
		var before := int(p.get("hp", d["maxHp"]))
		p["hp"] = clampi(before + int(fx["hp"]), 1, int(d["maxHp"]))
		lines.append(Str.t(db, "effects.hp_d") % (int(p["hp"]) - before))
	if fx.has("mp"):
		var d := Char.derived(db, p)
		var before := int(p.get("mp", d["maxMp"]))
		p["mp"] = clampi(before + int(fx["mp"]), 0, int(d["maxMp"]))
		lines.append(Str.t(db, "effects.mp_d") % (int(p["mp"]) - before))
	if fx.has("money"):
		run["money"] = maxi(0, int(run.get("money", 0)) + int(fx["money"]))
		lines.append("$%+d" % int(fx["money"]))
	var items: Variant = fx.get("item", {})
	if typeof(items) == TYPE_STRING:
		items = { items: 1 }
	for item_id in items:
		add_item(run, str(item_id), int(items[item_id]))
		var rec := DT.record(db, "items", str(item_id))
		lines.append(Str.t(db, "effects.got") % str(rec.get("name", item_id)))
	if fx.has("card"):
		var cid := str(fx["card"])
		run["collection"][cid] = int(run["collection"].get(cid, 0)) + 1
		# P2 1.3: whose deck it goes into is asked after the event (Flow).
		run["pendingCards"] = run.get("pendingCards", []) + [cid]
		lines.append(Str.t(db, "effects.new_card") % cid)
	if fx.has("kellyRisk"):
		run["kelly_risk"] = int(run.get("kelly_risk", 0)) + int(fx["kellyRisk"])
	if fx.has("learnVector"):
		var axis := str(fx["learnVector"])
		if not p["knownVectors"].has(axis):
			p["knownVectors"].append(axis)
			lines.append(Str.t(db, "effects.you_learned_the_vector") % axis.capitalize())
	if fx.has("learnForm"):
		var form := str(fx["learnForm"])
		if not p["knownForms"].has(form):
			p["knownForms"].append(form)
			lines.append(Str.t(db, "effects.you_learned_the_form") % form.capitalize())
	if fx.has("xp"):
		var reports := Lv.add_xp(db, p, int(fx["xp"]), rng)
		lines.append(Str.t(db, "effects.xp") % int(fx["xp"]))
		for r in reports:
			lines.append(Str.t(db, "effects.level") % int(r["level"]))
	if fx.has("signature"):
		run["signature"] = VO.shift(run.get("signature", {}), fx["signature"])
	for c in fx.get("counter", {}):
		run["shifts"][c] = int(run["shifts"].get(c, 0)) + int(fx["counter"][c])
	for npc in fx.get("disposition", {}):
		var state: Dictionary = npc_state(run, str(npc))
		state["disposition"] = VO.shift(state.get("disposition", {}), fx["disposition"][npc], {}, -100.0)
	if fx.has("narratorBond"):
		change_bond(db, run, "narrator", float(fx["narratorBond"]), lines)
	if bool(fx.get("sigHint", false)):
		lines.append(preload("res://src/core/dungeon/signature.gd").hint(db, run, int(ctx.get("week", 1))))
	if fx.has("narrate"):
		lines.append(str(fx["narrate"]))
	# M18: clues for the mystery board.
	var clues: Variant = fx.get("clue", [])
	for c in (clues if clues is Array else [clues]):
		if Mystery.add_clue(run, str(c)):
			lines.append(Str.t(db, "board.new_clue") % str(Mystery.clue(db, str(c)).get("text", c)))
	return lines


static func _grade(db: Dictionary, run: Dictionary, prof: String, delta: float, lines: Array) -> void:
	var g := clampf(float(run["grades"].get(prof, 0.0)) + delta, 0.0, 100.0)
	run["grades"][prof] = g
	if delta < 0:
		lines.append(Str.t(db, "effects.grade_with_d") % [prof.replace("_", " ").capitalize(), roundi(delta)])


## Bond change with the NPC's trait multipliers (All or nothing, Nervous, etc.).
## Clamped to -100..100. Returns the new value.
static func change_bond(db: Dictionary, run: Dictionary, npc: String, delta: float, lines: Array = []) -> float:
	var rec: Dictionary = db.get("npcs/" + npc, {})
	var mods := Char.merge_mods(_trait_mods(db, rec))
	var social: Dictionary = mods.get("social", {})
	if delta > 0:
		delta *= float(social.get("bondGainMul", 1.0))
	elif bool(social.get("noBondLoss", false)):
		delta = 0.0
	delta *= float(social.get("bondMul", 1.0))
	var before := float(run["bonds"].get(npc, float(rec.get("startBond", 0))))
	var after := clampf(before + delta, -100.0, 100.0)
	run["bonds"][npc] = after
	# M18: a friendship scene the first time Bond reaches a tier that has one.
	var t_before := tier_name(db, before)
	var t_after := tier_name(db, after)
	if t_after != t_before and after > before:
		var sid := "friend_%s_%s" % [npc, t_after.to_lower()]
		var pend: Array = run.get("pendingFriendScenes", [])
		if not pend.has(sid) and not run.get("flags", {}).has("cutscene_seen_" + sid) and _has_cutscene(db, sid):
			pend.append(sid)
			run["pendingFriendScenes"] = pend
	if roundi(after - before) != 0:
		lines.append("%s %+d" % [str(rec.get("name", npc.capitalize())), roundi(after - before)])
	return after


## The Bond tier name for a value (data/bonds.json tiers).
static func tier_name(db: Dictionary, value: float) -> String:
	var name := ""
	for t in db.get("bonds", {}).get("tiers", []):
		if value >= float(t.get("min", -100)):
			name = str(t.get("name", ""))
	return name


static func _has_cutscene(db: Dictionary, id: String) -> bool:
	for c in DT.records_under(db, "cutscenes/", "cutscenes"):
		if str(c.get("id", "")) == id:
			return true
	return false


static func _trait_mods(db: Dictionary, rec: Dictionary) -> Array:
	var out: Array = []
	var traits := DT.index_under(db, "traits", "traits")
	for t in rec.get("traits", []):
		if traits.has(str(t)):
			out.append(traits[str(t)].get("mods", {}))
	return out


static func add_item(run: Dictionary, item_id: String, n: int) -> void:
	var inv: Dictionary = run.get("inventory", {})
	inv[item_id] = maxi(0, int(inv.get(item_id, 0)) + n)
	if int(inv[item_id]) == 0:
		inv.erase(item_id)
	run["inventory"] = inv


## The per-NPC state Dictionary in the run (disposition, topics used, met).
static func npc_state(run: Dictionary, npc: String) -> Dictionary:
	if not run["npcs"].has(npc):
		run["npcs"][npc] = { "disposition": {}, "topics": {}, "met": false, "gifts": 0 }
	return run["npcs"][npc]


## Do the conditions hold? Keys: week, day, part, period, flag, notFlag,
## minGrade {prof: n}, minBond {npc: n}, maxBond, minStat {stat: n},
## kellyRiskAtLeast, minLevel, chance (needs rng).
static func conditions_met(db: Dictionary, run: Dictionary, cond: Dictionary, ctx: Dictionary = {}) -> bool:
	if cond.is_empty():
		return true
	if cond.has("week") and not _matches(cond["week"], int(ctx.get("week", 0))):
		return false
	if cond.has("day") and not _matches(cond["day"], str(ctx.get("day", ""))):
		return false
	if cond.has("part") and not _matches(cond["part"], str(ctx.get("part", ""))):
		return false
	if cond.has("period") and not _matches(cond["period"], int(ctx.get("period", 0))):
		return false
	if cond.has("minWeek") and int(ctx.get("week", 0)) < int(cond["minWeek"]):
		return false
	if cond.has("maxWeek") and int(ctx.get("week", 0)) > int(cond["maxWeek"]):
		return false
	var flags: Variant = cond.get("flag", [])
	if typeof(flags) == TYPE_STRING:
		flags = [flags]
	for f in flags:
		if not RM.flag(run, str(f)):
			return false
	var nflags: Variant = cond.get("notFlag", [])
	if typeof(nflags) == TYPE_STRING:
		nflags = [nflags]
	for f in nflags:
		if RM.flag(run, str(f)):
			return false
	for prof in cond.get("minGrade", {}):
		if float(run["grades"].get(prof, 0.0)) < float(cond["minGrade"][prof]):
			return false
	for npc in cond.get("minBond", {}):
		if RM.bond(run, str(npc)) < float(cond["minBond"][npc]):
			return false
	for npc in cond.get("maxBond", {}):
		if RM.bond(run, str(npc)) > float(cond["maxBond"][npc]):
			return false
	if not cond.get("minStat", {}).is_empty():
		var st := Char.effective_stats(db, run["player"])
		for s in cond["minStat"]:
			if int(st.get(s, 0)) < int(cond["minStat"][s]):
				return false
	if cond.has("minAp") and int(ctx.get("ap", 99)) < int(cond["minAp"]):
		return false
	if cond.has("minMoney") and int(run.get("money", 0)) < int(cond["minMoney"]):
		return false
	if cond.has("kellyRiskAtLeast") and int(run.get("kelly_risk", 0)) < int(cond["kellyRiskAtLeast"]):
		return false
	if cond.has("minLevel") and int(run["player"].get("level", 1)) < int(cond["minLevel"]):
		return false
	for c in cond.get("minCounter", {}):
		if int(run["shifts"].get(c, 0)) < int(cond["minCounter"][c]):
			return false
	return true


## A condition value may be a single value or a list of allowed values.
static func _matches(allowed: Variant, value: Variant) -> bool:
	if typeof(allowed) == TYPE_ARRAY:
		for a in allowed:
			if str(a) == str(value) or (typeof(value) == TYPE_INT and int(a) == int(value)):
				return true
		return false
	if typeof(value) == TYPE_INT:
		return int(allowed) == int(value)
	return str(allowed) == str(value)

## School rules (DESIGN.md Section 4): the weekly schedule, attending a class
## (stat XP bars, affinity nudge, Grade with the professor), class events drawn
## by weighted Sample from data/events/class_events.json, and skipping with
## detention after 3 skips in a week.
class_name School
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const VO := preload("res://src/core/vector_ops.gd")
const DT := preload("res://src/core/data_tables.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Char := preload("res://src/core/character.gd")


static func classes(db: Dictionary) -> Array:
	return db.get("school_classes", {}).get("classes", [])


static func class_rec(db: Dictionary, id: String) -> Dictionary:
	return DT.record(db, "school_classes", id)


## Why this class can't be taken, or "".
static func class_gate_error(db: Dictionary, run: Dictionary, id: String) -> String:
	var cls := class_rec(db, id)
	if cls.is_empty():
		return Str.t(db, "school.no_such_class")
	var gate: Dictionary = cls.get("gate", {})
	if gate.is_empty():
		return ""
	for prior in gate.get("attended", {}):
		if int(run["attendance"].get(prior, 0)) < int(gate["attended"][prior]):
			return Str.t(db, "school.needs_attended_times") % [str(class_rec(db, str(prior)).get("name", prior)), int(gate["attended"][prior])]
	var st := Char.effective_stats(db, run["player"])
	for s in gate.get("stats", {}):
		if int(st.get(s, 0)) < int(gate["stats"][s]):
			return Str.t(db, "school.needs") % [str(s).to_upper(), int(gate["stats"][s])]
	if gate.has("tier") and int(run["player"].get("knowledgeTier", 1)) < int(gate["tier"]):
		return Str.t(db, "school.needs_knowledge_tier") % int(gate["tier"])
	return ""


static func schedule_error(db: Dictionary, run: Dictionary, schedule: Array) -> String:
	if schedule.size() != 3:
		return Str.t(db, "school.pick_one_class_for_each")
	for id in schedule:
		var err := class_gate_error(db, run, str(id))
		if err != "":
			return err
	return ""


static func set_schedule(db: Dictionary, run: Dictionary, schedule: Array, week: int) -> String:
	var err := schedule_error(db, run, schedule)
	if err == "":
		run["schedule"] = schedule.duplicate()
		run["schedule_week"] = week
	return err


## Attend the class in `period` (1-3). Applies the base gains and returns
## { "class", "lines", "event" } where event is the drawn class event (not yet
## resolved: the UI shows it, the player picks, then resolve_event()).
static func attend(db: Dictionary, run: Dictionary, period: int, rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	var cid := str(run["schedule"][period - 1])
	var cls := class_rec(db, cid)
	var train: Dictionary = db.get("stats", {}).get("training", {})
	var mul := 1.0
	if run["attended_today"].has(cid):
		mul = float(train.get("repeatMul", 0.5))
	run["attended_today"].append(cid)
	run["attendance"][cid] = int(run["attendance"].get(cid, 0)) + 1
	run["attendance_week"][cid] = int(run["attendance_week"].get(cid, 0)) + 1
	var fx := class_gains(db, cls)
	var c := ctx.duplicate()
	c["professor"] = str(cls.get("professor", ""))
	c["gainMul"] = mul
	c["class"] = cid
	c["period"] = period
	var lines: Array = [Str.t(db, "school.you_attend") % [cls.get("name", cid), Str.t(db, "school.again_half_gains") if mul < 1.0 else ""]]
	lines.append_array(Fx.apply(db, run, fx, rng, c))
	var event := pick_event(db, run, cid, rng, c)
	if not event.is_empty():
		var counts: Dictionary = run.get("class_events_seen", {})
		var times := int(counts.get(str(event["id"]), 0))
		counts[str(event["id"])] = times + 1
		run["class_events_seen"] = counts
		if times > 0 and event.has("short"):
			# A repeat plays its short version so it never drags.
			event = event.duplicate()
			event["text"] = str(event["short"])
	if not event.is_empty() and bool(event.get("once", false)):
		run["events_seen"][str(event["id"])] = true
	return { "class": cid, "lines": lines, "event": event, "ctx": c }


## Base gains for one attendance: stat bars, +2 affinity, +Grade.
static func class_gains(db: Dictionary, cls: Dictionary) -> Dictionary:
	var train: Dictionary = db.get("stats", {}).get("training", {})
	var bars := {}
	for s in cls.get("statGains", []):
		bars[s] = float(train.get("classBars", 1.0))
	return { "statXp": bars, "affinity": cls.get("affinity", {}), "grade": float(cls.get("gradeGain", 3)) }


## Draw an event: forced events whose conditions hold come first (story beats);
## otherwise Sample by weight among the eligible events for this class.
static func pick_event(db: Dictionary, run: Dictionary, cid: String, rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	var eligible := {}
	var order: Array = []
	var forced := {}
	for e in db.get("events/class_events", {}).get("events", []):
		var ec := str(e.get("class", "any"))
		if ec != cid and ec != "any":
			continue
		if bool(e.get("once", false)) and run["events_seen"].has(str(e["id"])):
			continue
		if not Fx.conditions_met(db, run, e.get("cond", {}), ctx):
			continue
		if bool(e.get("forced", false)):
			if forced.is_empty() or int(e.get("priority", 0)) > int(forced.get("priority", 0)):
				forced = e
			continue
		# M16: events seen before are much rarer (each repeat quarters the weight).
		var seen := int(run.get("class_events_seen", {}).get(str(e["id"]), 0))
		eligible[str(e["id"])] = float(e.get("weight", 1.0)) * pow(float(db.get("school_classes", {}).get("rules", {}).get("repeatWeight", 0.25)), float(seen))
		order.append(str(e["id"]))
	if not forced.is_empty():
		return forced
	if eligible.is_empty():
		return {}
	var pick := VO.sample(eligible, rng, order)
	for e in db.get("events/class_events", {}).get("events", []):
		if str(e["id"]) == pick:
			return e
	return {}


## Resolve an event, optionally with a choice. Returns { "lines", "success" }.
## A check is d6 + the stat against dc; a quiz success repeats the class gains.
static func resolve_event(db: Dictionary, run: Dictionary, event: Dictionary, choice: int, rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	var lines: Array = []
	var node: Dictionary = event
	var choices: Array = event.get("choices", [])
	if choice >= 0 and choice < choices.size():
		node = choices[choice]
	var success := true
	if node.has("check"):
		var chk: Dictionary = node["check"]
		var st := Char.effective_stats(db, run["player"])
		var roll := rng.randi_range(1, 6) + int(st.get(str(chk.get("stat", "int")), 0))
		success = roll >= int(chk.get("dc", 10))
		lines.append(Str.t(db, "school.check_vs") % [str(chk.get("stat", "")).to_upper(), roll, int(chk.get("dc", 10)), "success" if success else "fail"])
	var fx: Dictionary = node.get("success" if success else "fail", node.get("effects", {}))
	var text := str(node.get("successText" if success else "failText", node.get("result", "")))
	if text != "":
		lines.append(fill(text, ctx))
	var c := ctx.duplicate()
	if bool(fx.get("repeatClassGain", false)) and ctx.has("class"):
		lines.append_array(Fx.apply(db, run, class_gains(db, class_rec(db, str(ctx["class"]))), rng, c))
	if fx.has("bondPartner") and ctx.has("partner"):
		Fx.change_bond(db, run, str(ctx["partner"]), float(fx["bondPartner"]), lines)
	lines.append_array(Fx.apply(db, run, fx, rng, c))
	return { "lines": lines, "success": success }


## Pick a partner for partner-work events from the class's classmates.
static func pick_partner(db: Dictionary, cid: String, rng: RandomNumberGenerator) -> String:
	var mates: Array = class_rec(db, cid).get("classmates", [])
	if mates.is_empty():
		return ""
	return str(mates[rng.randi_range(0, mates.size() - 1)])


## Fill {teacher}, {class}, {partner} placeholders.
static func fill(text: String, ctx: Dictionary) -> String:
	for key in ["teacher", "class_name", "partner_name"]:
		text = text.replace("{%s}" % key.trim_suffix("_name"), str(ctx.get(key, "")))
	return text


## Skip the class in `period`. Grade drops; the third skip in a week sets up detention.
static func skip(db: Dictionary, run: Dictionary, period: int) -> Array:
	var cid := str(run["schedule"][period - 1])
	var cls := class_rec(db, cid)
	var cfg: Dictionary = db.get("school_classes", {}).get("rules", {})
	run["skips_week"] = int(run.get("skips_week", 0)) + 1
	run["skips_total"] = int(run.get("skips_total", 0)) + 1
	var lines: Array = [Str.t(db, "school.you_skip") % cls.get("name", cid)]
	Fx.apply(db, run, { "gradeFor": { str(cls.get("professor", "")): -float(cfg.get("skipGradeLoss", 5)) } }, null, {})
	if int(run["skips_week"]) >= int(cfg.get("skipsForDetention", 3)) and not RM.flag(run, "detention_this_week"):
		run["detention_pending"] = true
		RM.set_flag(run, "detention_this_week")
		lines.append(Str.t(db, "school.that_s_three_skips_this"))
	return lines


## Weekly reset (call when a new week starts).
static func new_week(run: Dictionary) -> void:
	run["skips_week"] = 0
	run["attendance_week"] = {}
	run["flags"].erase("detention_this_week")


static func new_day(run: Dictionary) -> void:
	run["attended_today"] = []

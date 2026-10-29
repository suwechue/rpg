## TL Part 7: the goal tracker ("What can I do?"). Gathers what's open right
## now from the town, favors, the mystery board, Bonds and the forge, as lines
## per section. The HUD (G) and the town pause menu show it.
extends RefCounted

const Str := preload("res://src/core/strings.gd")
const DT := preload("res://src/core/data_tables.gd")
const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Sched := preload("res://src/core/town/schedule.gd")
const Locs := preload("res://src/core/town/locations.gd")
const Favors := preload("res://src/core/town/favors.gd")
const Mystery := preload("res://src/core/story/mystery.gd")
const Phone := preload("res://src/core/social/phone.gd")
const CS := preload("res://src/core/story/cutscenes.gd")

const SECTIONS := ["places", "favors", "leads", "bonds", "gear"]


## { section: [line, ...] } for this moment. ctx: week, day, part, day_count.
static func build(db: Dictionary, run: Dictionary, ctx: Dictionary) -> Dictionary:
	var week := int(ctx.get("week", 1))
	var day := str(ctx.get("day", "mon"))
	var part := str(ctx.get("part", ""))
	var dc := int(ctx.get("day_count", 0))
	return {
		"places": places(db, run, week, day, part, dc),
		"favors": favors(db, run, week, part, dc),
		"leads": leads(db, run),
		"bonds": bonds(db, run, dc),
		"gear": gear(db, run, dc),
	}


## Open places, the ones with people you know first ("Gary's Deli: Gary, Dex").
static func places(db: Dictionary, run: Dictionary, week: int, day: String, part: String, dc: int) -> Array:
	var who_at: Dictionary = {}
	for id in run.get("npcs", {}):
		if not bool(run["npcs"][id].get("met", false)):
			continue
		var loc := Sched.location_of(db, run, str(id), day, part, dc)
		if loc != "":
			var names: Array = who_at.get(loc, [])
			names.append(str(db.get("npcs/" + str(id), {}).get("name", id)).split(" ")[0])
			who_at[loc] = names
	var with_people: Array = []
	var empty: Array = []
	for r in Locs.all(db):
		var id := str(r.get("id", ""))
		if Locs.closed_reason(db, run, id, week, part) != "":
			continue
		if who_at.has(id):
			with_people.append(Str.t(db, "goals.place_people") % [str(r.get("name", id)), ", ".join(PackedStringArray(who_at[id]))])
		else:
			empty.append(str(r.get("name", id)))
	var out := with_people
	if not empty.is_empty():
		out.append(Str.t(db, "goals.place_also") % ", ".join(PackedStringArray(empty)))
	return out


static func favors(db: Dictionary, run: Dictionary, week: int, part: String, dc: int) -> Array:
	var out: Array = []
	for id in Favors.open_now(db, run, week, part, Sched.day_rng(run, "favors", dc)):
		var f := Favors.find(db, str(id))
		out.append(Str.t(db, "goals.favor") % [str(f.get("name", id)), int(f.get("ap", 1))])
	return out


## Clue pairs on the board that make a deduction you haven't made.
static func leads(db: Dictionary, run: Dictionary) -> Array:
	var out: Array = []
	var have: Array = run.get("clues", [])
	var done: Array = run.get("deductions", [])
	var ready := 0
	for d in Mystery.cfg(db).get("deductions", []):
		var pair: Array = d.get("clues", [])
		if done.has(str(d["id"])) or pair.is_empty():
			continue
		if pair.all(func(c: Variant) -> bool: return have.has(str(c))):
			ready += 1
	if ready > 0:
		out.append(Str.t(db, "goals.leads_ready") % ready)
	if not have.is_empty():
		out.append(Str.t(db, "goals.clues") % [have.size(), done.size()])
	return out


## Plans today, scenes waiting, and friends close to a tier with a scene.
static func bonds(db: Dictionary, run: Dictionary, dc: int) -> Array:
	var out: Array = []
	var inv := Phone.invite_today(run, dc)
	if inv != "":
		out.append(Str.t(db, "goals.hangout_today") % _name(db, inv))
	var skip := Phone.skip_invite_today(run, dc)
	if skip != "":
		out.append(Str.t(db, "goals.skip_today") % _name(db, skip))
	if not run.get("pendingFriendScenes", []).is_empty():
		out.append(Str.t(db, "goals.scenes_waiting") % run["pendingFriendScenes"].size())
	var tiers: Array = db.get("bonds", {}).get("tiers", [])
	for id in run.get("bonds", {}):
		var b := RM.bond(run, str(id))
		for t in tiers:
			var need := float(t.get("min", 0))
			if need <= b or need - b > 5.0:
				continue
			var sid := "friend_%s_%s" % [str(id), str(t.get("name", "")).to_lower()]
			if not run.get("flags", {}).has("cutscene_seen_" + sid) and not CS.find(db, sid).is_empty():
				out.append(Str.t(db, "goals.near_tier") % [_name(db, str(id)), str(t.get("name", "")), roundi(need - b)])
			break
	return out


## Commissions in progress, broken pieces, gear in the bag nobody wears.
static func gear(db: Dictionary, run: Dictionary, dc: int) -> Array:
	var out: Array = []
	for o in run.get("orders", []):
		var nm := str(_item(db, str(o["item"])).get("name", o["item"]))
		var left := int(o["ready"]) - dc
		out.append(Str.t(db, "goals.order_ready") % nm if left <= 0 else Str.t(db, "goals.order_days") % [nm, left])
	for id in run.get("gear", {}):
		if int(run["gear"][id].get("durability", -1)) == 0:
			out.append(Str.t(db, "goals.broken") % str(_item(db, str(id)).get("name", id)))
	var loose := 0
	for id in run.get("inventory", {}):
		if str(_item(db, str(id)).get("kind", "")) == "equipment":
			loose += int(run["inventory"][id])
	if loose > 0:
		out.append(Str.t(db, "goals.unworn") % loose)
	return out


static func _item(db: Dictionary, id: String) -> Dictionary:
	return DT.record(db, "items", id)


static func _name(db: Dictionary, id: String) -> String:
	return str(db.get("npcs/" + id, {}).get("name", id)).split(" ")[0]


## TL Part 7: run-end lines: attendance against skips, what skipping bought,
## and the gear each character finished with.
static func run_summary(db: Dictionary, run: Dictionary, chars: Array) -> Array:
	var attended := 0
	for cid in run.get("attendance", {}):
		attended += int(run["attendance"][cid])
	var out: Array = [Str.t(db, "summary.attendance") % [attended, int(run.get("skips_total", 0))]]
	var pals: Array = []
	for id in run.get("skippedWith", []):
		if not pals.has(_name(db, str(id))):
			pals.append(_name(db, str(id)))
	if not pals.is_empty():
		out.append(Str.t(db, "summary.skip_friends") % ", ".join(PackedStringArray(pals)))
	var met := 0
	for f in run.get("flags", {}):
		if str(f).begins_with("seen_day_"):
			met += 1
	out.append(Str.t(db, "summary.daytime") % [met, run.get("clues", []).size()])
	for ch in chars:
		var c: Dictionary = ch
		var names: Array = []
		for slot in c.get("equipment", {}):
			var id := str(c["equipment"][slot])
			if id != "":
				var lvl := int(run.get("gear", {}).get(id, {}).get("level", 0))
				names.append(str(_item(db, id).get("name", id)) + (" +%d" % lvl if lvl > 0 else ""))
		out.append(Str.t(db, "summary.gear") % [str(c.get("name", "")), ", ".join(PackedStringArray(names)) if not names.is_empty() else Str.t(db, "summary.no_gear")])
	return out

## Authored story sequences (data/story/*.json): which are due now, choices
## that can be misheard, Kelly Risk from the first fight, and the panic check.
## Story steps: event, narrate, guest, foreshadow, combat, kellyCheck.
class_name Story
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Dlg := preload("res://src/core/social/dialogue_check.gd")
const Char := preload("res://src/core/character.gd")


static func all(db: Dictionary) -> Array:
	var out: Array = []
	var keys: Array = db.keys()
	keys.sort()
	for key in keys:
		if str(key).begins_with("story/"):
			out.append_array(db[key].get("stories", []))
	return out


static func find(db: Dictionary, id: String) -> Dictionary:
	for s in all(db):
		if str(s.get("id", "")) == id:
			return s
	return {}


static func table_for(db: Dictionary, id: String) -> Dictionary:
	for key in db:
		if str(key).begins_with("story/"):
			for s in db[key].get("stories", []):
				if str(s.get("id", "")) == id:
					return db[key]
	return {}


static func done(run: Dictionary, id: String) -> bool:
	return RM.flag(run, "story_done_" + id)


## Stories whose trigger matches this moment and haven't played.
static func due(db: Dictionary, run: Dictionary, ctx: Dictionary, inline: bool) -> Array:
	var out: Array = []
	for s in all(db):
		if bool(s.get("inline", false)) != inline or done(run, str(s["id"])):
			continue
		# Stories with a place wait until the player gets there (due_at).
		if s.has("at"):
			continue
		if Fx.conditions_met(db, run, s.get("trigger", {}), ctx) and Fx.conditions_met(db, run, s.get("cond", {}), ctx):
			out.append(str(s["id"]))
	return out


## Stories tied to a place ("at": { "zone": id } or { "loc": id }) that are
## due now: their week and day match, their day part has started (they stay
## available for the rest of that day), and the player is in that zone or
## near that location (near_locs: location ids within reach).
static func due_at(db: Dictionary, run: Dictionary, ctx: Dictionary, zone: String, near_locs: Array) -> Array:
	var out: Array = []
	var parts := part_order(db, str(ctx.get("day", "")))
	for s in all(db):
		if not s.has("at") or done(run, str(s["id"])):
			continue
		var at: Dictionary = s["at"]
		if at.has("zone") and str(at["zone"]) != zone:
			continue
		if at.has("loc") and not near_locs.has(str(at["loc"])):
			continue
		var trig: Dictionary = s.get("trigger", {}).duplicate()
		var want := str(trig.get("part", ""))
		trig.erase("part")
		if want != "" and parts.find(str(ctx.get("part", ""))) < parts.find(want):
			continue
		if want != "" and parts.find(want) < 0:
			continue
		if Fx.conditions_met(db, run, trig, ctx) and Fx.conditions_met(db, run, s.get("cond", {}), ctx):
			out.append(str(s["id"]))
	return out


## The day parts of a day, in order (weekday or weekend).
static func part_order(db: Dictionary, day: String) -> Array:
	var cal: Dictionary = db.get("calendar", {})
	var weekend: Array = cal.get("weekendDays", [])
	var parts: Array = cal.get("weekendParts" if weekend.has(day) else "weekdayParts", [])
	return parts.map(func(p: Variant) -> String: return str(p.get("id", "")) if p is Dictionary else str(p))


## Resolve a choice that may be misheard (a choice with "misheard": { risk,
## effects, result }). Returns the effective choice Dictionary.
static func resolve_choice(db: Dictionary, run: Dictionary, choice: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not choice.has("misheard"):
		return choice
	var m: Dictionary = choice["misheard"]
	if rng.randf() < Dlg.misheard_chance(db, run, float(m.get("risk", 0.2)), "neutral"):
		var out: Dictionary = m.duplicate()
		out["wasMisheard"] = true
		return out
	return choice


## Kelly Risk from a fight with her as a guest: ignored calls for help and
## shields or heals on her.
static func combat_risk(step: Dictionary, summary: Dictionary, guest_id: String) -> int:
	var risk := 0
	if int(summary.get("helpIgnored", 0)) > 0:
		risk += int(step.get("helpIgnoredRisk", 2))
	if int(summary.get("support", {}).get(guest_id, 0)) > 0:
		risk += int(step.get("supportRisk", -2))
	return risk


## The panic moment: "death" at Risk 4 or more, otherwise "survive".
static func kelly_outcome(db: Dictionary, run: Dictionary, story_id: String) -> String:
	var limit := int(table_for(db, story_id).get("kellyRiskDeath", 4))
	return "death" if int(run.get("kelly_risk", 0)) >= limit else "survive"


## After surviving: Kelly's Bond starts from her Risk result, and a kind night
## (Risk 0 or less) earns her loyalty and opens recruitment later.
static func apply_survival(db: Dictionary, run: Dictionary) -> Array:
	var lines: Array = []
	var risk := int(run.get("kelly_risk", 0))
	Fx.change_bond(db, run, "kelly", float(3 - risk) * 4.0, lines)
	if risk <= 0:
		RM.set_flag(run, "kelly_survived_kind")
		var st := Fx.npc_state(run, "kelly")
		var disp: Dictionary = st.get("disposition", {}).duplicate()
		disp["loyalty"] = float(db.get("npcs/kelly", {}).get("restingLoyaltyEarned", 60))
		st["disposition"] = disp
	return lines


## A temporary guest ally (Kelly on night one): a character from NPC data,
## AI-controlled, stored in run.guests.
static func make_guest(db: Dictionary, run: Dictionary, id: String, rng: RandomNumberGenerator) -> Dictionary:
	var rec := Dlg.npc(db, id)
	var combat: Dictionary = rec.get("combat", {})
	var ch := Char.create(db, str(combat.get("class", "fighter")), rng, {
		"id": id, "name": str(rec.get("name", id)), "stats": combat.get("stats", {}),
		"knownVectors": combat.get("vectors", []), "traits": rec.get("traits", []) })
	ch["sprite"] = str(rec.get("sprite", ""))
	ch["guest"] = true
	ch["helpLine"] = str(rec.get("helpLine", Str.t(db, "story.help")))
	ch["disposition"] = rec.get("disposition", {})
	if not run.has("guests"):
		run["guests"] = []
	run["guests"].append(ch)
	return ch


static func clear_guests(run: Dictionary) -> void:
	run["guests"] = []

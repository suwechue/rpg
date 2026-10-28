## Everything active right now (P2 Part 2): arena mutators, run modifiers
## (difficulty, Easy minigames, the starting trait, the F1 override), story
## effects (injuries, Kelly's Risk) and each party member's perks and
## Techniques. The effects strip, the Effects page and the tests all read this.
## Pure: the caller passes the run and a small context.
extends RefCounted

const DT := preload("res://src/core/data_tables.gd")
const Str := preload("res://src/core/strings.gd")


## Icon id for an effect, with the default for its kind as the fallback.
static func icon_for(db: Dictionary, kind: String, id: String, explicit: String = "") -> String:
	if explicit != "":
		return explicit
	var own := "icon_%s_%s" % [kind, id]
	var assets: Dictionary = db.get("assets/manifest", {})
	assets = assets.get("assets", assets)
	return own if assets.has(own) else "icon_%s_default" % kind


## ctx: { "difficulty", "easyMinigames", "turnOverride", "dataTurnMode" }.
## Returns [{ kind, id, name, text, source, duration, icon, tone, member }].
static func gather(db: Dictionary, run: Dictionary, ctx: Dictionary = {}) -> Array:
	var out: Array = []
	var arena: Dictionary = run.get("arena", run.get("rift", {}))
	if not arena.is_empty():
		var every := int(db.get("arena/checkpoint", {}).get("every", 5))
		var left := every - (int(arena.get("wave", 0)) % every)
		for m in arena.get("mutators", []):
			var eff: Dictionary = m.get("effects", {})
			var risky := bool(eff.get("noRest", false)) or float(eff.get("enemyHpMul", 1.0)) > 1.0 or float(eff.get("enemyDamageMul", 1.0)) > 1.0
			out.append({ "kind": "mutator", "id": str(m.get("id", "")), "name": str(m.get("name", "")), "text": str(m.get("text", "")),
				"source": Str.t(db, "effects.src_mutator") % int(arena.get("mutatorWave", arena.get("wave", 0))), "duration": Str.t(db, "effects.waves_left") % left,
				"icon": icon_for(db, "mutator", str(m.get("id", "")), str(m.get("icon", ""))), "tone": "risky" if risky else "good", "member": "" })
	var diff := str(ctx.get("difficulty", "normal"))
	var drec: Dictionary = db.get("combat_rules", {}).get("difficulties", {}).get(diff, {})
	out.append({ "kind": "effect", "id": "difficulty", "name": Str.t(db, "effects.difficulty") % str(drec.get("name", diff.capitalize())),
		"text": Str.t(db, "effects.difficulty_text_" + diff), "source": Str.t(db, "effects.src_run"), "duration": Str.t(db, "effects.whole_run"),
		"icon": icon_for(db, "effect", "difficulty"), "tone": "risky" if diff == "hard" else "neutral", "member": "" })
	if bool(ctx.get("easyMinigames", false)):
		out.append({ "kind": "effect", "id": "easy_minigames", "name": Str.t(db, "effects.easy_minigames"), "text": Str.t(db, "effects.easy_minigames_text"),
			"source": Str.t(db, "effects.src_options"), "duration": "", "icon": icon_for(db, "effect", "easy_minigames"), "tone": "good", "member": "" })
	var override := str(ctx.get("turnOverride", ""))
	if override != "" and override != str(ctx.get("dataTurnMode", "")):
		out.append({ "kind": "effect", "id": "turn_override", "name": Str.t(db, "effects.turn_override") % override, "text": Str.t(db, "effects.turn_override_text"),
			"source": "F1", "duration": "", "icon": icon_for(db, "effect", "turn_override"), "tone": "warning", "member": "" })
	var traits := DT.index_under(db, "traits", "traits")
	for t in run.get("player", {}).get("traits", []):
		var rec: Dictionary = traits.get(str(t), {})
		out.append({ "kind": "effect", "id": "trait_" + str(t), "name": str(rec.get("name", t)), "text": str(rec.get("text", "")),
			"source": Str.t(db, "effects.src_trait"), "duration": Str.t(db, "effects.whole_run"), "icon": icon_for(db, "effect", "trait"), "tone": "neutral", "member": "player" })
	for ch in run.get("roster", []):
		if int(ch.get("injured", 0)) > 0:
			out.append({ "kind": "effect", "id": "injured_" + str(ch.get("id", "")), "name": Str.t(db, "effects.injured") % str(ch.get("name", "?")),
				"text": Str.t(db, "effects.injured_text"), "source": Str.t(db, "effects.src_story"), "duration": Str.t(db, "effects.days_left") % int(ch["injured"]),
				"icon": icon_for(db, "effect", "injured"), "tone": "risky", "member": str(ch.get("id", "")) })
	var risk := int(run.get("kelly_risk", 0))
	for g in run.get("guests", []):
		if g is Dictionary and str(g.get("id", "")) == "kelly" and risk > 0:
			out.append({ "kind": "effect", "id": "kelly_risk", "name": Str.t(db, "effects.kelly_risk") % risk, "text": Str.t(db, "effects.kelly_risk_text"),
				"source": Str.t(db, "effects.src_story"), "duration": Str.t(db, "effects.tonight"), "icon": icon_for(db, "effect", "kelly_risk"), "tone": "risky", "member": "kelly" })
	out.append_array(member_effects(db, run))
	return out


## Perks (and Techniques) per party member, for badges and the Effects page.
static func member_effects(db: Dictionary, run: Dictionary) -> Array:
	var out: Array = []
	var perks := DT.index_under(db, "perks", "perks")
	var techs := DT.index_under(db, "techniques", "techniques")
	var members: Array = [run.get("player", {})]
	for id in run.get("party_ids", []):
		for ch in run.get("roster", []):
			if str(ch.get("id", "")) == str(id):
				members.append(ch)
	for ch in members:
		if (ch as Dictionary).is_empty():
			continue
		var cls: Dictionary = {}
		for c in db.get("classes", {}).get("classes", []):
			if str(c.get("id", "")) == str(ch.get("class", "")):
				cls = c
		var cp: Dictionary = cls.get("perk", {})
		if not cp.is_empty():
			out.append({ "kind": "perk", "id": str(cp.get("id", "")), "name": str(cp.get("name", str(cp.get("id", "")).capitalize())), "text": str(cp.get("text", "")),
				"source": Str.t(db, "effects.src_class") % str(cls.get("name", "")), "duration": "", "icon": icon_for(db, "perk", str(cp.get("id", ""))), "tone": "good", "member": str(ch.get("id", "")) })
		for p in ch.get("perks", []):
			var rec: Dictionary = perks.get(str(p), {})
			out.append({ "kind": "perk", "id": str(p), "name": str(rec.get("name", p)), "text": str(rec.get("text", "")), "source": Str.t(db, "effects.src_perk"),
				"duration": "", "icon": icon_for(db, "perk", str(p)), "tone": "good", "member": str(ch.get("id", "")) })
		for t in ch.get("techniques", []):
			var rec: Dictionary = techs.get(str(t), {})
			out.append({ "kind": "technique", "id": str(t), "name": str(rec.get("name", t)), "text": str(rec.get("text", "")),
				"source": Str.t(db, "effects.src_technique") % str(rec.get("category", "")).capitalize(), "duration": "",
				"icon": icon_for(db, "technique", str(t)), "tone": "good", "member": str(ch.get("id", "")) })
	return out

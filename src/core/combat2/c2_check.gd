## Combat 2.0 data checks (docs/COMBAT_2.md): every move, spell, ultimate, perk,
## gear piece, character, enemy and fight in data/combat2/ refers to things that
## exist and fits its slots. DataDB._validate() reports these; tests run them too.
## Pure data.
extends RefCounted

const C2Rules := preload("res://src/core/combat2/c2_rules.gd")
const Kits := preload("res://src/core/combat2/kits.gd")

const SHAPES := ["adjacent", "line", "cone", "plus", "plus_wide", "burst", "area", "leap", "dash", "projectile", "self", "ally"]
const TARGETS := ["enemy", "ally", "self", "tile"]
const MARKS := ["weak", "resist", "immune"]
const SLOTS := ["weapon", "armor", "trinket"]
const EFFECTS := ["wallSlam", "oneMoreHeal", "batonInit", "firstSpellFree", "backKnockdown", "weakWhileStatus", "pinDowned", "chargeMod",
	"damagePct", "pushPlus", "killStep", "braceExtra", "healPct", "batonPct", "revealOnFirstHit", "ultRate", "cooldownCut", "movementPlus",
	"initiativePlus", "maxHpPlus", "allOutPct", "followUpPlus", "protectOnce", "standHeal"]


static func problems(db: Dictionary) -> Array:
	if not db.has("combat2/rules"):
		return []
	var out: Array = []
	var types: Array = (db.get("spaces", {}).get("arcane", {}).get("axes", []) as Array).duplicate()
	types.append_array(db.get("combat2/rules", {}).get("physicalTypes", []))
	var rules := C2Rules.build(db) as C2Rules
	for m in db.get("combat2/moves", {}).get("moves", []):
		_ability(out, "move", m, types)
	for s in db.get("combat2/spells", {}).get("spells", []):
		_ability(out, "spell", s, types)
		for v in s.get("vectors", []):
			if not types.has(str(v)):
				out.append("C2 spell %s: unknown Vector '%s'" % [s.get("id"), v])
		if not db.get("combat2/rules", {}).get("magnitudes", {}).has(str(s.get("magnitude", ""))):
			out.append("C2 spell %s: unknown magnitude '%s'" % [s.get("id"), s.get("magnitude")])
	for u in db.get("combat2/ultimates", {}).get("ultimates", []):
		_ability(out, "ultimate", u, types)
	for p in db.get("combat2/perks", {}).get("perks", []):
		if not EFFECTS.has(str(p.get("effect", {}).get("kind", ""))):
			out.append("C2 perk %s: unknown effect kind '%s'" % [p.get("id"), p.get("effect", {}).get("kind")])
	for g in db.get("combat2/gear", {}).get("gear", []):
		if not SLOTS.has(str(g.get("slot", ""))):
			out.append("C2 gear %s: unknown slot '%s'" % [g.get("id"), g.get("slot")])
		if g.has("effect") and not EFFECTS.has(str(g["effect"].get("kind", ""))):
			out.append("C2 gear %s: unknown effect kind '%s'" % [g.get("id"), g["effect"].get("kind")])
		if g.has("basicType") and not types.has(str(g["basicType"])):
			out.append("C2 gear %s: unknown basic type '%s'" % [g.get("id"), g["basicType"]])
		if g.has("weaponMove") and Kits.move(db, str(g["weaponMove"])).is_empty():
			out.append("C2 gear %s: unknown weapon move '%s'" % [g.get("id"), g["weaponMove"]])
	for ch in db.get("combat2/characters", {}).get("characters", []):
		var cid := str(ch.get("id", "?"))
		for mid in ch.get("pool", []):
			if Kits.move(db, str(mid)).is_empty():
				out.append("C2 character %s: unknown move '%s'" % [cid, mid])
		for sid in ch.get("spells", []):
			if Kits.spell(db, str(sid)).is_empty():
				out.append("C2 character %s: unknown spell '%s'" % [cid, sid])
		for uid in ch.get("ultimates", []):
			if Kits.ultimate(db, str(uid)).is_empty():
				out.append("C2 character %s: unknown ultimate '%s'" % [cid, uid])
		var lo: Dictionary = ch.get("loadouts", {})
		for lvl in lo:
			for msg in loadout_problems(db, rules, cid, int(lvl), lo[lvl]):
				out.append("C2 character %s level %s: %s" % [cid, lvl, msg])
	for e in db.get("combat2/enemies", {}).get("enemies", []):
		for t in e.get("marks", {}):
			if not types.has(str(t)) or not MARKS.has(str(e["marks"][t])):
				out.append("C2 enemy %s: bad marking %s=%s" % [e.get("id"), t, e["marks"][t]])
		for m in e.get("moves", []):
			_ability(out, "enemy move", m, types)
		for ph in e.get("phases", []):
			for sid in ph.get("summon", []):
				if Kits.rec(db, "enemies", "enemies", str(sid)).is_empty():
					out.append("C2 enemy %s: unknown summon '%s'" % [e.get("id"), sid])
	var fight_ids := {}
	for f in db.get("combat2/fights", {}).get("fights", []):
		fight_ids[str(f.get("id"))] = true
		var map: Array = f.get("map", [])
		for row in map:
			if str(row).length() != str(map[0]).length():
				out.append("C2 fight %s: map rows differ in length" % f.get("id"))
				break
		for eid in f.get("enemies", []):
			if Kits.rec(db, "enemies", "enemies", str(eid)).is_empty():
				out.append("C2 fight %s: unknown enemy '%s'" % [f.get("id"), eid])
		for pid in f.get("party", []):
			if Kits.character(db, str(pid)).is_empty():
				out.append("C2 fight %s: unknown character '%s'" % [f.get("id"), pid])
	for n in db.get("combat2/fights", {}).get("nights", []):
		for step in n.get("steps", []):
			if str(step) != "rest" and not fight_ids.has(str(step)):
				out.append("C2 night %s: unknown step '%s'" % [n.get("id"), step])
	return out


static func _ability(out: Array, what: String, a: Dictionary, types: Array) -> void:
	var id := str(a.get("id", "?"))
	if not SHAPES.has(str(a.get("shape", ""))):
		out.append("C2 %s %s: unknown shape '%s'" % [what, id, a.get("shape")])
	if a.has("type") and str(a["type"]) != "" and not types.has(str(a["type"])):
		out.append("C2 %s %s: unknown type '%s'" % [what, id, a["type"]])
	if a.has("target") and not TARGETS.has(str(a["target"])):
		out.append("C2 %s %s: unknown target '%s'" % [what, id, a["target"]])


## What's wrong with a loadout for this character at this level ([] when it's fine).
static func loadout_problems(db: Dictionary, rules: C2Rules, char_id: String, level: int, lo: Dictionary) -> Array:
	var out: Array = []
	var ch := Kits.character(db, char_id)
	var sl := Kits.slots(rules, level)
	var moves: Array = lo.get("moves", [])
	if moves.size() > int(sl["moves"]):
		out.append("%d moves for %d slots" % [moves.size(), int(sl["moves"])])
	var has_basic := false
	for mid in moves:
		if not (ch.get("pool", []) as Array).has(mid):
			out.append("move '%s' isn't in the pool" % mid)
		if bool(Kits.move(db, str(mid)).get("basic", false)):
			has_basic = true
	if not has_basic:
		out.append("no basic attack equipped")
	var spells: Array = lo.get("spells", [])
	if spells.size() > int(sl["spells"]):
		out.append("%d spells for %d slots" % [spells.size(), int(sl["spells"])])
	for sid in spells:
		if not (ch.get("spells", []) as Array).has(sid):
			out.append("spell '%s' isn't known" % sid)
	var perks: Array = lo.get("perks", [])
	if perks.size() > int(sl["perks"]):
		out.append("%d perks for %d slots" % [perks.size(), int(sl["perks"])])
	for pid in perks:
		var p := Kits.perk(db, str(pid))
		if p.is_empty():
			out.append("unknown perk '%s'" % pid)
		elif str(p.get("class", "any")) != "any" and str(p["class"]) != str(ch.get("class", "")):
			out.append("perk '%s' is for %s" % [pid, p["class"]])
	if str(lo.get("ultimate", "")) != "" and not (ch.get("ultimates", []) as Array).has(lo["ultimate"]):
		out.append("ultimate '%s' isn't known" % lo["ultimate"])
	var gear: Dictionary = lo.get("gear", {})
	for slot in gear:
		var gid := str(gear[slot])
		if gid == "":
			continue
		var g := Kits.gear(db, gid)
		if g.is_empty():
			out.append("unknown gear '%s'" % gid)
		elif str(g.get("slot", "")) != str(slot).rstrip("12"):
			out.append("gear '%s' doesn't go in %s" % [gid, slot])
	return out

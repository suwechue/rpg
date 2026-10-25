## Bonds beyond talking (DESIGN.md Section 11): gifts, hanging out,
## recruitment (Friend tier plus staggered Gates) and the party roster.
class_name Bonds
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Char := preload("res://src/core/character.gd")
const DT := preload("res://src/core/data_tables.gd")
const Dlg := preload("res://src/core/social/dialogue_check.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("social", {})


## Give an item. Liked tags: +5 per match up to +15; a disliked tag: -5;
## otherwise a polite +2. Returns { "reaction": "like"|"dislike"|"neutral", "lines" }.
static func give_gift(db: Dictionary, run: Dictionary, id: String, item_id: String) -> Dictionary:
	if int(run.get("inventory", {}).get(item_id, 0)) <= 0:
		return { "reaction": "none", "lines": [Str.t(db, "bonds.you_don_t_have_that")] }
	var it := DT.record(db, "items", item_id)
	var gifts: Dictionary = Dlg.npc(db, id).get("gifts", {})
	var tags: Array = it.get("tags", [])
	var likes := 0
	var dislike := false
	for t in tags:
		if Array(gifts.get("likes", [])).has(t):
			likes += 1
		if Array(gifts.get("dislikes", [])).has(t):
			dislike = true
	var c := cfg(db)
	var delta := float(c.get("giftNeutral", 2))
	var reaction := "neutral"
	if dislike:
		delta = float(c.get("giftDislike", -5))
		reaction = "dislike"
	elif likes > 0:
		delta = minf(float(c.get("giftLikeMax", 15)), float(c.get("giftLikePerTag", 5)) * float(likes) + 5.0)
		reaction = "like"
	Fx.add_item(run, item_id, -1)
	var lines: Array = []
	Fx.change_bond(db, run, id, delta, lines)
	var st := Fx.npc_state(run, id)
	st["gifts"] = int(st.get("gifts", 0)) + 1
	var text := str(gifts.get(reaction + "Text", c.get("giftText", {}).get(reaction, "")))
	if text != "":
		lines.push_front(text)
	return { "reaction": reaction, "lines": lines }


## Hang out (2 AP): Acquaintance or better. Bond +6..+12 by Sample.
static func can_hang_out(db: Dictionary, run: Dictionary, id: String) -> bool:
	return Dlg.tier_rank(db, Dlg.bond_tier(db, RM.bond(run, id))) >= Dlg.tier_rank(db, "Acquaintance") \
		and not bool(Dlg.npc(db, id).get("noHangout", false))


static func hang_out(db: Dictionary, run: Dictionary, id: String, rng: RandomNumberGenerator) -> Array:
	var c := cfg(db)
	var lines: Array = []
	var hang: Array = Dlg.npc(db, id).get("hangouts", [])
	if not hang.is_empty():
		lines.append(str(hang[rng.randi_range(0, hang.size() - 1)]))
	Fx.change_bond(db, run, id, float(rng.randi_range(int(c.get("hangoutMin", 6)), int(c.get("hangoutMax", 12)))), lines)
	return lines


## Why this person can't join yet, or "" if a recruitment ask would work.
## Friend tier (41+) or their own minBond, the week they become available,
## flags and counters they need, and the party roster limit.
static func recruit_block(db: Dictionary, run: Dictionary, id: String, week: int) -> String:
	var rec := Dlg.npc(db, id)
	if not bool(rec.get("recruitable", false)):
		return Str.t(db, "bonds.not_a_party_member")
	if not RM.character(run, id).is_empty():
		return Str.t(db, "bonds.already_in_your_roster")
	var need := float(rec.get("recruitBond", cfg(db).get("recruitBond", 41)))
	if RM.bond(run, id) < need:
		return Str.t(db, "bonds.needs_bond") % roundi(need)
	if week < int(rec.get("recruitWeek", 1)):
		return Str.t(db, "bonds.they_re_not_ready_yet") % int(rec.get("recruitWeek", 1))
	if rec.has("recruitFlag") and not RM.flag(run, str(rec["recruitFlag"])):
		return str(rec.get("recruitHint", Str.t(db, "bonds.something_has_to_happen_first")))
	for c in rec.get("recruitCounter", {}):
		if int(run.get("shifts", {}).get(c, 0)) < int(rec["recruitCounter"][c]):
			return str(rec.get("recruitHint", Str.t(db, "bonds.spend_more_time_where_they")))
	return ""


## Add a recruit to the roster as a full character from their data.
static func recruit(db: Dictionary, run: Dictionary, id: String, rng: RandomNumberGenerator) -> Dictionary:
	var rec := Dlg.npc(db, id)
	var combat: Dictionary = rec.get("combat", {})
	var ch := Char.create(db, str(combat.get("class", "fighter")), rng, {
		"id": id, "name": str(rec.get("name", id)), "stats": combat.get("stats", {}),
		"knownVectors": combat.get("vectors", []), "traits": rec.get("traits", []) })
	ch["sprite"] = str(rec.get("sprite", ""))
	ch["portrait"] = str(rec.get("portrait", ""))
	ch["disposition"] = rec.get("disposition", {})
	ch["advancedClass"] = str(combat.get("advanced", ""))
	ch["starterDeck"] = ch["deck"].duplicate()
	var lvl_target := maxi(1, int(run["player"].get("level", 1)) - 1)
	var lv := preload("res://src/core/progression/leveling.gd")
	while int(ch["level"]) < lvl_target:
		lv.add_xp(db, ch, lv.xp_to_next(db, int(ch["level"])), rng)
	lv.auto_perks(db, ch)
	Char.full_restore(db, ch)
	run["roster"].append(ch)
	RM.set_flag(run, "recruited_" + id)
	if run["party_ids"].size() < int(cfg(db).get("maxParty", 3)):
		run["party_ids"].append(id)
	return ch


## Pick tonight's party: up to 3 roster ids.
static func set_party(db: Dictionary, run: Dictionary, ids: Array) -> String:
	if ids.size() > int(cfg(db).get("maxParty", 3)):
		return Str.t(db, "bonds.up_to_people_can_come") % int(cfg(db).get("maxParty", 3))
	for id in ids:
		if RM.character(run, str(id)).is_empty():
			return Str.t(db, "bonds.isn_t_in_your_roster") % id
	run["party_ids"] = ids.duplicate()
	return ""


## Bonds between party members, for the adjacency bonus in combat
## (the player's Bond with each member; members trust each other as much).
static func party_bonds(run: Dictionary, member_ids: Array) -> Dictionary:
	var out := {}
	for id in member_ids:
		out[str(id)] = RM.bond(run, str(id))
	return out


## Fighting together: +2 Bond with each member who survived the fight.
static func fought_together(db: Dictionary, run: Dictionary, survivors: Array) -> void:
	for id in survivors:
		if str(id) != "player":
			Fx.change_bond(db, run, str(id), float(cfg(db).get("fightBond", 2)))

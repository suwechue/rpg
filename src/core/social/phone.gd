## The phone (ROADMAP M18, data/phone.json): texts from friends at Night
## (some invite you to hang out tomorrow after school), reactions to story
## flags, a school feed of rumors, contacts with Bond and whereabouts, and the
## school calendar. Texts live in run["texts"], invites in run["invites"].
extends RefCounted

const RM := preload("res://src/core/run/run_model.gd")
const Fx := preload("res://src/core/run/effects.gd")
const Sched := preload("res://src/core/town/schedule.gd")
const Crowd := preload("res://src/core/town/crowd.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("phone", {})


static func _send(run: Dictionary, from: String, text: String, day_count: int, invite: bool = false) -> void:
	var t: Array = run.get("texts", [])
	t.append({ "from": from, "text": text, "day": day_count, "invite": invite })
	run["texts"] = t


## Tonight's texts: friends by Bond (strongest first), maybe an invite, then
## any reactions to flags set since last time. Returns the new texts.
static func night_texts(db: Dictionary, run: Dictionary, day_count: int, rng: RandomNumberGenerator) -> Array:
	var c := cfg(db)
	var before: int = run.get("texts", []).size()
	var friends: Array = []
	for id in run.get("bonds", {}):
		if RM.bond(run, str(id)) >= float(c.get("textMinBond", 11)) and not db.get("npcs/" + str(id), {}).is_empty():
			friends.append(str(id))
	friends.sort_custom(func(a: String, b: String) -> bool: return RM.bond(run, a) > RM.bond(run, b))
	var sent := 0
	for id in friends:
		if sent >= int(c.get("maxTexts", 3)):
			break
		if rng.randf() >= float(c.get("textChance", 0.6)):
			continue
		var pool: Array = c.get("texts", {}).get(id, c.get("texts", {}).get("default", []))
		if RM.bond(run, id) >= float(c.get("inviteMinBond", 41)) and rng.randf() < float(c.get("inviteChance", 0.35)):
			_send(run, id, str(c.get("invite", "")).replace("{place}", ""), day_count, true)
		elif not pool.is_empty():
			_send(run, id, str(pool[rng.randi_range(0, pool.size() - 1)]), day_count)
		sent += 1
	for r in c.get("reactions", []):
		var key := "texted_" + str(r.get("flag", ""))
		if RM.flag(run, str(r.get("flag", ""))) and not RM.flag(run, key):
			RM.set_flag(run, key)
			_send(run, str(r.get("from", "")), str(r.get("text", "")), day_count)
	return run.get("texts", []).slice(before)


## Accept an invite: the friend expects you tomorrow after school.
static func accept_invite(run: Dictionary, from: String, day_count: int) -> void:
	var inv: Dictionary = run.get("invites", {})
	inv[from] = day_count + 1
	run["invites"] = inv


## Whoever you planned to see today ("" if nobody).
static func invite_today(run: Dictionary, day_count: int) -> String:
	for id in run.get("invites", {}):
		if int(run["invites"][id]) == day_count:
			return str(id)
	return ""


static func clear_invite(run: Dictionary, id: String) -> void:
	run.get("invites", {}).erase(id)


## The feed: a few rumors about the week plus a school post.
static func feed(db: Dictionary, run: Dictionary, week: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in 2:
		out.append(Crowd.rumor(db, run, week, rng))
	var posts: Array = cfg(db).get("feed", [])
	if not posts.is_empty():
		out.append(str(posts[rng.randi_range(0, posts.size() - 1)]))
	return out


## Contacts: everyone met, with their Bond tier and where they are now.
static func contacts(db: Dictionary, run: Dictionary, day: String, part: String, day_count: int) -> Array:
	var out: Array = []
	for id in run.get("npcs", {}):
		if not bool(run["npcs"][id].get("met", false)):
			continue
		var loc := Sched.location_of(db, run, str(id), day, part, day_count)
		var loc_name := ""
		for l in db.get("town/locations", {}).get("locations", []):
			if str(l.get("id", "")) == loc:
				loc_name = str(l.get("name", loc))
		out.append({ "id": str(id), "name": str(db.get("npcs/" + str(id), {}).get("name", id)), "tier": Fx.tier_name(db, RM.bond(run, str(id))), "where": loc_name })
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return out


## The school calendar's set pieces ("Week 3, Monday: Club fair").
static func calendar(db: Dictionary) -> Array:
	var out: Array = []
	for s in db.get("story/school_calendar", {}).get("stories", []):
		if str(s.get("calendar", "")) != "":
			out.append(str(s["calendar"]))
	return out

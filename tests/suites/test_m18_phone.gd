## M18: the phone (texts, invites, feed, contacts, calendar), friendship
## scenes at Bond tiers, and the mystery board's deductions.
extends "res://tests/suite.gd"

const Phone := preload("res://src/core/social/phone.gd")
const Mystery := preload("res://src/core/story/mystery.gd")
const Fx := preload("res://src/core/run/effects.gd")
const CS := preload("res://src/core/story/cutscenes.gd")
const RM := preload("res://src/core/run/run_model.gd")
const StoryRules := preload("res://src/core/story/story.gd")


func run_() -> Dictionary:
	return RM.new_run(db(), 5, "mage", seeded(5))


func test_texts_and_invites() -> void:
	var run := run_()
	var first := Phone.night_texts(db(), run, 3, seeded(1))
	check(first.all(func(t: Dictionary) -> bool: return RM.bond(run, str(t["from"])) >= 11.0), "only people with Bond text you")
	run["bonds"]["theo"] = 60.0
	run["bonds"]["dex"] = 30.0
	var got: Array = []
	for d in range(3, 15):
		got.append_array(Phone.night_texts(db(), run, d, seeded(d)))
	check(not got.is_empty(), "friends text at night")
	check(got.any(func(t: Dictionary) -> bool: return bool(t["invite"])), "a Friend-tier Bond sometimes invites you")
	Phone.accept_invite(run, "theo", 7)
	check(Phone.invite_today(run, 8) == "theo" and Phone.invite_today(run, 7) == "", "the plan is for tomorrow")
	RM.set_flag(run, "forge_relit")
	var react := Phone.night_texts(db(), run, 20, seeded(20))
	check(react.any(func(t: Dictionary) -> bool: return t["from"] == "jake"), "reactions arrive when their flag is set")
	check(not Phone.night_texts(db(), run, 21, seeded(21)).any(func(t: Dictionary) -> bool: return str(t["text"]).contains("FORGE")), "only once")


func test_feed_contacts_calendar() -> void:
	var run := run_()
	check(Phone.feed(db(), run, 1, seeded(1)).size() == 3, "the feed has rumors and a post")
	run["npcs"]["gary"]["met"] = true
	check(Phone.contacts(db(), run, "mon", "after_school", 0).any(func(c: Dictionary) -> bool: return c["id"] == "gary"), "contacts list people you've met")
	check(Phone.calendar(db()).size() >= 5, "the calendar lists the set pieces")


func test_friendship_scenes() -> void:
	for c in CS.all(db()):
		if str(c["id"]).begins_with("friend_"):
			check(CS.problems(db(), c).is_empty(), "%s is valid" % c["id"])
	for npc in ["kelly", "theo", "mara", "dex", "priya"]:
		for tier in ["acquaintance", "friend", "close", "unbreakable"]:
			check(not CS.find(db(), "friend_%s_%s" % [npc, tier]).is_empty(), "%s has a %s scene" % [npc, tier])
	for npc in ["baxter", "diane", "jake", "jon", "kris", "mel", "penny", "phase", "sam"]:
		check(not CS.find(db(), "friend_%s_friend" % npc).is_empty() and not CS.find(db(), "friend_%s_close" % npc).is_empty(), "%s has Friend and Close scenes" % npc)
	var run := run_()
	Fx.change_bond(db(), run, "theo", 45.0)
	check(run["pendingFriendScenes"].has("friend_theo_friend"), "reaching Friend queues the scene")
	Fx.change_bond(db(), run, "theo", 1.0)
	check(run["pendingFriendScenes"].count("friend_theo_friend") == 1, "only once")


func test_mystery_board() -> void:
	var run := run_()
	var lines := Fx.apply(db(), run, { "clue": "mr_b_window" }, seeded(1))
	check(run["clues"].has("mr_b_window") and not lines.is_empty(), "events give clues")
	check(Mystery.connect_clues(db(), run, "mr_b_window", "transfer_signatures").is_empty(), "you need both clues")
	Mystery.add_clue(run, "transfer_signatures")
	check(Mystery.connect_clues(db(), run, "mr_b_window", "forge_went_cold").is_empty(), "unrelated clues don't link")
	var d := Mystery.connect_clues(db(), run, "transfer_signatures", "mr_b_window")
	check(str(d.get("id", "")) == "mr_b_selects" and RM.flag(run, "deduction_mr_b_selects"), "a matching pair is a deduction")
	# The deduction opens a new choice in the week 3 cover-up.
	var ev: Dictionary = StoryRules.find(db(), "s3_coverup")["steps"][0]["event"]
	var extra: Array = ev["choices"].filter(func(c: Dictionary) -> bool: return c.get("cond", {}).has("flag"))
	check(not extra.is_empty() and Fx.conditions_met(db(), run, extra[0]["cond"], {}), "the deduction unlocks a story choice")
	check(not Fx.conditions_met(db(), run_(), extra[0]["cond"], {}), "which stays locked without it")

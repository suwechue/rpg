## Combat Lab Part 5: Guard, the Cantrip and the Vector Wheel are gone from the whole game.
extends "res://tests/suite.gd"

const Tutorial := preload("res://src/core/story/tutorial.gd")
const CardRules := preload("res://src/core/card.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const RM := preload("res://src/core/run/run_model.gd")


func _files(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if str(f).ends_with(".gd") or str(f).ends_with(".json"):
			out.append(dir + "/" + str(f))
	for d in DirAccess.get_directories_at(dir):
		_files(dir + "/" + str(d), out)


func test_no_references_left() -> void:
	var words := RegEx.create_from_string("(?i)\\bguard\\b|guard_|_guard\\b|guardshield|cantrip|\\bwheels?\\b|improvis")
	var files: Array = []
	_files("res://src", files)
	_files("res://data", files)
	check(files.size() > 100, "scanned the code and data (%d files)" % files.size())
	var found := 0
	for p in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(str(p)).split("\n")
		for i in lines.size():
			var line := lines[i]
			# Pack file names can't change (packs are never edited).
			if line.contains("assets/packs/"):
				continue
			var m := words.search(line)
			if m != null:
				found += 1
				check(false, "%s:%d still says '%s'" % [p, i + 1, m.get_string()])
	check(found == 0, "no references left")


func test_every_class_can_deal_damage_for_no_mp() -> void:
	for c in db()["classes"]["classes"]:
		var run := RM.new_run(db(), 3, "fighter", seeded(3))
		var ch: Dictionary = run["player"]
		ch["class"] = str(c["id"])
		var foe: Dictionary = DT.index_under(db(), "enemies/", "enemies")["bleacher_creeper"].duplicate(true)
		var st: Object = StateScript.new(db(), seeded(5), { "layout": { "map": ["PE......."] }, "party": [{ "char": ch }], "enemies": [foe], "partyFirst": true })
		var me: Object = st.unit_by_id("player")
		me.mp = 0
		var e: Object = st.units.filter(func(u: Object) -> bool: return u.team == "enemy")[0]
		var hp: int = e.hp
		check(st.strike(me, e.cell) and e.hp < hp, "%s: Strike costs no MP" % c["id"])
	for id in ["mage", "healer", "bard"]:
		var has_ranged := false
		for c in db()["classes"]["classes"]:
			if str(c["id"]) == id:
				for e in c["starterDeck"]:
					if str(e.get("basic", "")) == "card_zap":
						has_ranged = true
		check(has_ranged, "%s starts with a 0 MP card at range" % id)


func test_reworked_things_work() -> void:
	var zap := CardRules.resolve(db(), "card_zap")
	check(int(zap["cost"]) == 0, "Zap costs no MP")
	var run := RM.new_run(db(), 3, "mage", seeded(3))
	var foe: Dictionary = DT.index_under(db(), "enemies/", "enemies")["bleacher_creeper"].duplicate(true)
	foe["hp"] = 500
	var st: Object = StateScript.new(db(), seeded(5), { "layout": { "map": ["P...E...."] }, "party": [{ "char": run["player"] }], "enemies": [foe], "partyFirst": true })
	var me: Object = st.unit_by_id("player")
	var e: Object = st.units.filter(func(u: Object) -> bool: return u.team == "enemy")[0]
	me.deck.hand = ["card_zap", "card_wild_cast"]
	me.mp = 9
	var hp: int = e.hp
	check(st.play_card(me, 0, e.cell) and e.hp < hp, "Zap hits at range")
	hp = e.hp
	check(st.play_card(me, 0, e.cell) and e.hp < hp, "Wild Cast throws a two-Vector spell")
	me.mods["combat"] = { "quickZero": true }
	check(st.is_quick_card(me, zap), "Living Equation: a 0 MP card is a Quick")
	me.mods["combat"] = {}
	check(not st.is_quick_card(me, zap), "not without it")
	var hybrid := CardRules.make_spell(db(), { "heat": 1, "cold": 1 }, "bolt", "major")
	check(st._threshold_bonus(me, hybrid) == 0, "no bonus for a Mage")
	me.perk = "unstable"
	check(st._threshold_bonus(me, hybrid) == 3, "Unstable: two-Vector spells are steadier")
	var heavy: Dictionary = RM.new_run(db(), 3, "fighter", seeded(3))["player"]
	heavy["gearStats"] = { "collisionResist": 1 }
	var st2: Object = StateScript.new(db(), seeded(5), { "layout": { "map": ["PE......."] }, "party": [{ "char": heavy }], "enemies": [foe.duplicate(true)], "partyFirst": true })
	var h: Object = st2.unit_by_id("player")
	var h0: int = h.hp
	st2._damage(h, 4, null, "force", "collision")
	check(h0 - h.hp == 3, "heavy armor takes less from collisions")


func test_upside_touched_gets_wild_cast() -> void:
	const ClassChange := preload("res://src/core/progression/class_change.gd")
	var src := FileAccess.get_file_as_string("res://src/core/progression/class_change.gd")
	check(src.contains("grantCards"), "class change grants cards")
	for c in db()["classes"]["classes"]:
		if str(c["id"]) == "upside_touched":
			check(c.get("grantCards", []).has("card_wild_cast"), "Upside-Touched learns Wild Cast")
			check(str(c["perk"]["text"]).contains("Two-Vector"), "its perk is about two-Vector spells")


func test_tutorial_teaches_the_new_things() -> void:
	var taught := ""
	for r in Tutorial.rooms(db()):
		taught += str(r.get("teaches", "")) + " "
		check(not r.get("ui", {}).has("wheel"), "room %d has no Wheel" % int(r["id"]))
		for s in r.get("lesson", []):
			check(Tutorial.WAITS.has(str(s.get("wait", "next"))), "room %d: wait %s" % [int(r["id"]), s.get("wait", "")])
	for word in ["Strike", "telegraph", "pit", "discard"]:
		check(taught.containsn(word), "the tutorial teaches %s" % word)

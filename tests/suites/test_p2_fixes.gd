## P2 Parts 1 and 2: Strike and Guard as Quicks after both Actions, card owners,
## and the effects every screen shows.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const Arena := preload("res://src/core/arena/arena.gd")
const ArenaParty := preload("res://src/core/arena/arena_party.gd")
const Effects := preload("res://src/core/effects.gd")
const CardRules := preload("res://src/core/card.gd")


func fight() -> StateScript:
	var ch := Char.create(db(), "fighter", seeded(1), { "isPlayer": true })
	var e: Dictionary = DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)
	var st := StateScript.new(db(), seeded(5), { "layout": { "map": ["P.E......", "........."] }, "party": [{ "char": ch }], "enemies": [e], "partyFirst": true })
	st.units[1].hp = 999
	return st


func test_quicks_after_actions() -> void:
	var st := fight()
	var p = st.units[0]
	check(st.move(p, Vector2i(1, 0)) and st.move(p, Vector2i(1, 1)) and p.actions_left == 0, "two Actions spent (two moves)")
	st.units[1].cell = Vector2i(2, 1)
	check(st.quick_block(p) == "" and st.strike(p, Vector2i(2, 1)) and p.actions_left == 0, "Strike after both Actions works and costs no Action")
	var st2 := fight()
	var q = st2.units[0]
	st2.units[1].cell = Vector2i(1, 0)
	check(st2.strike(q, Vector2i(1, 0)) and q.actions_left == 2, "Strike first: both Actions left")
	check(not st2.guard(q), "Strike then Guard: one Quick per turn")
	var st3 := fight()
	var g = st3.units[0]
	st3.move(g, Vector2i(1, 0))
	st3.move(g, Vector2i(1, 1))
	check(st3.guard(g) and g.actions_left == 0, "Guard after both Actions works")
	check(st3.is_quick_now(g, { "builtin": true }), "labels say QUICK under two Actions")
	st3.turn_mode = "move_or_act"
	check(not st3.is_quick_now(g, { "builtin": true }), "labels say ACTION under another turn rule")


func test_card_owners() -> void:
	var run := ArenaParty.preset_run(db(), 3, "mage", 4, 3, seeded(3))
	var arena := Arena.new_arena(3, false)
	var heat := CardRules.spell_id(db(), { str(run["player"]["knownVectors"][0]): 1.0 }, "bolt", "standard")
	var owners := Arena.eligible_owners(db(), run, CardRules.resolve(db(), heat))
	var ok: Array = owners.filter(func(o: Dictionary) -> bool: return bool(o["ok"]))
	var bad: Array = owners.filter(func(o: Dictionary) -> bool: return not bool(o["ok"]))
	check(not ok.is_empty() and owners.size() >= 2, "eligible owners are listed (%d of %d)" % [ok.size(), owners.size()])
	if not bad.is_empty():
		check(str(bad[0]["reason"]) != "", "ineligible members say why")
		check(not Arena.pick_card(db(), arena, run, heat, str(bad[0]["id"])), "ineligible members are refused")
	var who := str(ok[0]["id"])
	var before := 0
	for ch in [run["player"]] + run["roster"]:
		if str(ch["id"]) == who:
			before = (ch["deck"] as Array).count(heat)
	check(Arena.pick_card(db(), arena, run, heat, who), "pick for a member")
	for ch in [run["player"]] + run["roster"]:
		if str(ch["id"]) == who:
			check((ch["deck"] as Array).count(heat) == before + 1, "the card lands in the chosen deck")
	check(Arena.undo_pick(arena, run), "undo until the next wave")
	var decks_before := JSON.stringify([run["player"]["deck"]] + run["roster"].map(func(c: Dictionary) -> Array: return c["deck"]))
	check(Arena.pick_card(db(), arena, run, heat, ""), "collection only")
	check(JSON.stringify([run["player"]["deck"]] + run["roster"].map(func(c: Dictionary) -> Array: return c["deck"])) == decks_before, "collection only touches no deck")
	check(Arena.auto_owner(db(), run, CardRules.resolve(db(), heat)) == Arena.auto_owner(db(), run, CardRules.resolve(db(), heat)), "autoplay's owner is deterministic")


func test_effects_gather() -> void:
	var run := ArenaParty.preset_run(db(), 3, "mage", 2, 3, seeded(3))
	run["arena"] = Arena.new_arena(3, false)
	var muts: Array = db()["arena/mutators"]["mutators"]
	run["arena"]["mutators"] = [muts[0]]
	run["arena"]["wave"] = 7
	var all := Effects.gather(db(), run, { "difficulty": "hard", "easyMinigames": true, "turnOverride": "move_or_act", "dataTurnMode": "two_actions" })
	var kinds := {}
	for e in all:
		kinds[str(e["id"])] = e
	check(kinds.has(str(muts[0]["id"])) and str(kinds[str(muts[0]["id"])]["duration"]).contains("3"), "the mutator, with waves to the checkpoint")
	check(kinds.has("difficulty") and kinds.has("easy_minigames") and kinds.has("turn_override"), "run modifiers and the F1 override")
	check(all.any(func(e: Dictionary) -> bool: return str(e["kind"]) == "perk"), "party perks are listed")
	var st := fight()
	st.mutators = [{ "name": "Heat wave", "effects": { "vectorDamage": { "heat": 1.5 } } }]
	check(st.mutator_note({ "heat": 1.0 }).contains("+50%"), "mutator damage shows in the hover breakdown")


func test_every_mutator_and_perk_has_text_and_icon() -> void:
	var assets: Dictionary = db()["assets/manifest"]
	assets = assets.get("assets", assets)
	for m in db()["arena/mutators"]["mutators"]:
		check(str(m.get("text", "")) != "", "mutator %s has a description" % m["id"])
		check(assets.has(Effects.icon_for(db(), "mutator", str(m["id"]), str(m.get("icon", "")))), "mutator %s has an icon" % m["id"])
	for p in DT.records_under(db(), "perks", "perks"):
		check(str(p.get("text", "")) != "", "perk %s has a description" % p["id"])
		check(assets.has(Effects.icon_for(db(), "perk", str(p["id"]))), "perk %s has an icon" % p["id"])

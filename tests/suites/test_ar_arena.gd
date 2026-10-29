## AR Part 5: the Endless Arena's waves, layouts and hazards, checkpoints,
## mutators and score; the new grid hazards in combat.
extends "res://tests/suite.gd"

const Arena := preload("res://src/core/arena/arena.gd")
const Char := preload("res://src/core/character.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")


func test_waves_from_a_seed() -> void:
	var a := Arena.new_arena(42, false)
	var b := Arena.new_arena(42, false)
	check(JSON.stringify(Arena.setup_for_wave(db(), a, 3)) == JSON.stringify(Arena.setup_for_wave(db(), b, 3)), "same seed, same wave")
	check(JSON.stringify(Arena.setup_for_wave(db(), a, 3)) != JSON.stringify(Arena.setup_for_wave(db(), Arena.new_arena(43, false), 3)), "different seed, different wave")
	var w1: int = Arena.wave_enemies(db(), a, 1)["enemies"].size()
	var w20: int = Arena.wave_enemies(db(), a, 19)["enemies"].size()
	check(w1 >= 3 and w20 >= 8 and w20 > w1, "waves grow from about 3 to 8-10 enemies (%d -> %d)" % [w1, w20])
	check(Arena.is_boss(db(), 5) and Arena.is_boss(db(), 10) and Arena.is_elite(db(), 4) and not Arena.is_elite(db(), 20), "a boss every 5th wave (user request), elites every 4th")
	var boss := Arena.wave_enemies(db(), a, 20)
	check(bool(boss["boss"]) and boss["enemies"][0]["affixes"].size() == 2, "bosses come back remixed with affixes")
	var elite := Arena.wave_enemies(db(), a, 5)
	check(elite["enemies"][0].has("affixes"), "elite waves have affixed elites")
	check(Arena.week_for_wave(db(), 1) == 1 and Arena.week_for_wave(db(), 18) == 5, "later waves draw from later weeks")


func test_layouts_rotate_hazards() -> void:
	var a := Arena.new_arena(7, false)
	var seen := {}
	for wave in range(1, 46):
		var lay := Arena.layout_for(db(), a, wave)
		seen[lay["hazard"]] = true
		var grid := GridScript.new(lay)
		check(not grid.party_spawns.is_empty() and not grid.enemy_spawns.is_empty(), "wave %d layout has spawns" % wave)
	check(seen.size() >= 5, "nine 5-wave blocks rotate through the themes' hazard sets (%d seen)" % seen.size())


func test_wave_rewards_and_score() -> void:
	var a := Arena.new_arena(1, true)
	a["wave"] = 5
	var lines := Arena.wave_won(db(), a, { "rounds": 3, "damageTaken": 0, "multiVector": 1 })
	check(int(a["score"]) == 10 + 5 + 3 + 2, "score: wave, no damage, fast clear, a multi-Vector cast (%d)" % int(a["score"]))
	check(lines.size() >= 3, "the result says why")
	check(int(a["pending"]["xp"]) > 0 and int(a["pending"]["shards"]) == 1 and a["pending"]["cards"].size() == 1, "rewards wait in pending")
	var banked := Arena.checkpoint(db(), a)
	check(int(banked["xp"]) > 0 and int(a["pending"]["xp"]) == 0 and int(a["banked"]["xp"]) > 0, "a checkpoint banks the rewards")
	check(int(a["ap"]) == 3 and a["offered"].size() == 3, "3 Arena AP and 3 mutators to pick from")


func test_checkpoint_spending() -> void:
	var a := Arena.new_arena(1, false)
	a["wave"] = 5
	Arena.checkpoint(db(), a)
	check(Arena.spend(db(), a, "rest") and int(a["ap"]) == 1, "rest costs 2")
	check(not Arena.spend(db(), a, "craftCard"), "can't afford a craft with 1 AP")
	check(Arena.spend(db(), a, "swapCard") and int(a["ap"]) == 0, "swap a card for 1")
	a["wave"] = 10
	Arena.checkpoint(db(), a)
	check(int(a["ap"]) == 3, "unspent AP carries over (0 + 3)")
	var first := str(a["offered"][0]["id"])
	Arena.offer_mutators(db(), a, 1)
	check(a["offered"].size() == 3, "reroll offers three again")
	check(Arena.choose_mutator(a, str(a["offered"][0]["id"])) and a["mutators"].size() == 1, "pick one")
	check(first != "" and int(a.get("mutatorsTaken", 0)) == 1, "mutators taken are counted for the score table")
	var party: Array = [Char.create(db(), "mage", seeded(1))]
	party[0]["hp"] = 1
	party[0]["mp"] = 0
	Arena.rest(db(), party)
	check(int(party[0]["hp"]) > 1 and int(party[0]["mp"]) > 0, "rest heals half HP and MP")
	party[0]["mp"] = 0
	Arena.breather(db(), party)
	check(int(party[0]["mp"]) == 3, "between waves: a little MP, no HP")


func test_mutators_in_combat() -> void:
	var mut: Array = db()["arena/mutators"]["mutators"]
	var cold: Dictionary = mut.filter(func(m: Dictionary) -> bool: return m["id"] == "cold_snap")[0]
	var early: Dictionary = mut.filter(func(m: Dictionary) -> bool: return m["id"] == "early_warning")[0]
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var p := Char.create(db(), "mage", seeded(1), { "isPlayer": true })
	var plain := StateScript.new(db(), seeded(1), { "layout": { "map": ["P...E...."] }, "party": [{ "char": p }], "enemies": [idx["hall_rusher"].duplicate(true)] })
	var muted := StateScript.new(db(), seeded(1), { "layout": { "map": ["P...E...."] }, "party": [{ "char": p.duplicate(true) }], "enemies": [idx["hall_rusher"].duplicate(true)], "mutators": [cold, early] })
	var e0 = plain.units[1]
	var e1 = muted.units[1]
	check(e1.max_hp > e0.max_hp, "Early warning: +30% enemy HP")
	var spec := { "vectors": { "cold": 1.0 }, "power": 10.0, "mult": 1.0, "ranged": true, "form": plain.form_rec("bolt"), "heal": false, "kind": "spell" }
	check(muted._expected_hit(muted.units[0], e1, spec) > plain._expected_hit(plain.units[0], e0, spec) * 1.4, "Cold is stronger: +50% Cold damage")
	var plan := AI.plan_intent(muted, e1)
	if str(plan.get("kind", "")) == "attack" or str(plan.get("kind", "")) == "special":
		check(int(plan.get("charge", 0)) >= 1, "Early warning: attacks telegraph a turn earlier")


func test_score_table() -> void:
	var scores := {}
	var a := Arena.new_arena(1, false)
	a["score"] = 50
	a["cleared"] = 4
	check(Arena.record_score(scores, a, 4), "first score is a best")
	a["score"] = 40
	check(not Arena.record_score(scores, a, 4), "a lower one isn't")
	check(scores.has("party4_mut0"), "kept per party size and mutator count")


func _fight(map: Array, enemies: Array) -> StateScript:
	var p := Char.create(db(), "mage", seeded(1), { "isPlayer": true, "stats": { "str": 8, "dex": 40, "con": 10, "int": 8, "per": 40, "wil": 6, "cha": 4 } })
	return StateScript.new(db(), seeded(3), { "layout": { "map": map }, "party": [{ "char": p }], "enemies": enemies, "turnMode": "move_and_act" })


func test_pits() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var st := _fight(["PEp......", "........."], [idx["hall_rusher"].duplicate(true)])
	var e = st.units[1]
	st._push(st.units[0], e, Vector2i(1, 0), 1)
	check(e.dead, "an enemy pushed into a pit is gone")
	var st2 := _fight(["p.P......", "........E"], [idx["hall_rusher"].duplicate(true)])
	var p = st2.units[0]
	var hp: int = p.hp
	st2._push(st2.units[1], p, Vector2i(-1, 0), 2)
	check(p.alive() and p.hp < hp and st2.grid.get_terrain(p.cell) != GridScript.PIT, "a party member falls, takes heavy damage and climbs out")


func test_collapsing_floor() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var st := _fight(["Pk.......", "........E"], [idx["hall_rusher"].duplicate(true)])
	var p = st.units[0]
	st.move(p, Vector2i(2, 0))
	check(st.grid.cracked.has(Vector2i(1, 0)), "stepping on it once cracks it")
	p.move_left = 4
	st.move(p, Vector2i(1, 0))
	check(st.grid.get_terrain(Vector2i(1, 0)) == GridScript.PIT, "the second time it falls")


func test_conveyors() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var st := _fight(["P........", ".RR......", "........E"], [idx["hall_rusher"].duplicate(true)])
	var p = st.units[0]
	p.cell = Vector2i(1, 1)
	st._end_round()
	check(p.cell == Vector2i(2, 1), "a conveyor moves you a tile at the end of the round")


func test_darkness() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var st := _fight(["P...d....", "........."], [idx["hall_rusher"].duplicate(true)])
	var e = st.units[1]
	e.cell = Vector2i(4, 0)
	check(not st.opponents_of(st.units[0]).has(e), "an enemy in darkness can't be targeted")
	var spec := { "vectors": { "light": 1.0 }, "power": 5.0, "mult": 0.0, "ranged": true, "form": st.form_rec("bolt"), "heal": false, "kind": "spell" }
	st._apply_vector_effects(st.units[0], spec, [Vector2i(4, 0)], [])
	check(st.opponents_of(st.units[0]).has(e), "Light reveals it")


func test_toxic_fire_and_traps() -> void:
	var idx := DT.index_under(db(), "enemies/", "enemies")
	var st := _fight(["Ptfg.....", "........E"], [idx["hall_rusher"].duplicate(true)])
	check(st.grid.toxic.has(Vector2i(1, 0)) and st.grid.burning.has(Vector2i(2, 0)), "toxic puddles and fire from the layout")
	var p = st.units[0]
	p.cell = Vector2i(2, 0)
	var hp: int = p.hp
	st._enter_cell(p, Vector2i(3, 0))
	check(p.statuses.has("root") and p.hp < hp, "a glyph trap roots and hurts")


## PT Part 6: a card offer after every wave, perks at checkpoints.
func test_pt_card_offer_and_perks() -> void:
	var arena := Arena.new_arena(5, false)
	var party: Array = [Char.create(db(), "mage", seeded(1), { "knownVectors": ["heat", "force"] })]
	var offer := Arena.card_offer(db(), arena, party, 1)
	check(offer.size() == 3, "three cards are offered (%s)" % str(offer))
	check(offer == Arena.card_offer(db(), arena, party, 1), "offers are seeded")
	var run := { "collection": {} }
	Arena.pick_card(db(), arena, run, str(offer[0]))
	check(int(run["collection"][str(offer[0])]) == 1 and arena["picked"].size() == 1, "a picked card joins the collection and the score list")
	var gain := Arena.skip_offer(db(), arena, run)
	check(int(run["scraps"]["generic"]) == int(gain["generic"]) and int(gain["generic"]) > 0, "skipping gives Scraps")
	var rare_early := 0
	var rare_late := 0
	for w in 20:
		for id in Arena.card_offer(db(), arena, party, w + 1):
			if str(DT.index_under(db(), "cards/", "cards").get(str(id), {}).get("rarity", "")) == "rare":
				rare_early += 1
		for id in Arena.card_offer(db(), arena, party, w + 40):
			if str(DT.index_under(db(), "cards/", "cards").get(str(id), {}).get("rarity", "")) == "rare":
				rare_late += 1
	check(rare_late > rare_early, "rarity improves with the wave (%d -> %d rares)" % [rare_early, rare_late])
	var ch: Dictionary = party[0]
	var perks := Arena.perk_offer(db(), arena, ch)
	if not perks.is_empty():
		Arena.take_perk(arena, ch, str(perks[0]))
		check(ch["perks"].has(str(perks[0])) and arena["perksTaken"].size() == 1, "a checkpoint perk pick")

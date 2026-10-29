## User requests (Oct 28): Strike and Guard cost an Action, place-based story
## events, the open dungeon exit, equipable arena cards, tooltips that wrap,
## relics, consumables, the backpack, the merchant, boss gimmicks and the loop.
extends "res://tests/suite.gd"

const Char := preload("res://src/core/character.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const Arena := preload("res://src/core/arena/arena.gd")
const Night := preload("res://src/core/dungeon/night.gd")
const Inv := preload("res://src/core/items/inventory.gd")
const Crafting := preload("res://src/core/progression/crafting.gd")
const UiThemeScript := preload("res://src/autoload/ui_theme.gd")


func hero(cls: String = "fighter") -> Dictionary:
	return Char.create(db(), cls, seeded(1), { "isPlayer": true, "stats": { "str": 6, "dex": 30, "con": 6, "int": 7, "per": 30, "wil": 6, "cha": 4 } })


func fight(ch: Dictionary, map: Array = ["P..E"], extra: Dictionary = {}) -> StateScript:
	var setup := { "layout": { "map": map }, "party": [{ "char": ch }], "enemies": [DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)] }
	setup.merge(extra, true)
	return StateScript.new(db(), seeded(5), setup)


func test_builtins_cost_an_action() -> void:
	var st := fight(hero())
	var me = st.unit_by_id("player")
	check(not st.is_quick_now(me, { "builtin": true }), "Strike and Guard are not Quicks any more")
	var a0: int = me.actions_left
	if st.guard(me):
		check(me.actions_left == a0 - 1, "Guard spends an Action")


func test_dungeon_exit_open() -> void:
	var f := { "rooms": [{ "type": "combat", "cleared": false }, { "type": "boss", "cleared": true }] }
	check(Night.exit_blockers(db(), f) == 0, "you can leave without clearing every fight")
	f["rooms"][1]["cleared"] = false
	check(Night.exit_blockers(db(), f) == 1, "but not without beating the boss")


func test_arena_offers_are_equipable() -> void:
	var solo := [hero("fighter")]
	for wave in range(1, 12):
		for id in Arena.card_offer(db(), { "seed": 3 }, solo, wave):
			check(Crafting.eligibility(db(), solo[0], DT.index_under(db(), "cards/", "cards").get(str(id), {})) == "", "wave %d offer %s fits the solo fighter" % [wave, id])


func test_wrap_text() -> void:
	var w := UiThemeScript.wrap_text("one two three four five six seven eight nine ten", 12)
	check(w.split("\n").size() > 3 and Array(w.split("\n")).all(func(l: String) -> bool: return l.length() <= 12), "long tooltips wrap: %s" % w)


func test_relics_and_goods() -> void:
	var ch := hero()
	var run := { "player": ch }
	var hp0 := int(Char.derived(db(), ch)["maxHp"])
	check(Inv.give(db(), run, ch, "relic_iron_heart") == "" and int(Char.derived(db(), ch)["maxHp"]) == hp0 + 10, "a relic's mods apply to its wearer")
	check(Inv.give(db(), run, ch, "relic_mana_stone") == "" and Inv.give(db(), run, ch, "relic_ember_charm") == "full", "relic slots fill up")
	check(Inv.lose_relics(ch).size() == 2 and ch["relics"].is_empty(), "going down loses every relic")
	var deck0: int = ch["deck"].size()
	check(Inv.give(db(), run, ch, "goods_fire_flask") == "" and ch["deck"].size() == deck0 + 1, "deck goods join the deck")
	Inv.spend_from_deck(ch, ["card_fire_flask"])
	check(ch["deck"].size() == deck0, "once used, they're gone for good")
	check(Inv.give(db(), run, ch, "goods_potion_heal") == "" and run["backpack"] == ["card_potion_heal"], "potions go in the backpack")
	var stock := Inv.stock(db(), seeded(2))
	check(stock.size() == int(Inv.cfg(db())["stockSize"]) and stock.all(func(i: String) -> bool: return Inv.needs(db(), i) != ""), "the merchant stocks goods it can sell")


func test_backpack_in_combat() -> void:
	var ch := hero()
	ch["hp"] = 10
	var st := fight(ch, ["P..E"], { "backpack": ["card_potion_heal"] })
	var me = st.unit_by_id("player")
	if st.current != me:
		return
	check(st.use_backpack(me, 0) and me.hp > 10 and st.backpack.is_empty(), "a backpack potion heals the user")
	check(st.finish()["backpackUsed"] == ["card_potion_heal"], "and is reported as used")


func test_consumables_reported_spent() -> void:
	var ch := hero()
	ch["deck"] = ["card_potion_heal", "card_potion_heal", "card_potion_heal"]
	var st := fight(ch)
	var me = st.unit_by_id("player")
	if st.current != me:
		return
	st.play_card(me, 0, me.cell)
	var spent: Array = st.finish()["party"][0]["spent"]
	check(spent == ["card_potion_heal"], "a used consumable is reported for removal: %s" % str(spent))


func test_boss_gimmicks_and_loop() -> void:
	var a := { "seed": 7 }
	check(Arena.is_boss(db(), 5) and not Arena.gimmick_for(db(), 5).is_empty(), "every 5th wave is a boss with a gimmick")
	var boss: Dictionary = Arena.wave_enemies(db(), a, 5)["enemies"][0]
	check(boss.has("gimmick"), "the boss carries its gimmick (%s)" % str(boss.get("gimmick", "")))
	var seen := {}
	for w in range(5, 51, 5):
		seen[str(Arena.gimmick_for(db(), w)["id"])] = true
	check(seen.size() >= 5, "gimmicks vary across the bosses (%d)" % seen.size())
	check(Arena.content_wave(db(), 51) == 1 and Arena.loop_index(db(), 51) == 1, "after wave 50 the arena loops")
	var hp50: int = int(Arena.wave_enemies(db(), a, 1)["enemies"][0].get("hp", 0))
	var hp51: int = int(Arena.wave_enemies(db(), a, 51)["enemies"][0].get("hp", 0))
	check(Arena.week_for_wave(db(), 51) == Arena.week_for_wave(db(), 1), "the loop starts over with the same enemies")


func test_thorns_and_last_stand() -> void:
	var st := fight(hero())
	var me = st.unit_by_id("player")
	var foe = null
	for u in st.units:
		if u.team == "enemy":
			foe = u
	foe.source["thorns"] = 3
	foe.source["lastStand"] = 0.5
	var hp0: int = me.hp
	foe.hp = foe.max_hp
	st._after_hit(me, foe, 5)
	check(me.hp == hp0 - 3, "Thorned Hide hurts the attacker")
	foe.hp = foe.max_hp / 2
	st._after_hit(me, foe, 1)
	check(foe.shield > 0 and foe.links.has("last_stand"), "Last Stand shields once at half HP")


func test_deck_synergies() -> void:
	var ch := hero("mage")
	ch["deck"] = ["card_rummage", "card_recall", "card_battle_plan", "card_strike", "card_strike", "card_strike", "card_strike", "card_strike"]
	var st := fight(ch)
	var me = st.unit_by_id("player")
	if st.current != me:
		return
	var FX := preload("res://src/core/combat/card_effects.gd")
	var h0: int = me.deck.hand.size()
	FX.run(st, me, { "effects": [{ "op": "draw", "n": 2 }] }, me.cell, [me.cell])
	check(me.deck.hand.size() == h0 + 2, "draw puts more cards in hand")
	me.deck.discard.append("card_strike")
	var d0: int = me.deck.discard.size()
	FX.run(st, me, { "id": "card_recall", "effects": [{ "op": "recall", "n": 1 }] }, me.cell, [me.cell])
	check(me.deck.discard.size() == d0 - 1, "recall brings a card back from the discard pile")
	var hs: int = st.hand_size(me)
	FX.run(st, me, { "effects": [{ "op": "hand_plus", "n": 1, "turns": 3 }] }, me.cell, [me.cell])
	check(st.hand_size(me) == hs + 1, "a bigger hand for a few turns")
	check(Arena.card_offer(db(), { "seed": 3 }, [hero()], 2).all(func(i: String) -> bool: return int(DT.index_under(db(), "cards/", "cards").get(i, {}).get("minWave", 0)) <= 2), "synergy cards only show up in later waves")


func test_flanking() -> void:
	var ch := hero()
	var st := fight(ch, ["..E", "...", "..."])
	var me = st.unit_by_id("player")
	var foe = null
	for u in st.units:
		if u.team == "enemy":
			foe = u
	me.cell = Vector2i(0, 1)
	foe.cell = Vector2i(1, 1)
	check(is_equal_approx(st.position_mul(me, foe), 1.0), "no flank alone")
	var ally := hero("rogue")
	var other = StateScript.new(db(), seeded(5), { "layout": { "map": ["P.E"] }, "party": [{ "char": ch }, { "char": ally }], "enemies": [DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)] })
	var a1 = other.units[0]
	var a2 = other.units[1]
	var f = null
	for u in other.units:
		if u.team == "enemy":
			f = u
	a1.cell = Vector2i(0, 0)
	f.cell = Vector2i(1, 0)
	a2.cell = Vector2i(2, 0)
	check(other.position_mul(a1, f) > 1.0, "an ally on the far side flanks the target")


func test_difficulty_ramp() -> void:
	check(is_equal_approx(StateScript.ramp_for(db(), 1, 0), 0.0) and is_equal_approx(StateScript.ramp_for(db(), 3, 0), 1.0), "story: gentle in week 1, full from week 3")
	check(is_equal_approx(StateScript.ramp_for(db(), 0, 1), 0.0) and is_equal_approx(StateScript.ramp_for(db(), 0, 15), 1.0), "arena: gentle at wave 1, full from wave 15")
	var early := fight(hero(), ["P..E"], { "ramp": 0.0 })
	var late := fight(hero(), ["P..E"], { "ramp": 1.0 })
	check(early.diff_value("enemyDamageMul") < late.diff_value("enemyDamageMul"), "enemies hit softer early (%.2f vs %.2f)" % [early.diff_value("enemyDamageMul"), late.diff_value("enemyDamageMul")])

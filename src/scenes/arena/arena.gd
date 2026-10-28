## The Endless Arena hub (docs/ARENA.md Part 5): between waves it shows the
## next wave, its hazard set, the score and the party; it starts each wave as
## a normal fight and reads the result when the fight hands back. Checkpoints
## every 5 waves spend Arena AP and pick a mutator. Two modes: from the title
## (run["arena"], a throwaway run) and the Rift in the story (run["rift"]:
## rewards bank at checkpoints, losing knocks you out until tomorrow).
extends Node2D

const Arena := preload("res://src/core/arena/arena.gd")
const Party := preload("res://src/core/arena/arena_party.gd")
const Night := preload("res://src/core/dungeon/night.gd")
const Sig := preload("res://src/core/dungeon/signature.gd")
const Modal := preload("res://src/scenes/ui/modal.gd")
const Workbench := preload("res://src/scenes/ui/workbench_screen.gd")
const PartyScreen := preload("res://src/scenes/ui/party_screen.gd")
const Shop := preload("res://src/core/town/shop.gd")
const SELF := "res://src/scenes/arena/arena.tscn"
const TITLE := "res://src/scenes/title/title.tscn"
const TOWN := "res://src/scenes/town/town.tscn"

var arena: Dictionary = {}
var story := false
var _ui: CanvasLayer
var _panel: PanelContainer
var _box: VBoxContainer
var _t := 0.0
var _busy := false
var _strip: VBoxContainer


func _ready() -> void:
	Flow.set_hud(false)
	story = GameState.run.has("rift") and not GameState.run.has("arena")
	arena = GameState.run.get("rift" if story else "arena", {})
	if arena.is_empty():
		arena = Arena.new_arena(int(GameState.run.get("seed", 1)), false)
		GameState.run["arena"] = arena
	_ui = CanvasLayer.new()
	add_child(_ui)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(Display.base.x * 0.62, 0)
	_ui.add_child(_panel)
	_box = VBoxContainer.new()
	_panel.add_child(_box)
	_strip = preload("res://src/scenes/ui/effects_strip.gd").new()
	_strip.position = Vector2(2, 40)
	_ui.add_child(_strip)
	Audio.play_music(str(Arena.waves(DataDB.all()).get("music", {}).get("hub", "dungeon")))
	if bool(arena.get("inFight", false)) and GameState.combat_context == "arena":
		_after_wave()
	_refresh()
	if bool(GameState.run.get("pendingPointBuy", false)):
		_point_buy.call_deferred()
	if GameState.dev_autoplay:
		_autoplay.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## A rift backdrop: a dark sky with a slow glowing seam.
func _draw() -> void:
	var view := Display.size_f()
	draw_rect(Rect2(Vector2.ZERO, view), Color("0b0716"))
	var glow := 0.5 + 0.5 * sin(_t * 0.8)
	var c := Color(UiTheme.vector_color("transmutation"), 0.25 + 0.2 * glow)
	var x := view.x / 2.0
	for i in 24:
		var y := view.y * float(i) / 24.0
		var w := 6.0 + 10.0 * sin(_t + float(i) * 0.7)
		draw_rect(Rect2(x - w / 2.0 + 14.0 * sin(float(i) * 0.5 + _t * 0.3), y, w, view.y / 24.0 + 1.0), c)


func _clear() -> void:
	for ch in _box.get_children():
		_box.remove_child(ch)
		ch.queue_free()


func _text(t: String, color: Variant = null) -> Label:
	var l := UiTheme.label(t, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(_panel.custom_minimum_size.x - 12, 0)
	_box.add_child(l)
	return l


func _button(t: String, cb: Callable, disabled: bool = false, tip: String = "") -> Button:
	var b := UiTheme.button(t, cb)
	b.disabled = disabled
	b.tooltip_text = tip
	_box.add_child(b)
	return b


func _center() -> void:
	_panel.reset_size()
	_panel.position = (Display.size_f() - _panel.size) / 2.0


func _refresh() -> void:
	_clear()
	if _strip != null:
		_strip.refresh()
	var db: Dictionary = DataDB.all()
	var next := int(arena["wave"]) + 1
	_text((Strings.t("arena.the_rift") if story else Strings.t("arena.endless_arena")) + Strings.t("arena.score") % int(arena["score"]), UiTheme.ACCENT)
	var phase := str(arena.get("phase", "ready"))
	if phase == "over":
		_over()
		return
	for ch in Party.party(GameState.run):
		var d := preload("res://src/core/character.gd").derived(db, ch)
		_text(Strings.t("arena.lv_hp_mp") % [ch.get("name", "?"), int(ch.get("level", 1)), int(ch.get("hp", 0)), int(d["maxHp"]), int(ch.get("mp", 0)), int(d["maxMp"])], UiTheme.DIM)
	for m in arena.get("mutators", []):
		_text(Strings.t("arena.mutator") % [m.get("name", ""), m.get("text", "")], UiTheme.GOOD)
	if not arena.get("offer", []).is_empty():
		_card_pick()
		return
	if phase == "checkpoint":
		_checkpoint()
		return
	var hz := Arena.hazard_set(db, next)
	var kind := Strings.t("arena.boss_wave") if Arena.is_boss(db, next) else (Strings.t("arena.elite_wave") if Arena.is_elite(db, next) else "Wave")
	_text(Strings.t("arena.terrain") % [kind, next, hz.get("name", "plain")], UiTheme.TEXT)
	if not arena.get("lastPick", {}).is_empty():
		_button(Strings.t("arena.undo_pick"), func() -> void:
			Arena.undo_pick(arena, GameState.run)
			_refresh())
	_button(Strings.t("arena.start_wave") % next, _start_wave)
	_button(Strings.t("arena.party"), func() -> void:
		await Flow.show_modal(preload("res://src/scenes/ui/party_panel.gd").new()))
	if not story:
		_button(Strings.t("pause.save_quit"), func() -> void: GameState.save_arena_and_quit())
	if not story:
		_button(Strings.t("arena.give_up"), func() -> void: _end_run())
	_center()


# --- Waves --------------------------------------------------------------------

func _start_wave() -> void:
	if _busy:
		return
	_busy = true
	var db: Dictionary = DataDB.all()
	var wave := int(arena["wave"]) + 1
	arena["wave"] = wave
	arena.erase("lastPick")
	var setup := Arena.setup_for_wave(db, arena, wave)
	setup["party"] = GameState.combat_party()
	setup["library"] = GameState.cards
	setup["difficulty"] = GameState.combat_difficulty
	setup["partyFirst"] = bool(DataDB.table("combat_rules").get("actions", {}).get("partyFirstInArena", true))
	var hp := 0
	for ch in Party.party(GameState.run):
		hp += int(ch.get("hp", 0))
	arena["hpBefore"] = hp
	var before: Array = []
	for ch in Party.party(GameState.run):
		before.append({ "id": str(ch.get("id", "")), "hp": int(ch.get("hp", 0)), "mp": int(ch.get("mp", 0)) })
	arena["partyBefore"] = before
	arena["inFight"] = true
	setup["intro"] = Strings.t("arena.wave") % [wave, str(Arena.hazard_set(db, wave).get("name", ""))]
	GameState.start_combat(setup, SELF)


func _after_wave() -> void:
	var db: Dictionary = DataDB.all()
	arena["inFight"] = false
	var summary: Dictionary = GameState.last_combat
	if str(summary.get("result", "")) != "win":
		_lost()
		return
	var hp := 0
	for ch in Party.party(GameState.run):
		hp += int(ch.get("hp", 0))
		ch["hp"] = maxi(1, int(ch.get("hp", 0)))
	var lines := Arena.wave_won(db, arena, { "rounds": int(summary.get("rounds", 99)), "damageTaken": maxi(0, int(arena.get("hpBefore", hp)) - hp),
		"multiVector": int(summary.get("multiVector", 0)) })
	Arena.breather(db, Party.party(GameState.run))
	for l in lines:
		Narrator.say(str(l))
	var wave := int(arena["wave"])
	arena["highestHit"] = maxi(int(arena.get("highestHit", 0)), int(summary.get("highestHit", 0)))
	# PT Part 6: a card pick after every wave.
	arena["offer"] = Arena.card_offer(db, arena, Party.party(GameState.run), wave)
	if wave % int(Arena.waves(db).get("narratorEvery", 5)) == 0:
		Narrator.react("arena")
	if Arena.is_checkpoint(db, wave):
		var banked := Arena.checkpoint(db, arena)
		if story:
			_apply_rewards(banked)
		arena["phase"] = "checkpoint"
	else:
		arena["phase"] = "ready"


## Story: banked rewards become real (XP, money, shards, cards).
func _apply_rewards(r: Dictionary) -> void:
	var db: Dictionary = DataDB.all()
	for ch in Party.party(GameState.run):
		GameState.give_xp(str(ch["id"]), int(r.get("xp", 0)))
	GameState.money += int(r.get("money", 0))
	for i in int(r.get("shards", 0)):
		var axis := Night.shard_axis(db, GameState.run, Calendar.week(), Rng.stream("loot"))
		for l in Night.add_shard(db, GameState.run, axis):
			Narrator.say(str(l))
	var coll: Dictionary = GameState.run.get("collection", {})
	for c in r.get("cards", []):
		coll[str(c)] = int(coll.get(str(c), 0)) + 1
	GameState.run["collection"] = coll
	Narrator.say(Strings.t("arena.rewards_banked_xp") % [int(r.get("xp", 0)), int(r.get("money", 0))])


func _lost() -> void:
	arena["phase"] = "over"
	if story:
		return
	var scores: Dictionary = Journal.data.get("arena", {})
	var best := Arena.record_score(scores, arena, Party.party(GameState.run).size())
	scores["bestWave"] = maxi(int(scores.get("bestWave", 0)), int(arena["cleared"]))
	Journal.data["arena"] = scores
	Journal.save_journal()
	arena["newBest"] = best


func _over() -> void:
	if story:
		_text(Strings.t("arena.you_re_knocked_out_you"), UiTheme.BAD)
		_text(Strings.t("arena.rewards_up_to_your_last"), UiTheme.DIM)
		_button(Strings.t("arena.wake_up"), _wake_at_home)
	else:
		_text(Strings.t("arena.waves_cleared_final_score") % [int(arena["cleared"]), int(arena["score"]), Strings.t("arena.new_best") if bool(arena.get("newBest", false)) else ""], UiTheme.TEXT)
		var scores: Dictionary = Journal.data.get("arena", {})
		_text(Strings.t("arena.best_wave_ever") % int(scores.get("bestWave", 0)), UiTheme.DIM)
		var names: Array = []
		for id in arena.get("picked", []):
			names.append(str(preload("res://src/core/card.gd").resolve(DataDB.all(), str(id), GameState.cards).get("name", id)))
		_text(Strings.t("arena.score_cards") % (", ".join(PackedStringArray(names)) if not names.is_empty() else "-"), UiTheme.DIM)
		var perks: Array = []
		for id in arena.get("perksTaken", []):
			perks.append(str(DataDB.record("perks", str(id)).get("name", id)))
		_text(Strings.t("arena.score_picks") % (", ".join(PackedStringArray(perks)) if not perks.is_empty() else "-"), UiTheme.DIM)
		_text(Strings.t("arena.score_highest_hit") % int(arena.get("highestHit", 0)), UiTheme.DIM)
		for k in scores:
			if str(k).begins_with("party"):
				_text(Strings.t("arena.points_wave") % [str(k).replace("party", Strings.t("arena.party_of")).replace("_mut", Strings.t("arena.mutators")), int(scores[k]["score"]), int(scores[k]["wave"])], UiTheme.DIM)
		_button(Strings.t("arena.back_to_the_title"), _end_run)
	_center()


func _end_run() -> void:
	GameState.run.erase("arena")
	SceneRouter.goto(TITLE)


## Story: knocked out in the Rift. Injured, home, and the rest of the day is lost.
func _wake_at_home() -> void:
	GameState.run.erase("rift")
	GameState.player["injured"] = maxi(1, int(GameState.player.get("injured", 0)))
	GameState.run.erase("town_pos")
	var day: int = Calendar.logic.day_index
	var guard := 0
	while Calendar.logic.day_index == day and guard < 12:
		GameState.advance_part()
		guard += 1
	SceneRouter.goto(TOWN)


## Story: leave at a checkpoint with what you banked.
func _leave() -> void:
	GameState.run.erase("rift")
	GameState.advance_part()
	SceneRouter.goto(TOWN)


# --- Checkpoints ----------------------------------------------------------------

func _checkpoint() -> void:
	var db: Dictionary = DataDB.all()
	var costs: Dictionary = Arena.checkpoint_cfg(db).get("costs", {})
	_text(Strings.t("arena.checkpoint_arena_ap_unspent_ap") % int(arena["ap"]), UiTheme.ACCENT)
	var hz := Arena.hazard_set(db, int(arena["wave"]) + 1)
	_text(Strings.t("arena.next_wave_s_terrain") % hz.get("name", "plain"), UiTheme.DIM)
	_button(Strings.t("arena.perk_pick"), _perk_pick, int(arena.get("perkPicked", -1)) == int(arena["wave"]))
	_button(Strings.t("forge.title"), func() -> void:
		var fs := preload("res://src/scenes/ui/forge_screen.gd").new()
		fs.spend_ap = _arena_spend
		fs.ap_left = func() -> int: return int(arena["ap"])
		await Flow.show_modal(fs)
		_refresh())
	var ap := int(arena["ap"])
	_button(Strings.t("arena.rest_heal_half_hp_and") % int(costs.get("rest", 2)), func() -> void:
		if Arena.spend(db, arena, "rest"):
			Arena.rest(db, Party.party(GameState.run))
		_refresh(), ap < int(costs.get("rest", 2)) or bool(arena.get("noRest", false)), Strings.t("arena.no_resting_after_high_stakes") if bool(arena.get("noRest", false)) else "")
	_button(Strings.t("arena.swap_cards_in_a_deck") % int(costs.get("swapCard", 1)), func() -> void: await _workbench(0, int(costs.get("removeCard", costs.get("swapCard", 1)))), ap < 0)
	_button(Strings.t("arena.craft_a_card_ap") % int(costs.get("craftCard", 2)), func() -> void: await _workbench(int(costs.get("craftCard", 2)), 0), ap < int(costs.get("craftCard", 2)))
	_button(Strings.t("arena.swap_a_teammate_ap") % int(costs.get("swapTeammate", 2)), _swap_teammate, ap < int(costs.get("swapTeammate", 2)) or GameState.roster.size() <= GameState.party_ids.size())
	_button(Strings.t("arena.change_equipment_ap") % int(costs.get("changeEquipment", 1)), _equipment, ap < int(costs.get("changeEquipment", 1)) or _equipment_items().is_empty())
	if arena.get("mutators", []).is_empty():
		_text(Strings.t("arena.pick_a_mutator_for_the"), UiTheme.ACCENT)
		for m in arena.get("offered", []):
			var mid := str(m["id"])
			_button("%s: %s" % [m.get("name", mid), m.get("text", "")], func() -> void:
				Arena.choose_mutator(arena, mid)
				_refresh())
		_button(Strings.t("arena.reroll_the_choices_ap") % int(costs.get("rerollMutators", 1)), func() -> void:
			if Arena.spend(db, arena, "rerollMutators"):
				Arena.offer_mutators(db, arena, int(arena.get("rerolls", 0)) + 1)
			_refresh(), ap < int(costs.get("rerollMutators", 1)))
		_button(Strings.t("arena.no_mutator"), func() -> void:
			arena["offered"] = []
			arena["mutators"] = []
			arena["phase"] = "ready"
			_refresh())
	else:
		_button(Strings.t("arena.continue_to_wave") % (int(arena["wave"]) + 1), func() -> void:
			arena["phase"] = "ready"
			_refresh())
	if story:
		_button(Strings.t("arena.bank_and_leave_the_rift"), _leave)
	_center()


## PT Part 9: point buy for each party member, from their recommended picks.
func _point_buy() -> void:
	GameState.run.erase("pendingPointBuy")
	const PB := preload("res://src/core/progression/point_buy.gd")
	for ch in Party.party(GameState.run):
		var start := PB.recommended(DataDB.all(), str(ch.get("class", "mage")))
		var pb := preload("res://src/scenes/ui/point_buy_screen.gd").new()
		pb.class_id = str(ch.get("class", "mage"))
		pb.who = str(ch.get("name", ""))
		pb.stats = start
		var got: Variant = await Flow.show_modal(pb)
		if got != null:
			# Undo the recommended picks, then apply the chosen ones.
			var diff := {}
			for s in got:
				diff[s] = int(got[s]) - int(start.get(s, 3))
			for s in diff:
				ch["stats"][s] = maxi(1, int(ch["stats"].get(s, 3)) + int(diff[s]))
			preload("res://src/core/character.gd").full_restore(DataDB.all(), ch)
	_refresh()


## PT Part 6: pick 1 of 3 cards after a wave, or skip for Scraps.
func _card_pick() -> void:
	var db: Dictionary = DataDB.all()
	_text(Strings.t("arena.pick_a_card"), UiTheme.ACCENT)
	var row := HBoxContainer.new()
	_box.add_child(row)
	for id in arena.get("offer", []):
		var cid := str(id)
		var card := preload("res://src/core/card.gd").resolve(db, cid, GameState.cards)
		var cv := preload("res://src/scenes/combat/card_view.gd").new()
		cv.setup(card, preload("res://src/core/card.gd").cost(db, card))
		cv.pressed.connect(func() -> void:
			var op := preload("res://src/scenes/ui/owner_pick.gd").new()
			op.card_id = cid
			op.active_ids = ["player"] + GameState.party_ids
			var who: Variant = await Flow.show_modal(op)
			if who == null:
				return
			if Arena.pick_card(db, arena, GameState.run, cid, str(who)):
				var owner_name := Strings.t("owner.collection") if str(who) == "" else str(GameState.character(str(who)).get("name", who))
				Narrator.say(Strings.t("arena.card_added") % [str(card.get("name", cid)), owner_name])
			_refresh())
		row.add_child(cv)
	_button(Strings.t("arena.skip_for_scraps"), func() -> void:
		Arena.skip_offer(db, arena, GameState.run)
		_refresh())
	_center()


## PT Part 6: one perk pick per checkpoint for a party member of your choice.
func _perk_pick() -> void:
	var db: Dictionary = DataDB.all()
	var m := preload("res://src/scenes/ui/modal.gd").new()
	m.build(Strings.t("arena.perk_pick"), 380)
	for ch in Party.party(GameState.run):
		var c: Dictionary = ch
		for pid in Arena.perk_offer(db, arena, c):
			var rec := DataDB.record("perks", str(pid))
			var p := str(pid)
			m.add_button("%s: %s (%s)" % [str(c.get("name", "?")).split(" ")[0], rec.get("name", p), rec.get("text", "")], func() -> void:
				Arena.take_perk(arena, c, p)
				m.finish(p))
	m.add_button(Strings.t("party_panel.close"), func() -> void: m.finish(null))
	await Flow.show_modal(m)
	_refresh()


func _arena_spend(n: int, _kind: String) -> bool:
	if int(arena["ap"]) < n:
		return false
	arena["ap"] = int(arena["ap"]) - n
	return true


func _workbench(craft_cost: int, swap_cost: int) -> void:
	var wb := Workbench.new()
	wb.place = Strings.t("arena.the_rift_2")
	wb.craft_ap = maxi(1, craft_cost)
	wb.deck_save_cost = swap_cost
	wb.ap_left = func() -> int: return int(arena["ap"])
	wb.spend_ap = _arena_spend
	await Flow.show_modal(wb)
	_refresh()


func _swap_teammate() -> void:
	var cost := int(Arena.checkpoint_cfg(DataDB.all()).get("costs", {}).get("swapTeammate", 2))
	var before := GameState.party_ids.duplicate()
	await Flow.show_modal(PartyScreen.new())
	if GameState.party_ids != before:
		if not _arena_spend(cost, "swapTeammate"):
			GameState.party_ids = before
	_refresh()


func _equipment_items() -> Array:
	var out: Array = []
	for id in GameState.run.get("inventory", {}):
		if str(DataDB.record("items", str(id)).get("kind", "")) == "equipment" and int(GameState.run["inventory"][id]) > 0:
			out.append(str(id))
	return out


func _equipment() -> void:
	var m := Modal.new()
	m.build(Strings.t("arena.change_equipment"), 380)
	for id in _equipment_items():
		var it := DataDB.record("items", id)
		for ch in Party.party(GameState.run):
			var who: Dictionary = ch
			var iid: String = id
			m.add_button("%s: %s" % [who.get("name", "?"), it.get("name", iid)], func() -> void: m.finish({ "ch": who, "item": iid }))
	m.add_button(Strings.t("arena.back"), func() -> void: m.finish(null))
	var r: Variant = await Flow.show_modal(m)
	if r is Dictionary and _arena_spend(int(Arena.checkpoint_cfg(DataDB.all()).get("costs", {}).get("changeEquipment", 1)), "changeEquipment"):
		var err := Shop.equip(DataDB.all(), GameState.run, r["ch"], str(r["item"]))
		if err != "":
			Narrator.say(err)
	_refresh()


# --- Dev --------------------------------------------------------------------------

## --autoplay: keep going on its own (rest when possible, first mutator) up to --waves.
func _autoplay() -> void:
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	var cap := int(GameState.run.get("devArenaWaves", 999))
	if not arena.get("offer", []).is_empty():
		# Autoplay takes the first card offered, and a perk at checkpoints (PT Part 6).
		var pick_id := str(arena["offer"][0])
		Arena.pick_card(DataDB.all(), arena, GameState.run, pick_id, Arena.auto_owner(DataDB.all(), GameState.run, preload("res://src/core/card.gd").resolve(DataDB.all(), pick_id)))
		_refresh()
		_autoplay()
		return
	if str(arena.get("phase", "")) == "checkpoint" and int(arena.get("perkPicked", -1)) != int(arena["wave"]):
		var ch: Dictionary = Party.party(GameState.run)[0]
		var offer := Arena.perk_offer(DataDB.all(), arena, ch)
		if not offer.is_empty():
			Arena.take_perk(arena, ch, str(offer[0]))
	match str(arena.get("phase", "ready")):
		"ready":
			if int(arena["wave"]) < cap:
				_start_wave()
		"checkpoint":
			var db: Dictionary = DataDB.all()
			if Arena.spend(db, arena, "rest"):
				Arena.rest(db, Party.party(GameState.run))
			if not arena.get("offered", []).is_empty():
				Arena.choose_mutator(arena, str(arena["offered"][0]["id"]))
			arena["phase"] = "ready"
			_refresh()
			_autoplay()

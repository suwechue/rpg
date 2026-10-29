## The Endless Arena hub (docs/ARENA.md Part 5): between waves it shows the
## next wave, its hazard set, the score and the party; it starts each wave as
## a normal fight and reads the result when the fight hands back. Checkpoints
## every 5 waves spend Arena AP and pick a mutator. Two modes: from the title
## (run["arena"], a throwaway run) and the Rift in the story (run["rift"]:
## rewards bank at checkpoints, losing knocks you out until tomorrow).
extends Node2D

const Inv := preload("res://src/core/items/inventory.gd")
const Arena := preload("res://src/core/arena/arena.gd")
const Camp := preload("res://src/core/arena/camp.gd")
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
var _camp: Node2D            # AC: the walkable camp at checkpoints


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
	Audio.play_ambience("arena")
	if bool(arena.get("inFight", false)) and GameState.combat_context == "arena":
		_after_wave()
	_refresh()
	_intro.call_deferred()
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
	if _camp != null and is_instance_valid(_camp):
		_camp.call("refresh")
		return
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
	var hz := Arena.hazard_set(db, next, arena)
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
	if Arena.is_boss(DataDB.all(), wave) and not bool(Journal.data.get("arena_boss_seen", false)):
		Journal.data["arena_boss_seen"] = true
		Journal.save_journal()
		await Cutscenes.play("arena_boss_first", self)
	elif (wave - 1) % int(Arena.waves(DataDB.all()).get("themes", {}).get("blockSize", 5)) == 0:
		var th := Arena.theme_for(DataDB.all(), arena, wave)
		if not th.is_empty() and not GameState.dev_autoplay:
			Narrator.say(Strings.t("arena.theme_banner") % [str(th.get("name", "")), str(th.get("text", ""))])
	# Boss waves announce their gimmick before the fight (user request, Oct 28).
	var gim := Arena.gimmick_for(db, wave)
	if not gim.is_empty() and not GameState.dev_autoplay:
		if not bool(Journal.data.get("arena_gimmick_seen", false)):
			Journal.data["arena_gimmick_seen"] = true
			Journal.save_journal()
			await Cutscenes.play("arena_gimmick_first", self)
		var boss_rec: Dictionary = Arena.wave_enemies(db, arena, wave)["enemies"][0]
		await Flow.show_event({ "title": Strings.t("arena.boss_gimmick_title") % [wave, str(boss_rec.get("name", "?"))],
			"text": Strings.t("arena.boss_gimmick_text") % [str(boss_rec.get("intro", boss_rec.get("text", ""))), str(gim.get("name", "")), str(gim.get("text", ""))] })
	var setup := Arena.setup_for_wave(db, arena, wave)
	setup["party"] = GameState.combat_party()
	setup["backpack"] = GameState.run.get("backpack", [])
	setup["ramp"] = preload("res://src/core/combat/combat_state.gd").ramp_for(db, 0, wave)
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
	setup["intro"] = Strings.t("arena.wave") % [wave, str(Arena.hazard_set(db, wave, arena).get("name", ""))]
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
	if best:
		_arena_cutscenes.call_deferred()


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
			perks.append(str(preload("res://src/core/progression/leveling.gd").techniques(DataDB.all()).get(str(id), {}).get("name", id)))
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
	if bool(Camp.cfg(db).get("enabled", true)) and not GameState.dev_autoplay:
		_open_camp.call_deferred()
		return
	var costs: Dictionary = Arena.checkpoint_cfg(db).get("costs", {})
	_text(Strings.t("arena.checkpoint_arena_ap_unspent_ap") % int(arena["ap"]), UiTheme.ACCENT)
	var hz := Arena.hazard_set(db, int(arena["wave"]) + 1, arena)
	_text(Strings.t("arena.next_wave_s_terrain") % hz.get("name", "plain"), UiTheme.DIM)
	var nth := Arena.theme_for(db, arena, int(arena["wave"]) + 1)
	if not nth.is_empty():
		# The next block's theme: rebuild decks for it here.
		_text(Strings.t("arena.next_theme") % [str(nth.get("name", "")), str(nth.get("text", ""))], UiTheme.ACCENT)
	_button(Strings.t("arena.technique_pick"), _perk_pick, int(arena.get("perkPicked", -1)) == int(arena["wave"]))
	_button(Strings.t("arena.merchant") % _coins(), _merchant)
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


## The first-visit cutscene, then point buy, one after the other.
func _intro() -> void:
	await _arena_cutscenes()
	if bool(GameState.run.get("pendingPointBuy", false)):
		await _point_buy()
	_refresh()


## Arena cutscenes (P2 Part 3): the first visit, the first wave 10 boss, a new
## best score, and each new 5-wave theme. Seen-flags live in the Journal.
func _arena_cutscenes() -> void:
	if not bool(Journal.data.get("arena_first_seen", false)):
		Journal.data["arena_first_seen"] = true
		Journal.save_journal()
		await Cutscenes.play("arena_first", self)
	if bool(arena.get("newBest", false)) and str(arena.get("phase", "")) == "over" and not bool(arena.get("bestShown", false)):
		arena["bestShown"] = true
		await Cutscenes.play("arena_new_best", self)


## AC: the walkable camp replaces the checkpoint menu.
func _open_camp() -> void:
	if _camp != null and is_instance_valid(_camp):
		return
	var db: Dictionary = DataDB.all()
	_panel.visible = false
	_camp = preload("res://src/scenes/arena/camp_view.gd").new()
	_camp.set("host", self)
	_camp.set("story", story)
	_camp.set("wave", int(arena["wave"]))
	add_child(_camp)
	Audio.play_music_first([str(Camp.cfg(db).get("music", "")), "arena"])
	Audio.play_ambience(str(Camp.cfg(db).get("ambience", "")))
	if not bool(Journal.data.get("arena_camp_seen", false)):
		Journal.data["arena_camp_seen"] = true
		Journal.save_journal()
		await Cutscenes.play("arena_camp_first", self)
	await Cutscenes.play_steps([{ "type": "title_card", "text": Strings.t("camp.arrived") % int(arena["wave"]), "seconds": 1.0 }], self, "camp_arrival")
	for u in Camp.upgrades(db, int(arena["wave"])):
		if int(u.get("minWave", 0)) == int(arena["wave"]):
			Narrator.say(str(u.get("text", "")))
	SaveSystem.save_run(true)


func _close_camp() -> void:
	if _camp != null and is_instance_valid(_camp):
		_camp.queue_free()
	_camp = null
	_panel.visible = true


func _mark_done(id: String) -> void:
	var d: Array = arena.get("campDone", [])
	if not d.has(id):
		d.append(id)
	arena["campDone"] = d


## What a camp station does (docs/ARENA_CAMPFIRE.md Part 2).
func camp_action(st: Dictionary) -> void:
	var db: Dictionary = DataDB.all()
	var costs: Dictionary = Arena.checkpoint_cfg(db).get("costs", {})
	var id := str(st.get("id", ""))
	match str(st.get("kind", "")):
		"campfire":
			var m := Modal.new()
			m.build(Strings.t("camp.campfire"), 340)
			m.text(Strings.t("camp.summary") % [int(arena.get("cleared", 0)), int(arena.get("score", 0)), int(arena.get("bestHit", 0)), arena.get("picked", []).size()], UiTheme.DIM)
			m.text(Narrator.line("arena"), UiTheme.TEXT)
			m.add_button(Strings.t("camp.rest") % int(costs.get("rest", 2)), func() -> void: m.finish("rest"), int(arena["ap"]) < int(costs.get("rest", 2)) or bool(arena.get("noRest", false)))
			m.add_button(Strings.t("camp.close"), func() -> void: m.finish(null))
			if str(await Flow.show_modal(m)) == "rest" and Arena.spend(db, arena, "rest"):
				Arena.rest(db, Party.party(GameState.run))
				_mark_done(id)
		"companions":
			await _companions()
		"deli":
			await _deli()
		"workbench":
			var m := Modal.new()
			m.build(Strings.t("camp.workbench_title"), 320)
			m.add_button(Strings.t("forge.title"), func() -> void: m.finish("forge"))
			m.add_button(Strings.t("arena.swap_cards_in_a_deck") % int(costs.get("swapCard", 1)), func() -> void: m.finish("swap"))
			m.add_button(Strings.t("arena.craft_a_card_ap") % int(costs.get("craftCard", 2)), func() -> void: m.finish("craft"), int(arena["ap"]) < int(costs.get("craftCard", 2)))
			m.add_button(Strings.t("camp.close"), func() -> void: m.finish(null))
			match str(await Flow.show_modal(m)):
				"forge":
					var fs := preload("res://src/scenes/ui/forge_screen.gd").new()
					fs.spend_ap = _arena_spend
					fs.ap_left = func() -> int: return int(arena["ap"])
					await Flow.show_modal(fs)
				"swap":
					await _workbench(0, int(costs.get("removeCard", costs.get("swapCard", 1))))
				"craft":
					await _workbench(int(costs.get("craftCard", 2)), 0)
			_mark_done(id)
		"rack":
			await _equipment()
		"blacksmith":
			await _blacksmith()
		"training":
			await _training()
		"merchant":
			await _merchant()
		"gate":
			await _gate()
		"home":
			_close_camp()
			_leave()


func _companions() -> void:
	var db: Dictionary = DataDB.all()
	var m := Modal.new()
	m.build(Strings.t("camp.companions"), 350)
	var members: Array = [GameState.player] + GameState.roster
	for ch in members:
		var c: Dictionary = ch
		var cid := str(c.get("id", "player"))
		if cid == "player":
			continue
		var benched := not GameState.party_ids.has(cid)
		m.add_button(Strings.t("camp.talk_to") % (Strings.t("camp.on_bench") % str(c.get("name", "?")) if benched else str(c.get("name", "?"))), func() -> void: m.finish({ "talk": c }))
		if benched:
			m.add_button(Strings.t("camp.join") % [str(c.get("name", "?")), int(Arena.checkpoint_cfg(db).get("costs", {}).get("swapTeammate", 2))], func() -> void: m.finish({ "swap": true }))
	m.add_button(Strings.t("camp.close"), func() -> void: m.finish(null))
	var r: Variant = await Flow.show_modal(m)
	if not (r is Dictionary):
		return
	if r.has("swap"):
		await _swap_teammate()
		return
	var who: Dictionary = r["talk"]
	var ctx := { "depth": int(arena.get("wave", 0)), "mutator": not arena.get("mutators", []).is_empty(),
		"downed": arena.get("lastDowned", []).has(str(who.get("id", ""))), "bestHit": str(arena.get("bestHitBy", "")) == str(who.get("id", "")) }
	var line := Camp.talk_line(db, arena, who, ctx, Rng.stream("npc"))
	if story and not arena.get("talkedAt", {}).has(str(who.get("id", ""))) and not db.get("npcs/" + str(who.get("id", "")), {}).is_empty():
		var talked: Dictionary = arena.get("talkedAt", {})
		talked[str(who.get("id", ""))] = int(arena["wave"])
		arena["talkedAt"] = talked
		preload("res://src/core/run/effects.gd").change_bond(db, GameState.run, str(who.get("id", "")), 2.0)
	await Flow.show_event({ "title": str(who.get("name", "")), "text": "\"%s\"" % line })


func _deli() -> void:
	var db: Dictionary = DataDB.all()
	if int(arena.get("stockWave", -1)) != int(arena["wave"]):
		arena["stockWave"] = int(arena["wave"])
		arena["campStock"] = Camp.stock(db, int(arena["wave"]), Arena.rng_for(arena, int(arena["wave"]), "deli"))
	while true:
		var m := Modal.new()
		m.build(Strings.t("camp.deli_title"), 400)
		m.text(Strings.t("camp.deli_hello") % [int(arena["wave"]), int(arena.get("tickets", 0))], UiTheme.DIM)
		if arena.has("meal"):
			m.text(Strings.t("camp.meal_active") % str(arena["meal"].get("name", "")), UiTheme.GOOD)
		for iid in arena.get("campStock", []):
			var it := Camp.item(db, str(iid))
			var item_id := str(iid)
			m.add_button(Strings.t("camp.buy") % [str(it.get("name", iid)), int(it.get("price", 0)), str(it.get("text", ""))], func() -> void: m.finish(item_id), int(arena.get("tickets", 0)) < int(it.get("price", 0)))
		m.add_button(Strings.t("camp.close"), func() -> void: m.finish(null))
		var pick: Variant = await Flow.show_modal(m)
		if pick == null:
			return
		var err := Camp.buy(db, arena, GameState.run, str(pick))
		if err != "":
			Narrator.say(Strings.t("camp.no_tickets") if err == "tickets" else Strings.t("merchant.backpack_full") % int(Inv.cfg(db).get("backpackSize", 6)))
			continue
		arena["campStock"].erase(str(pick))
		Audio.event("coin")
		Narrator.say(Strings.t("camp.bought") % str(Camp.item(db, str(pick)).get("name", pick)))
		_mark_done("deli")
		if bool(arena.get("dealPack", false)):
			arena.erase("dealPack")
			await _pack_pick()


## The deli's card pack: 1 of 3 cards, then who gets it.
func _pack_pick() -> void:
	var db: Dictionary = DataDB.all()
	var m := Modal.new()
	m.build(Strings.t("arena.pick_a_card"), 350)
	for id in Arena.card_offer(db, arena, Party.party(GameState.run), int(arena["wave"]) + 50):
		var cid := str(id)
		var card := preload("res://src/core/card.gd").resolve(db, cid, GameState.cards)
		m.add_button("%s: %s" % [str(card.get("name", cid)), preload("res://src/core/card.gd").describe(db, card)], func() -> void: m.finish(cid))
	var cid: Variant = await Flow.show_modal(m)
	if cid == null:
		return
	var op := preload("res://src/scenes/ui/owner_pick.gd").new()
	op.card_id = str(cid)
	op.active_ids = ["player"] + GameState.party_ids
	var who: Variant = await Flow.show_modal(op)
	if who != null:
		Arena.pick_card(db, arena, GameState.run, str(cid), str(who))


## The training ring: the Technique pick, and stat training through a minigame.
func _training() -> void:
	var db: Dictionary = DataDB.all()
	var t: Dictionary = Arena.checkpoint_cfg(db).get("training", {})
	var m := Modal.new()
	m.build(Strings.t("camp.train_title"), 380)
	m.add_button(Strings.t("camp.technique"), func() -> void: m.finish("technique"), int(arena.get("perkPicked", -1)) == int(arena["wave"]))
	for ch in Party.party(GameState.run):
		var c: Dictionary = ch
		var stats: Dictionary = c.get("stats", {})
		var low: Array = stats.keys()
		low.sort_custom(func(a: Variant, b: Variant) -> bool: return int(stats[a]) < int(stats[b]))
		for s in low.slice(0, 2):
			var stat := str(s)
			m.add_button(Strings.t("camp.train_pick") % [str(c.get("name", "?")).split(" ")[0], stat.to_upper(), int(t.get("cost", 1))], func() -> void: m.finish({ "ch": c, "stat": stat }), int(arena["ap"]) < int(t.get("cost", 1)))
	m.add_button(Strings.t("camp.close"), func() -> void: m.finish(null))
	var r: Variant = await Flow.show_modal(m)
	if str(r) == "technique":
		await _perk_pick()
		_mark_done("training")
		return
	if not (r is Dictionary):
		return
	var who: Dictionary = r["ch"]
	var pre := Camp.train(db, arena, who, str(r["stat"]), -1.0)
	if not bool(pre["ok"]):
		Narrator.say((Strings.t("camp.train_used") if pre["why"] == "used" else Strings.t("camp.train_cap")) % str(who.get("name", "?")))
		return
	# Undo the probe's bookkeeping, then play the minigame for real.
	arena["ap"] = int(arena["ap"]) + int(t.get("cost", 1))
	arena["trainedAt"].erase(str(who.get("id", "player")))
	var rec := DataDB.record("minigames", "precision")
	var mg: Control = (load(str(rec.get("script", "res://src/scenes/minigames/precision_minigame.gd"))) as GDScript).new()
	mg.set("archetype", "precision")
	mg.set("title", Strings.t("camp.train_title"))
	mg.set("hint", str(rec.get("text", "")))
	_ui.add_child(mg)
	var perf: float = await mg.finished
	var res := Camp.train(db, arena, who, str(r["stat"]), perf)
	Narrator.say(Strings.t("camp.train_done") % [str(who.get("name", "?")), str(r["stat"]).to_upper()] if int(res.get("gain", 0)) > 0 else Strings.t("camp.train_miss"))
	_mark_done("training")


## The gate: the mutator choice, the next five waves, then out into the arena.
func _gate() -> void:
	var db: Dictionary = DataDB.all()
	var costs: Dictionary = Arena.checkpoint_cfg(db).get("costs", {})
	while true:
		var m := Modal.new()
		m.build(Strings.t("camp.gate_title"), 400)
		var names: Array = []
		var w0 := int(arena["wave"]) + 1
		for w in range(w0, w0 + 5):
			names.append("%d %s" % [w, str(Arena.hazard_set(db, w, arena).get("name", "plain"))])
			if Arena.is_boss(db, w):
				m.text(Strings.t("camp.gate_boss") % w, UiTheme.BAD)
		m.text(Strings.t("camp.gate_next") % ", ".join(PackedStringArray(names)), UiTheme.DIM)
		if arena.get("mutators", []).is_empty():
			for mu in arena.get("offered", []):
				var mid := str(mu["id"])
				m.add_button("%s: %s" % [mu.get("name", mid), mu.get("text", "")], func() -> void: m.finish({ "mutator": mid }))
			m.add_button(Strings.t("arena.reroll_the_choices_ap") % int(costs.get("rerollMutators", 1)), func() -> void: m.finish("reroll"), int(arena["ap"]) < int(costs.get("rerollMutators", 1)))
		m.add_button(Strings.t("camp.gate_go") % w0, func() -> void: m.finish("go"))
		m.add_button(Strings.t("camp.close"), func() -> void: m.finish(null))
		var r: Variant = await Flow.show_modal(m)
		if r == null:
			return
		if r is Dictionary:
			Arena.choose_mutator(arena, str(r["mutator"]))
		elif str(r) == "reroll":
			if Arena.spend(db, arena, "rerollMutators"):
				Arena.offer_mutators(db, arena, int(arena.get("rerolls", 0)) + 1)
		elif str(r) == "go":
			arena["phase"] = "ready"
			_close_camp()
			_start_wave()
			return


## Arena coins: the banked money.
## The camp blacksmith (user request, Oct 29): upgrade, infuse and repair, paid
## from the arena's banked coins. Forging and commissions stay in town.
func _blacksmith() -> void:
	var s := preload("res://src/scenes/ui/smith_screen.gd").new()
	s.services = Array(Arena.checkpoint_cfg(DataDB.all()).get("blacksmithServices", ["upgrade", "infuse", "repair"]))
	s.note = Strings.t("camp.blacksmith_coins")
	var town_money := GameState.money
	GameState.money = _coins()
	await Flow.show_modal(s)
	var banked: Dictionary = arena.get("banked", {})
	banked["money"] = GameState.money
	arena["banked"] = banked
	GameState.money = town_money


func _coins() -> int:
	return int(arena.get("banked", {}).get("money", 0))


## The merchant (user request, Oct 28): relics, potions and effect items for coins.
func _merchant() -> void:
	var db: Dictionary = DataDB.all()
	var first := not bool(Journal.data.get("arena_merchant_seen", false))
	Journal.data["arena_merchant_seen"] = true
	Journal.save_journal()
	await Cutscenes.play(str(Inv.cfg(db).get("cutsceneFirst" if first else "cutscene", "")), self)
	if int(arena.get("merchantWave", -1)) != int(arena["wave"]):
		arena["merchantWave"] = int(arena["wave"])
		arena["merchantStock"] = Inv.stock(db, Arena.rng_for(arena, int(arena["wave"]), "merchant"))
	while true:
		var m := Modal.new()
		m.build(Strings.t("merchant.title"), 420)
		m.text(Strings.t("merchant.coins") % _coins(), UiTheme.ACCENT)
		var stock: Array = arena.get("merchantStock", [])
		if stock.is_empty():
			m.text(Strings.t("merchant.sold_out"), UiTheme.DIM)
		for id in stock:
			var it := Inv.item(db, str(id))
			var tag: String = { "relic": "merchant.relic_tag", "backpack": "merchant.backpack_tag", "deck": "merchant.deck_tag" }.get(Inv.needs(db, str(id)), "")
			var iid := str(id)
			m.add_button((Strings.t(tag) if tag != "" else "") + Strings.t("merchant.buy") % [str(it.get("name", id)), Inv.price(db, iid), str(it.get("text", ""))],
				func() -> void: m.finish(iid), _coins() < Inv.price(db, iid), "", iid)
		m.add_button(Strings.t("merchant.leave"), func() -> void: m.finish(null))
		var pick: Variant = await Flow.show_modal(m)
		if pick == null:
			break
		var id := str(pick)
		var who: Dictionary = GameState.player
		if Inv.needs(db, id) in ["relic", "deck"]:
			var q := Modal.new()
			q.build(Strings.t("merchant.who") % str(Inv.item(db, id).get("name", id)), 300)
			for ch in Party.party(GameState.run):
				var c: Dictionary = ch
				var worn: Array = c.get("relics", [])
				q.add_button("%s%s" % [c.get("name", "?"), (" (" + ", ".join(PackedStringArray(worn.map(func(r: Variant) -> String: return str(Inv.item(db, str(r)).get("name", r))))) + ")") if not worn.is_empty() else ""],
					func() -> void: q.finish(c))
			q.add_button(Strings.t("merchant.leave"), func() -> void: q.finish(null))
			var got: Variant = await Flow.show_modal(q)
			if got == null:
				continue
			who = got
		var err := Inv.give(db, GameState.run, who, id)
		if err == "full":
			Narrator.say(Strings.t("merchant.slots_full") % [str(who.get("name", "?")), int(Inv.cfg(db).get("relicSlots", 2))])
			continue
		if err == "backpack_full":
			Narrator.say(Strings.t("merchant.backpack_full") % int(Inv.cfg(db).get("backpackSize", 6)))
			continue
		arena["banked"]["money"] = _coins() - Inv.price(db, id)
		stock.erase(id)
		Audio.event("coin")
		Narrator.say(Strings.t("merchant.bought") % str(Inv.item(db, id).get("name", id)))
	_refresh()


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
			var rec: Dictionary = preload("res://src/core/progression/leveling.gd").techniques(db).get(str(pid), {})
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
			# AC autoplay: the cheapest meal, then train the lowest stat.
			var meals: Array = DataDB.table("arena/deli_stock").get("items", []).filter(func(it: Dictionary) -> bool: return str(it.get("kind", "")) == "meal" and int(arena["wave"]) >= int(it.get("minWave", 0)))
			meals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("price", 0)) < int(b.get("price", 0)))
			if not meals.is_empty():
				Camp.buy(db, arena, GameState.run, str(meals[0]["id"]))
			var lead: Dictionary = Party.party(GameState.run)[0]
			var st: Dictionary = lead.get("stats", {})
			var low: Array = st.keys()
			low.sort_custom(func(a: Variant, b: Variant) -> bool: return int(st[a]) < int(st[b]))
			if not low.is_empty():
				Camp.train(db, arena, lead, str(low[0]), 1.0)
			if not arena.get("offered", []).is_empty():
				# Autoplay takes the safest mutator on offer (no extra enemy HP or damage, no rest ban).
				var safest: Dictionary = arena["offered"][0]
				var best_risk := 99.0
				for m in arena["offered"]:
					var eff: Dictionary = m.get("effects", {})
					var risk := float(eff.get("enemyHpMul", 1.0)) + float(eff.get("enemyDamageMul", 1.0)) + (1.0 if bool(eff.get("noRest", false)) else 0.0)
					if risk < best_risk:
						best_risk = risk
						safest = m
				Arena.choose_mutator(arena, str(safest["id"]))
			arena["phase"] = "ready"
			_refresh()
			_autoplay()

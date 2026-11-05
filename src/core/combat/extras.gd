## Part 3c of docs/COMBAT_LAB.md: the extra mechanics, each behind its own lever.
## Every function here does nothing with its lever off. Numbers live in
## data/lab/extras.json and data/lab/gauges.json. `st` is the CombatState (untyped:
## it loads this script).
extends RefCounted

const Str := preload("res://src/core/strings.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const CardRules := preload("res://src/core/card.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")
const Board := preload("res://src/core/combat/board.gd")
const Char := preload("res://src/core/character.gd")
const DT := preload("res://src/core/data_tables.gd")
const EnemyMods := preload("res://src/core/combat/enemy_mods.gd")


static func cfg(st) -> Dictionary:
	return st.db.get("lab/extras", {})


static func _say(st, key: String, args: Array = []) -> void:
	var text: String = Str.t(st.db, key)
	st._emit({ "t": "log", "text": text % args if not args.is_empty() else text })


# --- Setup ----------------------------------------------------------------------

static func start(st, setup: Dictionary) -> void:
	var r: RefCounted = st.rules
	if r.flag("fog"):
		fill_fog(st)
	if r.flag("weather"):
		st.weather = setup.get("weather", default_weather(st))
		_say(st, "extra.weather", [str(st.weather.get("strong", "")).capitalize(), str(st.weather.get("weak", "")).capitalize()])
	if r.flag("fightWaves"):
		st.waves = setup.get("waves", []).duplicate(true)
		for w in st.waves:
			var d: Array = w.get("door", [0, 0])
			st.grid.doors[Vector2i(int(d[0]), int(d[1]))] = int(w.get("round", 1))
	if r.flag("envTimers"):
		st.env_timer = setup.get("timer", {}).duplicate(true)
		if not st.env_timer.is_empty():
			env_warn(st)
	if r.flag("bonusObjectives"):
		st.bonus_goals = pick_bonus(st)
	if r.flag("storyRelics"):
		st.relics = setup.get("labRelics", [])
		if has_relic(st, "surge_start"):
			st.add_surge("relic")
	st.mastery = setup.get("mastery", {})
	st.reserve_chars = setup.get("reserves", [])


## The strong and weak Vector: by default from the week's Upside-Down signature.
static func default_weather(st) -> Dictionary:
	var list: Array = cfg(st).get("weatherByWeek", [{ "strong": "heat", "weak": "cold" }])
	return list[clampi(int(cfg(st).get("defaultWeek", 0)), 0, list.size() - 1)]


## Levers changed mid-fight can turn these on.
static func on_levers_changed(st, changes: Dictionary) -> void:
	if changes.has("fog"):
		st.grid.fog.clear()
		if st.rules.flag("fog"):
			fill_fog(st)
	if changes.has("weather") and st.rules.flag("weather") and st.weather.is_empty():
		st.weather = default_weather(st)


static func fill_fog(st) -> void:
	var grid: GridScript = st.grid
	var listed: Array = grid.fog_layout
	if not listed.is_empty():
		for c in listed:
			grid.fog[c] = true
		return
	for c in grid.all_cells():
		if int(c.x) >= grid.cols / 2:
			grid.fog[c] = true


# --- Turn order -----------------------------------------------------------------

static func can_pick_turn(st, target: Object) -> bool:
	if not st.rules.flag("chooseOrder") or st.current == null or st.current.team != "party" or target == null or target == st.current:
		return false
	if target.team != "party" or not target.alive() or target.ai_controlled:
		return false
	return st.order.find(target) > st.turn_index


## The player picks who goes next; whoever was up keeps what they had left.
static func pick_turn(st, target: Object) -> bool:
	if not can_pick_turn(st, target):
		return false
	st.order.erase(target)
	st.order.insert(st.turn_index, target)
	st.current = target
	if target.last_turn_round != st.round_num:
		st._start_turn(target)
	_say(st, "extra.picked", [target.name])
	return true


## A Quick or Swift card moves you earlier next round; a Heavy one later.
static func card_initiative(st, u: Object, card: Dictionary) -> void:
	if not st.rules.flag("cardInitiative") or u.team != "party":
		return
	var step := int(cfg(st).get("initiativeStep", 3))
	if bool(card.get("quick", false)) or st.kw(card, "swift"):
		u.init_bonus = step
		_say(st, "extra.init_early", [u.name])
	elif st.kw(card, "heavy"):
		u.init_bonus = -step
		_say(st, "extra.init_late", [u.name])


static func can_delay(st, u: Object) -> bool:
	if not st.rules.flag("delay") or u != st.current or u.team != "party" or u.links.has("delayed_round") and int(str(u.links["delayed_round"])) == st.round_num:
		return false
	for i in range(st.turn_index + 1, st.order.size()):
		if st.order[i].team == "enemy" and st.order[i].alive():
			return true
	return false


## Pass, and act after the next enemy (once a round).
static func delay(st, u: Object) -> bool:
	if not can_delay(st, u):
		return false
	u.links["delayed_round"] = str(st.round_num)
	st.order.remove_at(st.turn_index)
	var at: int = st.turn_index
	while at < st.order.size() and not (st.order[at].team == "enemy" and st.order[at].alive()):
		at += 1
	st.order.insert(mini(at + 1, st.order.size()), u)
	st.turn_index -= 1
	_say(st, "extra.delayed", [u.name])
	st._advance()
	return true


# --- Positioning ----------------------------------------------------------------

## Facing: more from the side, most from behind.
static func facing_mul(st, u: Object, t: Object) -> float:
	if not st.rules.flag("facing") or u == t:
		return 1.0
	var d: Vector2i = u.cell - t.cell
	var dot: int = d.x * t.facing_dir.x + d.y * t.facing_dir.y
	if dot < 0:
		return st.rules.num("facingBackMul", 1.5)
	if dot == 0:
		return st.rules.num("facingSideMul", 1.25)
	return 1.0


## Extra cost of leaving each tile: zones of control and sticky ground.
static func leave_costs(st, u: Object) -> Dictionary:
	var out := {}
	for c in st.grid.sticky:
		out[c] = 1
	if st.rules.text("zoneOfControl", "off") == "extra_move" and u.team == "party":
		for e in st.units:
			if e.team == "enemy" and e.alive():
				for d in GridScript.DIRS:
					out[e.cell + d] = 1
	return out


## Walking away from an enemy's side gives it a free hit (once per enemy per move).
static func zoc_free_hit(st, u: Object, prev: Vector2i, cell: Vector2i, done: Array) -> void:
	if st.rules.text("zoneOfControl", "off") != "free_hit" or u.team != "party":
		return
	for e in st.units:
		if e.team != "enemy" or not e.alive() or done.has(e):
			continue
		if GridScript.manhattan(e.cell, prev) == 1 and GridScript.manhattan(e.cell, cell) > 1:
			done.append(e)
			for act in e.actions:
				var spec: Dictionary = st.action_spec(e, act)
				if not bool(spec.get("heal", false)):
					_say(st, "extra.free_hit", [e.name, u.name])
					st._hit_unit(e, u, spec, false)
					break


static func high_range(st, u: Object) -> int:
	return st.rules.count("highRange", 1) if st.rules.flag("highGround") and st.grid.high.has(u.cell) else 0


static func high_bonus(st, u: Object, t: Object) -> float:
	if st.rules.flag("highGround") and st.grid.high.has(u.cell) and not st.grid.high.has(t.cell):
		return float(st.rules.count("highDamage", 1))
	return 0.0


## Pushed off a raised tile: a fall.
static func high_fall(st, t: Object, from: Vector2i) -> void:
	if st.rules.flag("highGround") and st.grid.high.has(from) and not st.grid.high.has(t.cell) and t.alive():
		_say(st, "extra.high_fall", [t.name])
		st._damage(t, st.rules.count("fallDamage", 2), null, "", "fall")


## Line of sight: walls, crates and Constructs block spells.
static func los_filter(st, u: Object, cells: Array) -> Array:
	if not st.rules.flag("lineOfSight"):
		return cells
	var blockers: Dictionary = st.sight_blockers().duplicate()
	for p in st.units:
		if p.is_prop() and not p.dead:
			blockers[p.cell] = true
	return cells.filter(func(c: Vector2i) -> bool: return st.grid.has_los(u.cell, c, blockers))


## Fog: an enemy's plan is hidden until something lights it.
static func plan_hidden(st, u: Object) -> bool:
	if not st.rules.flag("fog") or u.team != "enemy" or st.revealed > 0:
		return false
	if not st.grid.fog.has(u.cell) or st.grid.lit.has(u.cell):
		return false
	for o in st.units:
		if o.team == "party" and o.alive() and GridScript.manhattan(o.cell, u.cell) == 1:
			return false
	return true


# --- Spells and Vectors ---------------------------------------------------------

static func charging(st, card: Dictionary) -> bool:
	return st.rules.flag("chargeSpells") and st.kw(card, "charge")


## A Charge card fires at the start of your next turn, a Magnitude higher.
static func start_charge(st, u: Object, card: Dictionary, target: Vector2i) -> void:
	var cells: Array = st.effect_cells(u, card, target)
	st.charges.append({ "unit": u.id, "card": st._surge_card(card), "target": target, "cells": cells })
	st._emit({ "t": "telegraph", "cells": cells, "name": str(card.get("name", "")) })
	_say(st, "extra.charging", [u.name, str(card.get("name", ""))])


static func fire_charges(st, u: Object) -> void:
	for ch in st.charges.duplicate():
		if str(ch["unit"]) != u.id:
			continue
		st.charges.erase(ch)
		_say(st, "extra.fires", [u.name, str(ch["card"].get("name", ""))])
		st._cast(u, ch["card"], ch["target"], false, 0, u.mp)


static func linger(st, u: Object, v: Dictionary, cells: Array) -> void:
	if not st.rules.flag("lingeringFields") or cells.is_empty():
		return
	var grid: GridScript = st.grid
	var rounds: int = st.rules.count("fieldRounds", 3)
	for c in cells:
		if grid.get_terrain(c) == GridScript.WALL:
			continue
		if v.has("heat") and grid.walkable_terrain(c):
			grid.burning[c] = rounds
		if v.has("cold") and grid.get_terrain(c) == GridScript.FLOOR:
			grid.set_terrain(c, GridScript.ICE)
			grid.field_ice[c] = rounds
		if v.has("binding") and grid.walkable_terrain(c):
			grid.sticky[c] = rounds
		if v.has("light"):
			grid.lit[c] = rounds
			var o: Object = st.unit_at(c)
			if o != null:
				st.unhide(o)
		if v.has("force") and grid.walkable_terrain(c):
			grid.cracks[c] = int(grid.cracks.get(c, 0)) + 1
			if int(grid.cracks[c]) >= int(cfg(st).get("cracksToPit", 2)):
				grid.cracks.erase(c)
				grid.set_terrain(c, GridScript.PIT)
				st._emit({ "t": "tiles", "kind": "pit", "cells": [c] })
				_say(st, "board.collapse")
				var t: Object = st.unit_at(c)
				if t != null and t.alive():
					st._fall(t)
	st._emit({ "t": "tiles", "kind": "field", "cells": cells })


static func tick_fields(st) -> void:
	var grid: GridScript = st.grid
	for c in grid.field_ice.keys():
		grid.field_ice[c] = int(grid.field_ice[c]) - 1
		if int(grid.field_ice[c]) <= 0:
			grid.field_ice.erase(c)
			if grid.get_terrain(c) == GridScript.ICE:
				grid.set_terrain(c, GridScript.FLOOR)
	for c in grid.sticky.keys():
		grid.sticky[c] = int(grid.sticky[c]) - 1
		if int(grid.sticky[c]) <= 0:
			grid.sticky.erase(c)


## A spell's Magnitude under the fight's weather.
static func weather_card(st, card: Dictionary) -> Dictionary:
	if not st.rules.flag("weather") or st.weather.is_empty() or not card.has("magnitude"):
		return card
	var v: Dictionary = card.get("vectors", {})
	var step := 0
	if v.has(str(st.weather.get("strong", ""))):
		step = st.rules.count("weatherBonus", 1)
	elif v.has(str(st.weather.get("weak", ""))):
		step = st.rules.count("weatherMalus", -1)
	if step == 0:
		return card
	var mags: Array = st.db.get("vectors", {}).get("magnitudeOrder", [])
	var out := card.duplicate()
	out["magnitude"] = str(mags[clampi(mags.find(str(card["magnitude"])) + step, 0, mags.size() - 1)])
	return out


## Overload: pay HP or Exhaust a card to cast one Magnitude above what you can afford.
static func can_overload(st, u: Object, card: Dictionary, hand_index: int = -1) -> bool:
	var mode: String = st.rules.text("overload", "off")
	if mode == "off" or not CardRules.is_spell(card) or not card.has("magnitude"):
		return false
	var mags: Array = st.db.get("vectors", {}).get("magnitudeOrder", [])
	var at := mags.find(str(card["magnitude"]))
	var lower := card.duplicate()
	lower["magnitude"] = str(mags[maxi(0, at - 1)])
	if st.card_cost(u, lower) > u.mp:
		return false
	var hp_ok: bool = u.hp > st.rules.count("overloadHp", 3)
	var card_ok: bool = u.deck != null and u.deck.hand.size() >= 2
	match mode:
		"hp":
			return hp_ok
		"exhaust":
			return card_ok
	return hp_ok or card_ok


## Returns the card's hand index afterward (Exhausting another card can shift it).
static func pay_overload(st, u: Object, hand_index: int) -> int:
	var mode: String = st.rules.text("overload", "off")
	var hp_ok: bool = u.hp > st.rules.count("overloadHp", 3)
	if mode == "hp" or (mode == "both" and hp_ok):
		u.hp -= st.rules.count("overloadHp", 3)
		st._emit({ "t": "damage", "unit": u.id, "amount": st.rules.count("overloadHp", 3), "absorbed": 0, "crit": false, "high": false, "vector": "", "cause": "overload", "source": u.id, "note": "", "toParty": true, "telegraphed": false })
		_say(st, "extra.overload_hp", [u.name])
		return hand_index
	var i: int = u.deck.hand.size() - 1
	if i == hand_index:
		i -= 1
	var id: Variant = u.deck.hand[i]
	u.deck.hand.remove_at(i)
	u.deck.exhausted.append(id)
	_say(st, "extra.overload_card", [u.name])
	return hand_index - 1 if i < hand_index else hand_index


## Two different allies hit the same tile with different Vectors in a round.
static func ally_hit(st, u: Object, cell: Vector2i, vector: String) -> void:
	if not st.rules.flag("allyReactions") or u == null or u.team != "party" or vector == "":
		return
	var list: Array = st.reaction_hits.get(cell, [])
	for prior in list:
		if str(prior["unit"]) != u.id and str(prior["vector"]) != vector:
			var pair := [str(prior["vector"]), vector]
			pair.sort()
			var rec: Dictionary = st.db.get("lab/reactions", {}).get("allyCombos", {}).get("+".join(PackedStringArray(pair)), {})
			if not rec.is_empty():
				st.reaction_hits.erase(cell)
				_fire_ally(st, u, cell, rec)
				return
	list.append({ "unit": u.id, "vector": vector })
	st.reaction_hits[cell] = list


static func _fire_ally(st, u: Object, cell: Vector2i, rec: Dictionary) -> void:
	var nm := str(rec.get("name", "Reaction"))
	if not st.combos_cast.has(nm):
		st.combos_cast.append(nm)
	st._emit({ "t": "combo", "unit": u.id, "id": nm, "name": nm, "text": str(rec.get("text", "")) })
	st.add_surge("combo")
	for op in rec.get("ops", []):
		if str(op.get("op", "")) == "hit":
			var t: Object = st.unit_at(cell)
			if t != null and t.alive():
				st._damage(t, st.rules.flat(float(op.get("n", 2))), u, "", "reaction")
		else:
			Board.apply(st, u, op, cell)


# --- Cards and decks ------------------------------------------------------------

## A card after in-fight upgrades and mastery: its "+" version.
static func upgraded(st, u: Object, card: Dictionary) -> Dictionary:
	var id := str(card.get("id", ""))
	var plus := false
	if st.rules.flag("fightUpgrade") and int(st.card_plays.get(id, 0)) >= st.rules.count("fightUpgradeAt", 3):
		plus = true
	if st.rules.flag("cardMastery") and int(st.mastery.get(id, 0)) >= st.rules.count("masteryUses", 10):
		plus = true
	if not plus:
		return card
	var out: Dictionary = CardRules.upgraded(card) if card.has("upgrade") else st._surge_card(card)
	out = out.duplicate()
	if not str(out.get("name", "")).ends_with("+"):
		out["name"] = str(out.get("name", "")) + "+"
	return out


static func note_play(st, u: Object, id: String) -> void:
	st.card_plays[id] = int(st.card_plays.get(id, 0)) + 1
	if st.rules.flag("fightUpgrade") and int(st.card_plays[id]) == st.rules.count("fightUpgradeAt", 3):
		_say(st, "extra.upgraded", [str(CardRules.resolve(st.db, id, st.library).get("name", id))])
	if st.rules.flag("cardMastery"):
		st.mastery[id] = int(st.mastery.get(id, 0)) + 1
		if int(st.mastery[id]) == st.rules.count("masteryUses", 10):
			_say(st, "extra.mastered", [str(CardRules.resolve(st.db, id, st.library).get("name", id))])


## Some enemy attacks shuffle a junk card into your deck.
static func status_card(st, act: Dictionary, t: Object) -> void:
	if not st.rules.flag("statusCards") or not act.has("addsStatusCard") or t.team != "party" or t.deck == null or t.is_prop():
		return
	var id := str(act["addsStatusCard"])
	t.deck.draw_pile.insert(st.rng.randi_range(0, t.deck.draw_pile.size()), id)
	_say(st, "extra.status_card", [t.name, str(CardRules.resolve(st.db, id, st.library).get("name", id))])


## Junk cards do their thing when drawn.
static func on_drawn(st, u: Object, drawn: Array) -> void:
	for id in drawn:
		var c := CardRules.resolve(st.db, str(id), st.library)
		match str(c.get("whenDrawn", "")):
			"discard":
				var others: Array = u.deck.hand.filter(func(h: Variant) -> bool: return str(h) != str(id))
				if not others.is_empty():
					var drop: Variant = others[st.rng.randi_range(0, others.size() - 1)]
					u.deck.hand.erase(drop)
					u.deck.discard.append(drop)
				_say(st, "extra.fear", [u.name])
			"hurt":
				st._damage(u, 1, null, "", "status_card")
				_say(st, "extra.burned", [u.name])


## A character's one unique card, always in the opening hand.
static func add_signature(st, u: Object) -> void:
	if not st.rules.flag("signatureCard") or u.deck == null:
		return
	var table: Dictionary = st.db.get("cards/signature_cards", {}).get("signatures", {})
	var id := str(table.get(u.id, table.get(str(u.source.get("class", "")), "")))
	if id != "":
		u.deck.hand.append(id)
		u.deck.hand_limit += 1


## A duet needs its two characters next to each other (and, in the story, the Bond).
static func duet_block(st, u: Object, card: Dictionary) -> String:
	if not card.has("duet"):
		return ""
	if not st.rules.flag("duetCards"):
		return Str.t(st.db, "extra.duet_off")
	var need: Array = card["duet"]
	var mine := str(u.source.get("class", ""))
	for a in st.allies_of(u):
		if a == u or GridScript.manhattan(a.cell, u.cell) != 1:
			continue
		var theirs := str(a.source.get("class", ""))
		if (need.has(mine) and need.has(theirs) and mine != theirs) or (need.has(u.id) and need.has(a.id)):
			if st.lab_log == null and float(u.source.get("partyBonds", {}).get(a.id, 0)) < bond_min(st, st.rules.text("duetBond", "Close")):
				return Str.t(st.db, "extra.duet_bond")
			return ""
	return Str.t(st.db, "extra.duet_needs") % ", ".join(PackedStringArray(need))


static func bond_min(st, tier: String) -> float:
	for t in st.db.get("bonds", {}).get("tiers", []):
		if str(t.get("name", "")) == tier:
			return float(t.get("min", 0))
	return 0.0


static func on_reshuffle(st, u: Object) -> void:
	match st.rules.text("reshuffleEffect", "none"):
		"surge":
			st.add_surge("reshuffle")
		"hp_cost":
			_say(st, "extra.reshuffle_hurt", [u.name])
			st._damage(u, 1, null, "", "status_card")


# --- Enemies --------------------------------------------------------------------

## Role tags from the fight's data: only with the lever on.
static func apply_role(st, rec: Dictionary) -> Dictionary:
	if not st.rules.flag("enemyRoles") or str(rec.get("labRole", "")) == "":
		return rec
	var out := rec.duplicate(true)
	var role: Dictionary = cfg(st).get("roles", {}).get(str(rec["labRole"]), {})
	for k in role:
		out[k] = role[k]
	out["name"] = "%s (%s)" % [str(out.get("name", "")), str(rec["labRole"]).capitalize()]
	return out


static func role_of(st, t: Object) -> String:
	return str(t.source.get("labRole", "")) if st.rules.flag("enemyRoles") else ""


## A Bomber goes off when pushed or killed, and an Anchor stops pushes next to it.
static func bomber_pushed(st, u: Object, t: Object) -> void:
	if role_of(st, t) == "bomber" and t.alive():
		_say(st, "extra.bomber_pushed", [t.name])
		t.hp = 0
		st._last_cause = "explosion"
		st._on_zero_hp(t, u)


static func bomber_died(st, t: Object) -> void:
	if role_of(st, t) == "bomber":
		Board.explode(st, null, t.cell, st.rules.flat(float(cfg(st).get("bomberDamage", 3))))


static func anchor_stops(st, t: Object, cell: Vector2i) -> bool:
	if not st.rules.flag("enemyRoles"):
		return false
	for e in st.units:
		if e != t and e.alive() and role_of(st, e) == "anchor" and GridScript.manhattan(e.cell, cell) == 1:
			return true
	return false


## The marked side: "back" (behind its facing) or "side".
static func weak_from(st, u: Object, t: Object) -> bool:
	if not st.rules.flag("weakPoints") or u == null or u == t:
		return false
	var side := str(t.source.get("weakPoint", ""))
	if side == "":
		return false
	var d: Vector2i = u.cell - t.cell
	var dot: int = d.x * t.facing_dir.x + d.y * t.facing_dir.y
	return dot < 0 if side == "back" else dot == 0


## The tiles to hit a unit's weak point from, for the field.
static func weak_cells(st, t: Object) -> Array:
	if not st.rules.flag("weakPoints"):
		return []
	var side := str(t.source.get("weakPoint", ""))
	if side == "back":
		return [t.cell - t.facing_dir]
	if side == "side":
		var perp := Vector2i(t.facing_dir.y, t.facing_dir.x)
		return [t.cell + perp, t.cell - perp]
	return []


static func on_hit(st, u: Object, t: Object) -> void:
	if weak_from(st, u, t) and t.alive() and u.team != t.team:
		_say(st, "extra.weak_point", [t.name])
		if not t.intent.is_empty():
			st._note_cancel(t)
		t.intent = {}
		t.links["staggered"] = "1"
		st._emit({ "t": "status", "unit": t.id, "status": "dazed" })


static func on_enemy_death(st, t: Object) -> void:
	bomber_died(st, t)
	if st.rules.flag("morale"):
		for e in st.units:
			if e == t or e.team != "enemy" or not e.alive() or e.boss or bool(e.source.get("mindless", false)):
				continue
			if GridScript.manhattan(e.cell, t.cell) <= st.rules.count("moraleRadius", 2) and st.rng.randf() < float(cfg(st).get("panicChance", 0.5)):
				_panic(st, e)
	if has_relic(st, "kill_heal") and st.current != null and st.current.team == "party":
		st._heal(st.current, st.current, 1, false)


static func _panic(st, e: Object) -> void:
	var best: Vector2i = e.cell
	var far := -1
	var reach: Dictionary = st.grid.reachable(e.cell, e.movement, st.occupied(e))
	for c in reach:
		var d := 99
		for o in st.opponents_of(e):
			d = mini(d, GridScript.manhattan(o.cell, c))
		if d > far:
			far = d
			best = c
	e.intent = { "kind": "move", "move": best, "cells": [] }
	_say(st, "extra.panic", [e.name])


## A boss's plan after this one, shown faded (bossLookahead 2).
static func plan_ahead(st, u: Object) -> void:
	if not u.boss or st.rules.count("bossLookahead", 1) < 2:
		return
	u.turns_taken += 1
	var kept: Dictionary = u.intent
	u.intent_next = st._ai_script().plan_intent(st, u)
	u.intent = kept
	u.turns_taken -= 1


static func faded_cells(st) -> Array:
	var out: Array = []
	for u in st.units:
		if u.boss and u.alive():
			out.append_array(u.intent_next.get("cells", []))
	return out


# --- Party ----------------------------------------------------------------------

static func carry(st) -> bool:
	return st.rules.text("downedRules", "current") == "carry"


## Drag a downed ally one tile with your Move.
static func can_drag(st, u: Object, t: Object) -> bool:
	return carry(st) and u == st.current and t != null and t.downed and not t.dead and t.team == u.team and GridScript.manhattan(u.cell, t.cell) == 1 and u.move_left > 0


static func drag(st, u: Object, t: Object, cell: Vector2i) -> bool:
	if not can_drag(st, u, t) or GridScript.manhattan(t.cell, cell) != 1 or st.unit_at(cell) != null or not st.grid.walkable_terrain(cell):
		return false
	var from: Vector2i = t.cell
	t.cell = cell
	u.move_left = 0
	st._emit({ "t": "push", "unit": t.id, "from": from, "to": cell })
	_say(st, "extra.dragged", [u.name, t.name])
	return true


static func can_bring_reserve(st) -> bool:
	return st.rules.flag("reserves") and st.reserve_used < st.rules.count("reserveUses", 1) and not st.reserve_chars.is_empty() and st.current != null and st.current.team == "party"


## A benched member comes in at an edge tile in place of a downed or chosen ally. Their turn is spent.
static func bring_reserve(st, out_unit: Object) -> bool:
	if not can_bring_reserve(st) or out_unit == null or out_unit.team != "party" or out_unit.is_player:
		return false
	st.reserve_used += 1
	var ch: Dictionary = st.reserve_chars[0]
	st.reserve_chars = st.reserve_chars.slice(1)
	var u: Object = UnitScript.from_character(st.db, ch, st.rng)
	st._party_levers(u)
	u.deck.hand_limit = st.hand_size(u)
	u.deck.draw(st.hand_size(u), st.rng)
	var spot := Vector2i(-1, -1)
	for c in st.grid.all_cells():
		if int(c.x) == 0 and st.grid.walkable_terrain(c) and st.unit_at(c) == null:
			spot = c
			break
	u.cell = spot if spot.x >= 0 else st._free_near(out_unit.cell)
	out_unit.dead = true
	out_unit.out = true
	st._emit({ "t": "vanish", "unit": out_unit.id, "cell": out_unit.cell })
	st._add_unit(u)
	st._emit({ "t": "spawn", "unit": u.id, "cell": u.cell, "prop": false })
	u.last_turn_round = st.round_num
	_say(st, "extra.reserve", [u.name, out_unit.name])
	return true


## Bonded neighbors share one free Quick a round.
static func bond_quick(st, u: Object, spend: bool) -> bool:
	if not st.rules.flag("bondInCombat") or u.team != "party":
		return false
	var need := bond_min(st, st.rules.text("bondTier", "Close"))
	for a in st.allies_of(u):
		if a == u or GridScript.manhattan(a.cell, u.cell) != 1:
			continue
		if float(u.source.get("partyBonds", {}).get(a.id, 0)) < need:
			continue
		var pair: String = st._pair_key(u, a)
		if not st.bond_quicks.has(pair):
			if spend:
				st.bond_quicks[pair] = true
				_say(st, "extra.bond_quick", [u.name, a.name])
			return true
	return false


static func gauge_rec(st, u: Object) -> Dictionary:
	return st.db.get("lab/gauges", {}).get("gauges", {}).get(str(u.source.get("class", "")), {})


static func gauge_add(st, u: Object, n: int = 1) -> void:
	if u == null or u.team != "party" or u.is_prop():
		return
	var rec := gauge_rec(st, u)
	if rec.is_empty() or int(str(u.links.get("gauge_lock", "-1"))) >= st.round_num:
		return
	u.gauge = mini(int(rec.get("max", 5)), u.gauge + n)


static func gauge_full(st, u: Object) -> bool:
	return st.rules.flag("classGauges") and not gauge_rec(st, u).is_empty() and u.gauge >= int(gauge_rec(st, u).get("max", 5))


## Spend a full meter: each class has one effect (data/lab/gauges.json).
static func spend_gauge(st, u: Object) -> bool:
	if not gauge_full(st, u) or u != st.current:
		return false
	var rec := gauge_rec(st, u)
	_say(st, "extra.gauge_spent", [u.name, str(rec.get("name", ""))])
	match str(rec.get("spend", "")):
		"shove_all":
			for o in st.opponents_of(u):
				if GridScript.manhattan(o.cell, u.cell) == 1:
					st._push(u, o, o.cell - u.cell, int(rec.get("steps", 1)))
		"overheat":
			u.links["overheat"] = "1"
			u.links["gauge_lock"] = str(st.round_num + 1)
		"reposition":
			u.move_left += int(rec.get("tiles", 3))
			u.links["back_hit"] = "1"
		"shield_or_revive":
			var best: Object = null
			var revived := false
			for a in st.allies_of(u, true):
				if a.downed and GridScript.manhattan(a.cell, u.cell) == 1 and not revived:
					st._heal(u, a, int(rec.get("revive", 3)), false)
					revived = true
				if best == null or a.hp_ratio() < best.hp_ratio():
					best = a
			if best != null and not revived:
				best.shield += int(rec.get("shield", 3))
				best.shield_turns = maxi(best.shield_turns, 2)
				st._emit({ "t": "shield", "unit": best.id, "amount": int(rec.get("shield", 3)) })
		"extra_action":
			for a in st.allies_of(u):
				if a != u:
					a.links["extra_action"] = "1"
					_say(st, "extra.tempo", [a.name])
					break
	# Spending never fills the meter it came from.
	u.gauge = 0
	return true


## Every event: gauges, bonus goal counters.
static func observe(st, e: Dictionary) -> void:
	var t := str(e.get("t", ""))
	if st.rules.flag("bonusObjectives"):
		match t:
			"board_kill":
				st.bonus_counts["board"] = int(st.bonus_counts.get("board", 0)) + 1
			"combo":
				st.bonus_counts["combo"] = int(st.bonus_counts.get("combo", 0)) + 1
			"down":
				st.bonus_counts["down"] = int(st.bonus_counts.get("down", 0)) + 1
			"damage":
				if bool(e.get("toParty", false)) and bool(e.get("telegraphed", false)):
					st.bonus_counts["telegraphHit"] = int(st.bonus_counts.get("telegraphHit", 0)) + 1
	if not st.rules.flag("classGauges"):
		return
	var cur: Object = st.current
	if cur == null or cur.team != "party":
		return
	var cls := str(cur.source.get("class", ""))
	match t:
		"push", "collide":
			if cls == "fighter":
				gauge_add(st, cur)
		"cast":
			if cls == "mage":
				gauge_add(st, cur)
			elif cls == "bard":
				for id in st.chain:
					if st.chain[id].size() > 0:
						gauge_add(st, cur)
						break
		"heal", "shield":
			if cls == "healer":
				gauge_add(st, cur)


## End of round: Rogues who weren't targeted build Shadow.
static func gauges_round(st) -> void:
	if not st.rules.flag("classGauges"):
		return
	for u in st.units:
		if u.team == "party" and u.alive() and str(u.source.get("class", "")) == "rogue":
			var aimed := false
			for e in st.units:
				if e.team == "enemy" and str(e.intent.get("unit", "")) == u.id:
					aimed = true
			if not aimed:
				gauge_add(st, u)


# --- Fight structure ------------------------------------------------------------

static func waves_tick(st) -> void:
	for w in st.waves.duplicate():
		var door: Vector2i = Vector2i(int(w["door"][0]), int(w["door"][1]))
		if st.round_num == int(w["round"]) - 1:
			st._emit({ "t": "telegraph", "cells": [door], "name": "Door" })
			_say(st, "extra.door_warn")
		if st.round_num >= int(w["round"]):
			st.waves.erase(w)
			st.grid.doors.erase(door)
			if st.unit_at(door) != null:
				_say(st, "extra.door_blocked", [st.unit_at(door).name])
				continue
			var index: Dictionary = DT.index_under(st.db, "enemies/", "enemies")
			for id in w.get("enemies", []):
				var rec: Dictionary = index.get(str(id), {})
				if rec.is_empty():
					continue
				var s: Object = UnitScript.from_enemy(EnemyMods.apply(st.db, rec), 1.0)
				st._scale_enemy(s)
				s.cell = door if st.unit_at(door) == null else st._free_near(door)
				s.role = "fighter"
				st._add_unit(s)
				st._emit({ "t": "spawn", "unit": s.id, "cell": s.cell, "prop": false })
			_say(st, "extra.door_opens")
			st._build_order_keep_current()


static func pick_bonus(st) -> Array:
	var pool: Array = st.db.get("lab/bonus_goals", {}).get("goals", []).duplicate()
	var out: Array = []
	var seeded := RandomNumberGenerator.new()
	seeded.seed = int(st.round_seed)
	for i in mini(st.rules.count("bonusCount", 2), pool.size()):
		out.append(pool.pop_at(seeded.randi_range(0, pool.size() - 1)))
	return out


## Which optional goals were met, when the fight ended.
static func bonus_results(st) -> Array:
	var out: Array = []
	for g in st.bonus_goals:
		var n := int(g.get("n", 1))
		var done := false
		match str(g.get("check", "")):
			"no_down":
				done = int(st.bonus_counts.get("down", 0)) == 0
			"rounds":
				done = st.round_num <= n
			"board":
				done = int(st.bonus_counts.get("board", 0)) >= n
			"combo":
				done = int(st.bonus_counts.get("combo", 0)) >= n
			"no_telegraph":
				done = int(st.bonus_counts.get("telegraphHit", 0)) == 0
		out.append({ "id": str(g.get("id", "")), "text": str(g.get("text", "")), "done": done and st.result == "win" })
	return out


static func env_warn(st) -> void:
	var grid: GridScript = st.grid
	var timer: Dictionary = st.env_timer
	grid.env_warn.clear()
	match str(timer.get("type", "")):
		"rising_water":
			var row := int(timer.get("row", grid.rows - 1))
			for c in grid.all_cells():
				if int(c.y) == row and grid.walkable_terrain(c):
					grid.env_warn.append(c)
		"collapsing_floor":
			var pool: Array = grid.all_cells().filter(func(c: Vector2i) -> bool: return grid.walkable_terrain(c) and st.unit_at(c) == null)
			for i in mini(int(timer.get("tiles", 2)), pool.size()):
				grid.env_warn.append(pool.pop_at(st.rng.randi_range(0, pool.size() - 1)))
		"spreading_fire":
			var col := int(timer.get("col", grid.cols - 1))
			for c in grid.all_cells():
				if int(c.x) == col and grid.walkable_terrain(c):
					grid.env_warn.append(c)


## The board clock moves at round end: warned tiles turn, new ones are warned.
static func env_tick(st) -> void:
	var timer: Dictionary = st.env_timer
	if timer.is_empty():
		return
	var grid: GridScript = st.grid
	match str(timer.get("type", "")):
		"rising_water":
			for c in grid.env_warn:
				grid.set_terrain(c, GridScript.WATER)
				var t: Object = st.unit_at(c)
				if t != null and t.alive():
					t.cell = st._free_near(c)
					st._damage(t, 1, null, "", "fall")
			_say(st, "extra.water_rises")
			timer["row"] = int(timer.get("row", grid.rows - 1)) - 1
			if int(timer["row"]) < int(timer.get("stopRow", 1)):
				grid.env_warn.clear()
				st.env_timer = {}
				return
		"collapsing_floor":
			for c in grid.env_warn:
				grid.collapsing[c] = 1
			_say(st, "extra.floor_goes")
		"spreading_fire":
			for c in grid.env_warn:
				grid.burning[c] = 99
			_say(st, "extra.fire_spreads")
			timer["col"] = int(timer.get("col", grid.cols - 1)) - 1
			if int(timer["col"]) < int(timer.get("stopCol", 1)):
				grid.env_warn.clear()
				st.env_timer = {}
				return
	env_warn(st)


# --- Rewards --------------------------------------------------------------------

static func has_relic(st, id: String) -> bool:
	return st.rules.flag("storyRelics") and st.relics.has(id)


## After a win: three new cards to pick from.
static func post_fight_cards(db: Dictionary, rng: RandomNumberGenerator, n: int = 3) -> Array:
	var pool: Array = db.get("cards/lab_cards", {}).get("cards", []).filter(func(c: Dictionary) -> bool: return not bool(c.get("unplayable", false)))
	var out: Array = []
	for i in mini(n, pool.size()):
		out.append(str(pool.pop_at(rng.randi_range(0, pool.size() - 1)).get("id", "")))
	return out


# --- Labels ---------------------------------------------------------------------

## What's active right now, in a few words, for the HUD.
static func active_line(st) -> String:
	var parts: Array = []
	if st.rules.flag("weather") and not st.weather.is_empty():
		parts.append(Str.t(st.db, "extra.tag_weather") % [str(st.weather.get("strong", "")).capitalize(), str(st.weather.get("weak", "")).capitalize()])
	if not st.env_timer.is_empty():
		parts.append(Str.t(st.db, "extra.tag_timer_" + str(st.env_timer.get("type", ""))))
	for g in st.bonus_goals:
		parts.append(str(g.get("text", "")))
	for s in st.db.get("lab/lab", {}).get("levers", []):
		if str(s.get("tag", "")) != "" and st.rules.v(str(s["id"])) != s["default"] and str(st.rules.v(str(s["id"]))) != "off":
			parts.append(str(s["tag"]))
	return "  ".join(PackedStringArray(parts))


## Plain-words lines for pushes ("Brick pushed the Ghoul into the pit.").
static func plain_push(st, u: Object, t: Object, how: String) -> void:
	if st.rules.flag("plainLog") and u != null and u != t:
		_say(st, "extra.push_" + how, [u.name, t.name])

## Combat 2.0 fight state (docs/COMBAT_2.md Parts 1 to 3): a shared timeline by
## Initiative; each turn is a Move, then one Ability (a class move, a spell or the
## ultimate), plus one free item. Hitting a weakness knocks an enemy down and
## gives One More, which can be passed to an ally (Baton Pass). With every enemy
## down, the party may launch an All-Out Attack. Built on CombatState, so the grid,
## board, props, pushes, pits, collisions and the Vector reactions table carry over.
## Every open question is a lever in data/combat2/rules.json (c2_rules.gd).
extends "res://src/core/combat/combat_state.gd"

const C2Rules := preload("res://src/core/combat2/c2_rules.gd")
const Kits := preload("res://src/core/combat2/kits.gd")
const Shapes := preload("res://src/core/combat2/shapes.gd")
const Perks := preload("res://src/core/combat2/perks.gd")

var c2: C2Rules = null               # the C2 levers
var c2_setup: Dictionary = {}
var kits: Dictionary = {}             # unit id -> kit (Kits.build), enemies too
var cooldowns: Dictionary = {}        # unit id -> { ability uid -> own turns left }
var charges_left: Dictionary = {}     # unit id -> { spell uid -> charges }
var meter: Dictionary = {}            # unit id -> ultimate meter
var known_marks: Dictionary = {}      # enemy kind -> { type -> "weak"/"resist"/"immune" }
var backpack_c2: Array = []           # item ids the party carries (shared)
var one_more: Dictionary = {}         # { unit } while an extra Ability is waiting
var one_mores_turn := 0
var all_out_ready := false
var boss_plans: Dictionary = {}       # boss id -> { uid, cells, name }: big attacks marked a turn ahead
var tally: Dictionary = {}            # counts for the Lab metrics
var used_free_spell: Dictionary = {}  # unit id -> true once Warm-Up was spent
var protect_used: Dictionary = {}     # unit id -> true once their Protect fired
var first_hits: Dictionary = {}       # "attacker|enemy" -> true (reveal on first hit)
var acted: Dictionary = {}            # unit id -> used an Ability this turn
var items_turn := 0
var big_counter: Dictionary = {}      # boss id -> own turns since its last big attack
var _deferred := true
var _previewing := false


func _init(p_db: Dictionary, p_rng: RandomNumberGenerator, setup: Dictionary) -> void:
	c2_setup = setup
	c2 = C2Rules.build(p_db, setup.get("c2Levers", {})) as C2Rules
	var base := setup.duplicate()
	base["party"] = []
	base["enemies"] = []
	base["preset"] = C2Rules.base_preset(p_db)
	var lab := C2Rules.lab_levers(p_db)
	lab.merge(setup.get("labLevers", {}), true)
	base["levers"] = lab
	base.erase("lab")
	super(p_db, p_rng, base)
	_c2_start()


func _c2_start() -> void:
	tally = { "knockdowns": 0, "oneMores": 0, "batons": 0, "allOuts": 0, "spells": 0, "charges": 0, "moves": {}, "enemyAttacks": 0, "enemyHits": 0,
		"enemyDamage": 0, "partyDamage": 0, "ultimates": 0, "followUps": 0, "protects": 0, "braces": 0, "items": 0, "partyKnocked": 0, "weakHits": 0 }
	known_marks = (c2_setup.get("known", {}) as Dictionary).duplicate(true)
	backpack_c2 = (c2_setup.get("items", []) as Array).duplicate()
	var carry: Dictionary = c2_setup.get("carry", {})
	var party: Array = c2_setup.get("party", [])
	for i in party.size():
		var kit: Dictionary = party[i]
		var u := _party_unit(kit)
		_place(u, grid.party_spawns, i, true)
		_join(u, kit)
		var c: Dictionary = carry.get(u.id, {})
		if c.has("hp"):
			u.hp = clampi(int(c["hp"]), 0, u.max_hp)
			if u.hp <= 0:
				u.hp = 1
		for uid in c.get("charges", {}):
			if charges_left[u.id].has(uid):
				charges_left[u.id][uid] = int(c["charges"][uid])
	var lvl := int(c2_setup.get("level", 1))
	var enemies: Array = c2_setup.get("enemies", [])
	for i in enemies.size():
		var u := _enemy_unit(str(enemies[i]), lvl)
		if u == null:
			continue
		_place(u, grid.enemy_spawns, i, false)
		_join(u, kits[u.id] if kits.has(u.id) else _enemy_kit(u))
	round_num = 1
	_deferred = false
	_build_order()
	turn_index = -1
	_advance()


func _party_unit(kit: Dictionary) -> UnitScript:
	var u := UnitScript.new()
	u.id = str(kit["char"])
	u.name = str(kit.get("name", u.id))
	u.team = "party"
	var st: Dictionary = kit.get("stats", {})
	u.max_hp = maxi(1, roundi(float(st.get("hp", 20))))
	u.hp = u.max_hp
	u.movement = maxi(1, roundi(float(st.get("movement", 3))))
	u.initiative = roundi(float(st.get("agility", 5)))
	u.stats = { "power": float(st.get("power", 3)), "magic": float(st.get("magic", 3)) }
	u.source = { "name": u.name, "class": str(kit.get("class", "")), "c2": true }
	var key := str(kit.get("sprite", ""))
	u.sprite = str(db.get("assets/roles", {}).get(key, key))
	u.facing = 1
	u.facing_dir = Vector2i(1, 0)
	return u


func _enemy_unit(id: String, level: int) -> UnitScript:
	var rec := Kits.rec(db, "enemies", "enemies", id)
	if rec.is_empty():
		return null
	var scale := 1.0 + c2.num("enemyLevelScale") * float(maxi(0, level - 1))
	var r := rec.duplicate(true)
	r["hp"] = maxi(1, roundi(float(rec.get("hp", 10)) * scale * c2.num("enemyHpMul", 1.0)))
	r["initiative"] = int(rec.get("agility", 5))
	r.erase("actions")
	var u := UnitScript.from_enemy(r)
	u.stats = { "power": float(rec.get("power", 2)) * scale, "magic": float(rec.get("power", 2)) * scale }
	u.source["kind"] = id
	return u


func _enemy_kit(u: UnitScript) -> Dictionary:
	var moves: Array = []
	for m in u.source.get("moves", []):
		moves.append(Kits.ability(m, "move"))
	return { "char": u.id, "name": u.name, "moves": moves, "spells": [], "ultimate": {}, "effects": [], "weak": [], "resist": [], "enemy": true }


func _join(u: UnitScript, kit: Dictionary) -> void:
	kits[u.id] = kit
	cooldowns[u.id] = {}
	meter[u.id] = 0
	var ch := {}
	for s in kit.get("spells", []):
		ch[str(s["uid"])] = int(s.get("maxCharges", 1))
	charges_left[u.id] = ch


# --- Turn flow ---------------------------------------------------------------

func _advance() -> void:
	if _deferred:
		return
	super._advance()


## Telegraphs are a boss-only thing in C2: other enemy attacks land on their turn.
func refresh_intents(_only: Array = []) -> void:
	pass


func _build_order() -> void:
	for u in units:
		u.init_bonus = _init_bonus(u)
	super._build_order()


func _init_bonus(u: UnitScript) -> int:
	var n := int(u.links.get("c2_init", "0"))
	if u.statuses.has("haste"):
		n += c2.count("hasteInitiative", 5)
	if u.statuses.has("slow"):
		n -= c2.count("slowInitiative", 5)
	return n


func _start_turn(u: UnitScript) -> void:
	if u.links.has("c2_extra"):
		# A Baton Pass, a Cue or an Encore: an extra turn out of order, no start-of-turn ticks.
		var bonus := int(u.links["c2_extra"])
		u.links.erase("c2_extra")
		_turn_reset(u)
		u.move_left += bonus
		u.links["c2_extra_turn"] = "1"
		_emit({ "t": "turn", "unit": u.id, "extra": true })
		return
	super._start_turn(u)
	u.links.erase("c2_extra_turn")
	_turn_reset(u)
	for uid in cooldowns.get(u.id, {}).keys():
		cooldowns[u.id][uid] = maxi(0, int(cooldowns[u.id][uid]) - 1)
	u.statuses.erase("braced")
	u.links.erase("c2_half")
	if u.statuses.has("stun"):
		u.statuses.erase("stun")
		u.links["c2_skip"] = "stun"
		_emit({ "t": "log", "text": "%s is stunned and loses the turn." % u.name })
	elif u.statuses.has("knocked"):
		if Perks.pinned(self, u):
			u.links["c2_skip"] = "pinned"
			_emit({ "t": "log", "text": "%s is pinned down and can't get up." % u.name })
		else:
			u.statuses.erase("knocked")
			_emit({ "t": "stand", "unit": u.id })
			var heal := Perks.value(kit_of(u), "standHeal")
			if heal > 0.0:
				_heal(u, u, roundi(heal), false)
			if c2.text("standUp", "skip") == "skip":
				u.links["c2_skip"] = "stand"
				_emit({ "t": "log", "text": "%s gets back up (that uses the turn)." % u.name })
			else:
				u.links["c2_half"] = "1"
				_emit({ "t": "log", "text": "%s gets back up, shaky (half effect this turn)." % u.name })
	if u.team == "enemy" and u.boss:
		big_counter[u.id] = int(big_counter.get(u.id, 0)) + 1


func _turn_reset(u: UnitScript) -> void:
	u.action_used = false
	u.moved_steps = 0
	u.start_cell = u.cell
	u.move_left = 0 if u.statuses.has("root") else maxi(0, u.movement - (1 if u.statuses.has("slow") else 0))
	acted[u.id] = false
	items_turn = 0
	one_more = {}
	one_mores_turn = 0
	all_out_ready = false
	u.links.erase("c2_skip")


## Whether this turn has to be skipped (standing up, stunned, pinned). Drivers end it.
func must_skip(u: UnitScript) -> bool:
	return u != null and u.links.has("c2_skip")


func end_turn() -> void:
	if result != "" or current == null:
		return
	var u := current
	if not bool(acted.get(u.id, false)) and not u.links.has("c2_skip") and u.alive():
		# No Ability this turn: Brace.
		u.statuses["braced"] = 1
		tally["braces"] = int(tally["braces"]) + (1 if u.team == "party" else 0)
		_emit({ "t": "status", "unit": u.id, "status": "braced" })
	u.links.erase("c2_skip")
	u.links.erase("c2_baton")
	one_more = {}
	all_out_ready = false
	_c2_check_end()
	if result != "":
		return
	super.end_turn()


## Put an extra turn for this unit right after the current one.
func insert_turn(u: UnitScript, move_bonus: int = 0) -> void:
	u.links["c2_extra"] = str(move_bonus)
	order.insert(turn_index + 1, u)


## The next rounds of turns, for the timeline at the top: [{ unit, round }].
func c2_timeline(rounds: int = -1) -> Array:
	var n := rounds if rounds > 0 else c2.count("timelineRounds", 2)
	var out: Array = []
	for i in range(maxi(0, turn_index), order.size()):
		if order[i].alive() and takes_turns(order[i]):
			out.append({ "unit": order[i], "round": round_num })
	var next: Array = units.filter(func(x: UnitScript) -> bool: return takes_turns(x))
	for x in next:
		x.init_bonus = _init_bonus(x)
	next = _ordered(next)
	for x in units:
		x.init_bonus = 0
	for r in range(1, n):
		for x in next:
			out.append({ "unit": x, "round": round_num + r })
	return out


# --- Abilities ---------------------------------------------------------------

func kit_of(u: UnitScript) -> Dictionary:
	return kits.get(u.id, {})


## Every Ability this unit has: moves, spells, then the ultimate.
func abilities(u: UnitScript) -> Array:
	var k := kit_of(u)
	var out: Array = (k.get("moves", []) as Array).duplicate()
	out.append_array(k.get("spells", []))
	if not (k.get("ultimate", {}) as Dictionary).is_empty():
		out.append(k["ultimate"])
	return out


func ability_of(u: UnitScript, uid: String) -> Dictionary:
	for a in abilities(u):
		if str(a["uid"]) == uid:
			return a
	return {}


## Why this Ability can't be used now ("" when it can).
func ability_block(u: UnitScript, ab: Dictionary) -> String:
	if ab.is_empty():
		return "no such ability"
	if result != "" or u != current or not u.alive():
		return "not your turn"
	if u.links.has("c2_skip"):
		return "this turn is lost"
	if u.action_used and one_more.is_empty():
		return "already used an Ability this turn"
	var uid := str(ab["uid"])
	if int(cooldowns.get(u.id, {}).get(uid, 0)) > 0:
		return "cooling down (%d)" % int(cooldowns[u.id][uid])
	match str(ab.get("kind", "")):
		"spell":
			if int(charges_left.get(u.id, {}).get(uid, 0)) <= 0 and not _free_spell(u):
				return "no charges left"
		"ultimate":
			if int(meter.get(u.id, 0)) < c2.count("ultMax", 100):
				return "ultimate not ready (%d/%d)" % [int(meter.get(u.id, 0)), c2.count("ultMax", 100)]
	if Shapes.targets(self, u, ab).is_empty():
		return "no target in range"
	return ""


func ability_targets(u: UnitScript, ab: Dictionary) -> Array:
	return Shapes.targets(self, u, ab)


func _free_spell(u: UnitScript) -> bool:
	return Perks.value(kit_of(u), "firstSpellFree") > 0.0 and not used_free_spell.has(u.id)


## Use an Ability at a tile. Ends the turn unless One More, All-Out or moveAfterAct leaves it open.
func use_ability(u: UnitScript, uid: String, target: Vector2i) -> bool:
	var ab := ability_of(u, uid)
	if ability_block(u, ab) != "" or not Shapes.targets(self, u, ab).has(target):
		return false
	var fresh := _resolve(u, ab, target)
	_after_ability(u, ab, fresh)
	return true


## Resolve the Ability's effects. Returns how many enemies it newly knocked down.
func _resolve(u: UnitScript, ab: Dictionary, target: Vector2i) -> int:
	var shape := str(ab.get("shape", "adjacent"))
	var kind := str(ab.get("kind", "move"))
	_emit({ "t": "cast", "unit": u.id, "name": str(ab.get("name", "")), "target": target, "c2": kind })
	if kind == "ultimate":
		meter[u.id] = 0
		tally["ultimates"] = int(tally["ultimates"]) + (1 if u.team == "party" else 0)
		_emit({ "t": "cutin", "kind": "ultimate", "unit": u.id, "text": str(ab.get("cutIn", ab.get("name", ""))) })
	var from := u.cell
	if target != u.cell:
		u.facing_dir = Shapes.dir_of(u.cell, target)
	if shape == "leap":
		var land := Shapes.landing(self, u, target, u.cell)
		if land.x >= 0:
			_teleport(u, land)
			u.facing_dir = Shapes.dir_of(u.cell, target)
	elif shape == "dash":
		var stop := Shapes.dash_stop(self, u, u.cell, target, Shapes.range_of(ab))
		if stop != u.cell:
			_teleport(u, stop)
	var cells := Shapes.cells(self, u, ab, target, from)
	if shape in ["leap", "dash"]:
		cells = [target if shape == "leap" else (cells[0] if not cells.is_empty() else target)]
	var affects := str(ab.get("affects", "allies" if shape == "ally" or (shape == "self" and not ab.has("power")) else "enemies"))
	var fresh := 0
	if bool(ab.get("actNow", false)):
		var ally := unit_at(target)
		if ally != null and ally != u and ally.team == u.team and ally.alive():
			insert_turn(ally, 0)
			_emit({ "t": "log", "text": "%s cues %s: they act next." % [u.name, ally.name] })
	if bool(ab.get("allAlliesAct", false)):
		var others: Array = allies_of(u).filter(func(a: UnitScript) -> bool: return a != u)
		others.reverse()
		for a in others:
			insert_turn(a, 0)
	if affects == "allies":
		var group: Array = []
		for c in cells:
			var a := unit_at(c)
			if a != null and a.team == u.team and a.alive() and not a.is_prop():
				group.append(a)
		if shape == "burst" and not group.has(u):
			group.append(u)
		if bool(ab.get("allAlliesAct", false)):
			group = allies_of(u)
		for a in group:
			_support(u, a, ab)
	else:
		var hits: Array = []
		for c in cells:
			var t := unit_at(c)
			if t != null and t != u and t.alive() and (is_hostile(u, t) or t.is_prop()):
				hits.append(t)
		for t in hits:
			if not t.alive():
				continue
			if _hit(u, t, ab, target):
				fresh += 1
		if ab.has("terrain"):
			for c in cells:
				if grid.get_terrain(c) == GridScript.FLOOR and unit_at(c) == null:
					grid.set_terrain(c, str(ab["terrain"]))
		var vtype := str(ab.get("type", ""))
		if Board.on(self) and vtype != "" and not Perks.physical(db, vtype):
			Board.react(self, u, { vtype: float(ab.get("power", 1)) }, cells)
		if shape == "self" and ab.has("shield"):
			_support(u, u, ab)
	_c2_check_end()
	return fresh


func _teleport(u: UnitScript, cell: Vector2i) -> void:
	var from := u.cell
	u.cell = cell
	_emit({ "t": "move", "unit": u.id, "path": [cell], "from": from })
	_enter_cell(u, cell)


func _support(u: UnitScript, a: UnitScript, ab: Dictionary) -> void:
	if float(ab.get("heal", 0)) > 0.0:
		var amt := float(ab["heal"]) * (1.0 + Perks.value(kit_of(u), "healPct"))
		_heal(u, a, roundi(amt), false)
	if float(ab.get("shield", 0)) > 0.0:
		a.shield += roundi(float(ab["shield"]))
		a.shield_turns = maxi(a.shield_turns, 2)
		_emit({ "t": "shield", "unit": a.id, "amount": a.shield })
	var s: Dictionary = ab.get("status", {})
	if not s.is_empty():
		add_status(a, str(s["id"]), int(s.get("turns", 1)))
	if bool(ab.get("scan", false)):
		for e in opponents_of(u):
			reveal_all(e)


## One hit on one unit. Returns true when it newly knocked the unit down.
func _hit(u: UnitScript, t: UnitScript, ab: Dictionary, center: Vector2i) -> bool:
	var vtype := str(ab.get("type", ""))
	if bool(ab.get("scan", false)):
		reveal_all(t)
	var res := hit_result(u, t, ab)
	var knocked := false
	if not t.is_prop() and vtype != "" and float(ab.get("power", 0)) > 0.0:
		_learn(u, t, vtype, str(res["mark"]) if str(res["mark"]) != "" else "normal")
	if float(ab.get("power", 0)) > 0.0 or res["amount"] > 0:
		if u.team == "enemy" and t.team == "party":
			tally["enemyAttacks"] = int(tally["enemyAttacks"]) + 1
		var amount: int = res["amount"]
		if amount > 0:
			var cover_ally := _protector(t, amount)
			if cover_ally != null:
				_emit({ "t": "log", "text": "%s takes the blow for %s!" % [cover_ally.name, t.name] })
				_emit({ "t": "cutin", "kind": "protect", "unit": cover_ally.id, "text": "Protect!" })
				tally["protects"] = int(tally["protects"]) + 1
				t = cover_ally
			var before := t.hp + t.shield
			_damage(t, amount, u, vtype if not Perks.physical(db, vtype) else "", "hit")
			var dealt := maxi(0, before - (t.hp + t.shield))
			_gain_meter(u, float(dealt) * c2.num("ultPerDealt", 1.0))
			if not t.is_prop():
				_gain_meter(t, float(dealt) * c2.num("ultPerTaken", 1.5))
			if u.team == "party" and t.team == "enemy":
				tally["partyDamage"] = int(tally["partyDamage"]) + dealt
			elif u.team == "enemy" and t.team == "party":
				tally["enemyDamage"] = int(tally["enemyDamage"]) + dealt
				if dealt > 0:
					tally["enemyHits"] = int(tally["enemyHits"]) + 1
		if bool(res["weak"]) and u.team == "party":
			tally["weakHits"] = int(tally["weakHits"]) + 1
		if bool(res["knock"]) and t.alive() and not t.is_prop() and not t.statuses.has("knocked"):
			knocked = _knock_down(u, t)
	if t.alive() and not t.is_prop() and res["mark"] != "immune":
		var s: Dictionary = ab.get("status", {})
		if not s.is_empty():
			add_status(t, str(s["id"]), int(s.get("turns", 1)))
		if bool(ab.get("delay", false)):
			delay_unit(t)
	if t.alive():
		var steps := int(ab.get("push", 0))
		var pull := int(ab.get("pull", 0))
		if steps > 0 or pull > 0:
			steps += int(Perks.value(kit_of(u), "pushPlus")) if steps > 0 else 0
			var dir := Shapes.dir_of(center if str(ab.get("shape", "")) in ["area", "plus"] and center != t.cell else u.cell, t.cell)
			if dir == Vector2i.ZERO:
				dir = Shapes.dir_of(u.cell, t.cell)
			var hp_before := t.hp
			var n_events := events.size()
			if steps > 0:
				_push(u, t, dir, steps)
			else:
				_push(u, t, -dir, pull)
			var slam := Perks.value(kit_of(u), "wallSlam")
			if slam > 0.0 and t.alive() and _collided(t, n_events):
				_damage(t, roundi(slam), u, "", "collision")
			if hp_before > t.hp:
				pass
	if knocked and u.team == "party":
		_follow_ups(u, t)
	var first_key := "%s|%s" % [u.id, t.id]
	if not first_hits.has(first_key) and not t.is_prop():
		first_hits[first_key] = true
		if Perks.value(kit_of(u), "revealOnFirstHit") > 0.0:
			reveal_all(t)
	return knocked


func _collided(t: UnitScript, since: int) -> bool:
	for i in range(since, events.size()):
		var e: Dictionary = events[i]
		if str(e.get("t", "")) == "collide" and str(e.get("unit", "")) == t.id:
			return true
	return false


## What a hit would do: { amount, mark, weak, knock, back, side }. No changes.
func hit_result(u: UnitScript, t: UnitScript, ab: Dictionary) -> Dictionary:
	var vtype := str(ab.get("type", ""))
	var power := float(ab.get("power", 0))
	var out := { "amount": 0, "mark": "", "weak": false, "knock": false, "back": false, "side": false }
	if t.is_prop():
		out["amount"] = roundi(power)
		return out
	var mark := mark_of(t, vtype, u)
	out["mark"] = mark
	if power <= 0.0:
		return out
	var stat := float(u.stats.get("magic" if not Perks.physical(db, vtype) or str(ab.get("kind", "")) == "spell" else "power", 3))
	var dmg := power * (1.0 + c2.num("statDamagePer", 0.08) * stat)
	if u.team == "enemy":
		dmg *= c2.num("enemyDamageMul", 1.0)
	var mul := 1.0
	match mark:
		"weak":
			mul *= c2.num("weakMul", 1.5)
			out["weak"] = true
		"resist":
			mul *= c2.num("resistMul", 0.5)
		"immune":
			mul = 0.0
	var downed := t.statuses.has("knocked")
	if downed:
		mul *= c2.num("knockdownMul", 1.5) * (1.0 + float(ab.get("downedBonus", 0.0)))
	var side := facing_side(u, t)
	if side == "back":
		mul *= c2.num("backMul", 1.5)
		out["back"] = true
	elif side == "side":
		mul *= c2.num("sideMul", 1.25)
		out["side"] = true
	if t.statuses.has("braced"):
		mul *= maxf(0.0, 1.0 - c2.num("braceReduction", 0.25) - Perks.value(kit_of(t), "braceExtra"))
	if t.statuses.has("marked"):
		mul *= c2.num("markedMul", 1.25)
	if u.links.has("c2_baton"):
		mul *= 1.0 + float(u.links["c2_baton"])
	if u.links.has("c2_half"):
		mul *= 0.5
	mul *= 1.0 + Perks.damage_pct(kit_of(u), ab, { "weak": out["weak"], "downed": downed, "back": out["back"] })
	out["amount"] = maxi(0, roundi(dmg * mul)) if mark != "immune" else 0
	if c2.flag("knockdownOn", true) and not downed and mark != "immune":
		var by_back := bool(out["back"]) and (c2.flag("backCritKnockdown") or Perks.value(kit_of(u), "backKnockdown") > 0.0)
		var enemy_ok := u.team == "party" or c2.flag("enemyOneMore", true)
		out["knock"] = enemy_ok and (bool(out["weak"]) or by_back or bool(ab.get("knockdown", false)))
	return out


## front, side or back: where the attacker stands relative to the way the target faces.
func facing_side(u: UnitScript, t: UnitScript) -> String:
	if not c2.flag("facingOn", true) or t.is_prop() or u.cell == t.cell:
		return "front"
	var d := Shapes.dir_of(t.cell, u.cell)
	var f := t.facing_dir
	var dot := d.x * f.x + d.y * f.y
	if dot > 0:
		return "front"
	return "back" if dot < 0 else "side"


## A unit's marking for a type: weak, resist, immune or "" (data, armor and perks).
func mark_of(t: UnitScript, vtype: String, attacker: UnitScript = null) -> String:
	if vtype == "":
		return ""
	if attacker != null:
		for e in kit_of(attacker).get("effects", []):
			if str(e.get("kind", "")) == "weakWhileStatus" and str(e.get("type", "")) == vtype and t.statuses.has(str(e.get("status", ""))):
				return "weak"
	if t.team == "party":
		var k := kit_of(t)
		if (k.get("weak", []) as Array).has(vtype):
			return "weak"
		if (k.get("resist", []) as Array).has(vtype):
			return "resist"
		return ""
	return str(t.source.get("marks", {}).get(vtype, ""))


## What the party knows about this enemy's markings: type -> mark, or "?" if unknown.
func known_of(t: UnitScript) -> Dictionary:
	var kind := str(t.source.get("kind", t.id))
	return known_marks.get(kind, {})


func _learn(u: UnitScript, t: UnitScript, vtype: String, mark: String) -> void:
	if u.team != "party" or not c2.flag("revealOnHit", true) or bool(t.source.get("hiddenMarks", false)):
		return
	var kind := str(t.source.get("kind", t.id))
	if not known_marks.has(kind):
		known_marks[kind] = {}
	if not known_marks[kind].has(vtype):
		known_marks[kind][vtype] = mark
		_emit({ "t": "reveal", "unit": t.id, "type": vtype, "mark": mark })


func reveal_all(t: UnitScript) -> void:
	if t.is_prop() or t.team != "enemy":
		return
	var kind := str(t.source.get("kind", t.id))
	var marks: Dictionary = t.source.get("marks", {})
	if not c2.flag("scanRevealsAll", true):
		return
	known_marks[kind] = marks.duplicate()
	_emit({ "t": "reveal", "unit": t.id, "all": true })
	_emit({ "t": "log", "text": "%s's markings are revealed." % t.name })


func _knock_down(u: UnitScript, t: UnitScript) -> bool:
	t.statuses["knocked"] = 99
	_emit({ "t": "status", "unit": t.id, "status": "knocked" })
	_emit({ "t": "log", "text": "%s is knocked down!" % t.name })
	_gain_meter(u, float(c2.count("ultPerKnockdown", 10)))
	if t.team == "enemy":
		tally["knockdowns"] = int(tally["knockdowns"]) + 1
	else:
		tally["partyKnocked"] = int(tally["partyKnocked"]) + 1
	return true


func _gain_meter(u: UnitScript, amount: float) -> void:
	if u == null or u.is_prop() or amount <= 0.0 or (kit_of(u).get("ultimate", {}) as Dictionary).is_empty():
		return
	var rate := 1.0 + Perks.value(kit_of(u), "ultRate")
	meter[u.id] = mini(c2.count("ultMax", 100), int(meter.get(u.id, 0)) + roundi(amount * rate))


## Friend-tier Bond: an ally next to the knocked-down enemy may add a hit.
func _follow_ups(u: UnitScript, t: UnitScript) -> void:
	if not c2.flag("bondTeamUps", true) or Perks.bond_tier(self) < 2 or not t.alive():
		return
	for a in allies_of(u):
		if a == u or a.statuses.has("knocked") or GridScript.manhattan(a.cell, t.cell) != 1:
			continue
		var chance := c2.num("followUpChance", 0.5) + Perks.value(kit_of(a), "followUpPlus")
		if _previewing or rng.randf() >= chance:
			continue
		var basic := _basic_of(a)
		if basic.is_empty():
			continue
		var res := hit_result(a, t, basic)
		var amt := roundi(float(res["amount"]) * c2.num("followUpShare", 0.5))
		if amt > 0:
			_emit({ "t": "log", "text": "%s follows up!" % a.name })
			_damage(t, amt, a, "", "hit")
			tally["followUps"] = int(tally["followUps"]) + 1
		if not t.alive():
			return


func _basic_of(u: UnitScript) -> Dictionary:
	for m in kit_of(u).get("moves", []):
		if bool(m.get("basic", false)):
			return m
	return {}


## Close-tier Bond (or the Bodyguard perk): an ally takes a killing blow once per fight.
func _protector(t: UnitScript, amount: int) -> UnitScript:
	if t.team != "party" or amount < t.hp + t.shield:
		return null
	for a in allies_of(t):
		if a == t or protect_used.has(a.id) or a.hp + a.shield <= amount:
			continue
		var bond := c2.flag("bondTeamUps", true) and Perks.bond_tier(self) >= 3
		var perk := Perks.value(kit_of(a), "protectOnce") > 0.0 and GridScript.manhattan(a.cell, t.cell) == 1
		if bond or perk:
			protect_used[a.id] = true
			return a
	return null


## Act after the next unit in this round's order.
func delay_unit(t: UnitScript) -> void:
	var i := order.find(t)
	if i > turn_index and i < order.size() - 1:
		order.remove_at(i)
		order.insert(mini(i + 1, order.size()), t)
		_emit({ "t": "log", "text": "%s is thrown off the beat." % t.name })
	else:
		t.links["c2_init"] = str(int(t.links.get("c2_init", "0")) - 3)


func _after_ability(u: UnitScript, ab: Dictionary, fresh: int) -> void:
	var uid := str(ab["uid"])
	var kind := str(ab.get("kind", ""))
	acted[u.id] = true
	u.action_used = true
	if u.team == "party":
		var m: Dictionary = tally["moves"]
		m[uid] = int(m.get(uid, 0)) + 1
	if int(ab.get("cooldown", 0)) > 0:
		cooldowns[u.id][uid] = int(ab["cooldown"]) + 1
	if kind == "spell":
		if _free_spell(u):
			used_free_spell[u.id] = true
		else:
			charges_left[u.id][uid] = maxi(0, int(charges_left[u.id].get(uid, 0)) - 1)
			if u.team == "party":
				tally["charges"] = int(tally["charges"]) + 1
		if u.team == "party":
			tally["spells"] = int(tally["spells"]) + 1
	if result != "":
		return
	if fresh > 0 and c2.flag("oneMoreOn", true) and one_mores_turn < c2.count("oneMoreChain", 1) and u.alive():
		one_more = { "unit": u.id }
		one_mores_turn += 1
		u.action_used = false
		u.move_left = c2.count("oneMoreStep", 0)
		if u.team == "party":
			tally["oneMores"] = int(tally["oneMores"]) + 1
		_emit({ "t": "cutin", "kind": "one_more", "unit": u.id, "text": "ONE MORE!" })
		var heal := Perks.value(kit_of(u), "oneMoreHeal")
		if heal > 0.0:
			_heal(u, u, roundi(heal), false)
	else:
		one_more = {}
		if not c2.flag("moveAfterAct"):
			u.move_left = 0
	all_out_ready = u.team == "party" and c2.flag("allOutOn", true) and all_enemies_down()
	if _previewing:
		return
	if one_more.is_empty() and not all_out_ready and (u.move_left <= 0 or not c2.flag("moveAfterAct")):
		end_turn()


func all_enemies_down() -> bool:
	var any := false
	for e in units:
		if e.team == "enemy" and e.alive() and not e.is_prop():
			any = true
			if not e.statuses.has("knocked"):
				return false
	return any


## Pass the waiting One More to an ally: they act now with more damage and Movement.
func baton_block(u: UnitScript, ally: UnitScript) -> String:
	if not c2.flag("batonOn", true):
		return "Baton Pass is off"
	if one_more.is_empty() or str(one_more.get("unit", "")) != u.id or u != current:
		return "no One More to pass"
	if ally == null or ally == u or ally.team != u.team or not ally.alive() or ally.statuses.has("knocked"):
		return "can't pass to them"
	if c2.text("batonGate", "always") == "bond" and Perks.bond_tier(self) < 1:
		return "needs a Bond (Acquaintance or higher)"
	return ""


func baton_pass(u: UnitScript, ally: UnitScript) -> bool:
	if baton_block(u, ally) != "":
		return false
	var stack := float(u.links.get("c2_baton", "0")) + c2.num("batonBonus", 0.25) + Perks.value(kit_of(u), "batonPct")
	stack = minf(stack, c2.num("batonMax", 0.5) + Perks.value(kit_of(u), "batonPct"))
	one_more = {}
	insert_turn(ally, c2.count("batonMove", 1))
	ally.links["c2_baton"] = str(snappedf(stack, 0.01))
	var init := Perks.value(kit_of(u), "batonInit")
	if init > 0.0:
		ally.links["c2_init"] = str(int(ally.links.get("c2_init", "0")) + roundi(init))
	_gain_meter(u, float(c2.count("ultPerBaton", 8)))
	tally["batons"] = int(tally["batons"]) + 1
	_emit({ "t": "cutin", "kind": "baton", "unit": u.id, "to": ally.id, "text": "BATON PASS!" })
	_emit({ "t": "log", "text": "%s passes the baton to %s (+%d%% damage)." % [u.name, ally.name, roundi(stack * 100.0)] })
	acted[u.id] = true
	end_turn()
	return true


## The All-Out Attack: every ally hits every knocked-down enemy in reach, then they stand.
func all_out(u: UnitScript) -> bool:
	if not all_out_ready or u != current or u.team != "party":
		return false
	_emit({ "t": "cutin", "kind": "all_out", "unit": u.id, "text": "ALL-OUT ATTACK!" })
	tally["allOuts"] = int(tally["allOuts"]) + 1
	for a in allies_of(u):
		if a.statuses.has("knocked"):
			continue
		var reach: int = a.movement + c2.count("allOutRange", 1)
		var stat := maxf(float(a.stats.get("power", 3)), float(a.stats.get("magic", 3)))
		var pct := 1.0 + Perks.value(kit_of(a), "allOutPct")
		for e in units:
			if e.team == "enemy" and e.alive() and e.statuses.has("knocked") and GridScript.manhattan(a.cell, e.cell) <= reach:
				var amt := roundi(c2.num("allOutPower", 8.0) * (1.0 + c2.num("statDamagePer", 0.08) * stat) * pct * c2.num("knockdownMul", 1.5))
				_damage(e, amt, a, "", "hit")
				tally["partyDamage"] = int(tally["partyDamage"]) + amt
	if c2.flag("allOutStandUp", true):
		for e in units:
			if e.team == "enemy" and e.alive():
				e.statuses.erase("knocked")
	all_out_ready = false
	one_more = {}
	acted[u.id] = true
	_c2_check_end()
	if result == "":
		end_turn()
	return true


# --- Items ---------------------------------------------------------------------

func item_block(u: UnitScript, index: int) -> String:
	if u != current or result != "":
		return "not your turn"
	if index < 0 or index >= backpack_c2.size():
		return "no such item"
	if items_turn >= c2.count("freeItemsPerTurn", 1):
		return "already used an item this turn"
	return ""


## Use a backpack item (free: it doesn't end the turn). spell_uid picks which spell a charge goes to.
func use_item(u: UnitScript, index: int, spell_uid: String = "") -> bool:
	if item_block(u, index) != "":
		return false
	var it := Kits.item(db, str(backpack_c2[index]))
	var fx: Dictionary = it.get("effect", {})
	if fx.has("heal"):
		_heal(u, u, int(fx["heal"]), false)
	if fx.has("charge"):
		var ch: Dictionary = charges_left.get(u.id, {})
		var pick := spell_uid
		if pick == "" or not ch.has(pick):
			for s in kit_of(u).get("spells", []):
				if int(ch.get(str(s["uid"]), 0)) < int(s.get("maxCharges", 1)):
					pick = str(s["uid"])
					break
		if pick != "" and ch.has(pick):
			var mx := 1
			for s in kit_of(u).get("spells", []):
				if str(s["uid"]) == pick:
					mx = int(s.get("maxCharges", 1))
			ch[pick] = mini(mx, int(ch[pick]) + int(fx["charge"]))
	if bool(fx.get("stand", false)):
		u.statuses.erase("knocked")
	for s in fx.get("cleanse", []):
		u.statuses.erase(str(s))
	backpack_c2.remove_at(index)
	items_turn += 1
	tally["items"] = int(tally["items"]) + 1
	_emit({ "t": "log", "text": "%s uses %s." % [u.name, str(it.get("name", "an item"))] })
	return true


# --- Threat and previews -----------------------------------------------------------

## The tiles this enemy can reach and hit on its next turn ("Fractured but Whole" hover).
func threat_cells(e: UnitScript) -> Dictionary:
	var out := {}
	var spots: Array = [e.cell]
	if not e.statuses.has("root"):
		spots.append_array(grid.reachable(e.cell, e.movement, occupied(e)).keys())
	var saved := e.cell
	for spot in spots:
		e.cell = spot
		for ab in abilities(e):
			if bool(ab.get("big", false)):
				continue
			for c in Shapes.reach_cells(self, e, ab, spot):
				out[c] = true
	e.cell = saved
	for p in boss_plans.values():
		for c in p["cells"]:
			out[c] = true
	return out


## Every enemy's threat at once: cell -> [enemy ids].
func all_threat() -> Dictionary:
	var out := {}
	for e in units:
		if e.team == "enemy" and e.alive():
			for c in threat_cells(e):
				if not out.has(c):
					out[c] = []
				out[c].append(e.id)
	return out


## Exactly what using this Ability here would do, without doing it:
## { units: { id: { hp, hpAfter, knocked, cell, cellAfter, dies } }, oneMore, allOut }.
func ability_preview(u: UnitScript, uid: String, target: Vector2i) -> Dictionary:
	var ab := ability_of(u, uid)
	var out := { "units": {}, "oneMore": false, "allOut": false, "ok": false }
	if ability_block(u, ab) != "" or not Shapes.targets(self, u, ab).has(target):
		return out
	var Sim: GDScript = load("res://src/core/lab/players/sim.gd")
	var snap: Dictionary = Sim.save(self)
	var before := {}
	for x in units:
		before[x.id] = { "hp": x.hp + x.shield, "cell": x.cell, "knocked": x.statuses.has("knocked"), "alive": x.alive() }
	var ev := events.duplicate()
	_previewing = true
	var fresh := _resolve(u, ab, target)
	_after_ability(u, ab, fresh)
	_previewing = false
	for x in units:
		var b: Dictionary = before.get(x.id, {})
		if b.is_empty():
			continue
		if int(b["hp"]) != x.hp + x.shield or b["cell"] != x.cell or bool(b["knocked"]) != x.statuses.has("knocked") or bool(b["alive"]) != x.alive():
			out["units"][x.id] = { "name": x.name, "hp": int(b["hp"]), "hpAfter": x.hp + x.shield, "cell": b["cell"], "cellAfter": x.cell,
				"knocked": x.statuses.has("knocked") and not bool(b["knocked"]), "dies": bool(b["alive"]) and not x.alive() }
	out["oneMore"] = not one_more.is_empty()
	out["allOut"] = all_out_ready
	out["ok"] = true
	Sim.restore(self, snap)
	events = ev
	return out


# --- Bosses -----------------------------------------------------------------------

## A boss's big attack marked this turn, landing on its next turn.
func plan_big(u: UnitScript, ab: Dictionary, target: Vector2i) -> void:
	boss_plans[u.id] = { "uid": str(ab["uid"]), "cells": Shapes.cells(self, u, ab, target), "name": str(ab.get("name", "")), "target": target, "from": u.cell }
	big_counter[u.id] = 0
	_emit({ "t": "telegraph", "unit": u.id, "name": str(ab.get("name", "")), "cells": boss_plans[u.id]["cells"] })
	_emit({ "t": "log", "text": "%s winds up %s! (it lands on its next turn)" % [u.name, str(ab.get("name", ""))] })


## Land a planned big attack on the tiles that were marked.
func land_big(u: UnitScript) -> void:
	var p: Dictionary = boss_plans.get(u.id, {})
	boss_plans.erase(u.id)
	if p.is_empty():
		return
	var ab := ability_of(u, str(p["uid"]))
	_emit({ "t": "cast", "unit": u.id, "name": str(p["name"]), "target": p["target"], "c2": "big" })
	for c in p["cells"]:
		var t := unit_at(c)
		if t != null and t.alive() and (is_hostile(u, t) or t.is_prop()):
			_hit(u, t, ab, p["target"])
	_c2_check_end()


# --- Phases and the end --------------------------------------------------------------

func _check_phase(t: UnitScript) -> void:
	if t.team != "enemy" or t.phases.is_empty():
		super._check_phase(t)
		return
	for i in t.phases.size():
		var ph: Dictionary = t.phases[i]
		var key := "c2_phase_%d" % i
		if t.links.has(key) or float(t.hp) / float(maxi(1, t.max_hp)) >= float(ph.get("hpBelow", 0.5)):
			continue
		t.links[key] = "1"
		if ph.has("text"):
			_emit({ "t": "log", "text": str(ph["text"]) })
		_emit({ "t": "cutin", "kind": "phase", "unit": t.id, "text": "Phase %d" % (i + 2) })
		for id in ph.get("summon", []):
			var add := _enemy_unit(str(id), int(c2_setup.get("level", 1)))
			if add == null:
				continue
			add.cell = _free_near(t.cell)
			if add.cell.x < 0:
				continue
			_add_unit(add)
			_join(add, _enemy_kit(add))
			_emit({ "t": "spawn", "unit": add.id, "cell": add.cell, "prop": false })


func _c2_check_end() -> void:
	if result != "":
		return
	var party_up := false
	var foes := false
	for x in units:
		if x.team == "party" and x.alive() and not x.downed and not x.is_prop():
			party_up = true
		if x.team == "enemy" and x.alive() and not x.is_prop():
			foes = true
	if not party_up:
		result = "lose"
		_emit({ "t": "end", "result": "lose" })
	elif not foes:
		result = "win"
		_emit({ "t": "end", "result": "win" })


func _check_end() -> void:
	_c2_check_end()


## What carries to the next fight of a night: HP and spell charges per character.
func carry_out() -> Dictionary:
	var out := {}
	for x in units:
		if x.team == "party" and not x.is_prop():
			out[x.id] = { "hp": maxi(0, x.hp), "charges": (charges_left.get(x.id, {}) as Dictionary).duplicate() }
	return out

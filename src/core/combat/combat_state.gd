## One tactical fight (DESIGN.md Section 9). Pure rules: the combat scene and
## the AI call the action functions (move, play_card, improvise, strike, guard,
## end_turn) and read `events` to animate what happened.
##
## setup = {
##   "layout": room layout record (data/rooms/combat_layouts.json),
##   "party": [{ "char": character Dictionary, "ai": bool, "guest": bool }],
##   "enemies": [enemy record Dictionary, with optional "scale"],
##   "boss": bool, "fleeAllowed": bool, "library": run card library
## }
class_name CombatState
extends RefCounted

const VO := preload("res://src/core/vector_ops.gd")
const DT := preload("res://src/core/data_tables.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const Forms := preload("res://src/core/combat/forms.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")
const Res := preload("res://src/core/combat/resolver.gd")
const EnemyMods := preload("res://src/core/combat/enemy_mods.gd")

var db: Dictionary = {}
var rng: RandomNumberGenerator
var grid: GridScript
var units: Array = []
var order: Array = []
var turn_index := 0
var round_num := 1
var current: UnitScript = null
var result := ""
var events: Array = []
var library: Dictionary = {}
var boss_fight := false
var flee_allowed := true
var glyphs: Array = []
var kills: Array = []
var xp_total := 0
var money_total := 0
var wild_surges := 0
var support_log: Dictionary = {}
var help_calls: Array = []
var forms: Dictionary = {}
var _spawn_counter := 0
var _ai: GDScript = null           # enemy_ai.gd, loaded lazily (it preloads this script)
var _note := ""                    # why the next hit did what it did ("Cold, resisted"), for the log
var turn_mode := "move_or_act"     # data/combat_rules.json "turnMode" (AR); setup "turnMode" overrides
var difficulty := "normal"         # data/combat_rules.json "difficulty"; setup "difficulty" overrides
var ai_overrides: Dictionary = {}  # sims: data/ai.json values to replace for this fight
var delayed: Array = []            # telegraphed strikes that land later: [{ cells, turns, spec, caster, neutral, name }]
var revealed := 0                  # rounds Reveal keeps every plan visible
var _pending_decoys: Array = []    # decoys that appear where a unit stood once it moves away
var _fx: GDScript = null           # card_effects.gd, loaded lazily
var last_party_card: Dictionary = {}  # the last card a party member played (Mirror enemies copy it)
var reinforcements: Dictionary = {}   # { "round", "enemies": [records], "cells": [telegraphed spawn tiles] }


func _init(p_db: Dictionary, p_rng: RandomNumberGenerator, setup: Dictionary) -> void:
	db = p_db
	rng = p_rng
	library = setup.get("library", {})
	turn_mode = str(setup.get("turnMode", db.get("combat_rules", {}).get("turnMode", "move_or_act")))
	difficulty = str(setup.get("difficulty", db.get("combat_rules", {}).get("difficulty", "normal")))
	ai_overrides = setup.get("ai", {})
	boss_fight = bool(setup.get("boss", false))
	flee_allowed = bool(setup.get("fleeAllowed", not boss_fight))
	for f in db.get("forms", {}).get("forms", []):
		forms[str(f["id"])] = f
	grid = GridScript.new(setup.get("layout", {}))
	var party: Array = setup.get("party", [])
	for i in party.size():
		var entry: Dictionary = party[i]
		var u := UnitScript.from_character(db, entry["char"], rng)
		u.ai_controlled = bool(entry.get("ai", false))
		u.guest = bool(entry.get("guest", false))
		_place(u, grid.party_spawns, i, true)
	var enemies: Array = setup.get("enemies", [])
	for i in enemies.size():
		var rec: Dictionary = EnemyMods.apply(db, enemies[i])
		var u := UnitScript.from_enemy(rec, float(rec.get("scale", 1.0)))
		var hp_mul := "bossHpMul" if u.boss else "enemyHpMul"
		u.max_hp = maxi(1, roundi(float(u.max_hp) * float(db.get("combat_rules", {}).get(hp_mul, 1.0))))
		u.max_hp = maxi(1, roundi(float(u.max_hp) * float(difficulty_rules().get("enemyHpMul", 1.0))))
		u.hp = u.max_hp
		var roles: Array = setup.get("roles", [])
		u.role = str(roles[i]) if i < roles.size() else ("minion" if str(rec.get("tier", "")) == "minion" else "fighter")
		_place(u, grid.enemy_spawns, i, false)
		if float(rec.get("startShieldPct", 0.0)) > 0.0:
			u.shield = roundi(float(u.max_hp) * float(rec["startShieldPct"]))
			u.shield_turns = 99
	_formation(str(setup.get("formation", "default")))
	if not setup.get("reinforcements", {}).is_empty():
		reinforcements = setup["reinforcements"].duplicate()
		reinforcements["cells"] = []
	for p in grid.prop_spawns:
		var crate := UnitScript.make_prop("crate", int(Res.combat_cfg(db).get("crateHp", 8)))
		crate.cell = p["cell"]
		_add_unit(crate)
	var hype := false
	for u in units:
		if u.team == "party" and (u.perk == "hype" or u.perk == "encore"):
			hype = true
	if hype:
		for u in units:
			if u.team == "party":
				u.initiative += 4
				u.statuses["hype_draw"] = 1
	var opening := int(Res.combat_cfg(db).get("openingHand", 5))
	for u in units:
		if u.deck != null:
			u.deck.draw(opening, rng)
	_build_order()
	turn_index = -1
	_emit({ "t": "round", "n": round_num })
	_advance()


func _add_unit(u: UnitScript) -> void:
	# Two of the same enemy (or prop) still need different ids for links and events.
	var base := u.id
	var n := 2
	while unit_by_id(u.id) != null:
		u.id = "%s_%d" % [base, n]
		n += 1
	u.spawn_index = _spawn_counter
	_spawn_counter += 1
	units.append(u)


## Encounter formations (data/encounters.json): front_back puts the front
## role nearest the party and the rest behind; surround spreads enemies over
## every row; ambush puts the party in the middle with enemies on both sides.
func _formation(kind: String) -> void:
	if kind == "default" or kind == "":
		return
	var foes: Array = units.filter(func(u: UnitScript) -> bool: return u.team == "enemy")
	var party: Array = units.filter(func(u: UnitScript) -> bool: return u.team == "party")
	var free := func(c: Vector2i) -> bool: return grid.walkable_terrain(c) and not grid.exits.has(c)
	var mid := grid.cols / 2
	if kind == "ambush":
		var pc := Vector2i(mid, 0)
		var i := 0
		for u in party:
			var c := Vector2i(mid - (i % 2), clampi(grid.rows / 2 - 1 + i / 2, 0, grid.rows - 1))
			if free.call(c):
				u.cell = c
			i += 1
		var left: Array = []
		var right: Array = []
		for r in grid.rows:
			for c in [Vector2i(1, r), Vector2i(2, r)]:
				if free.call(c):
					left.append(c)
			for c in [Vector2i(grid.cols - 1, r), Vector2i(grid.cols - 2, r)]:
				if free.call(c):
					right.append(c)
		_spread(foes, [left, right], pc)
		return
	var zone: Array = []
	for c in grid.all_cells():
		var cell: Vector2i = c
		if cell.x > mid and free.call(cell):
			zone.append(cell)
	if kind == "front_back":
		zone.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and absi(a.y - grid.rows / 2) < absi(b.y - grid.rows / 2)))
		var fronts := foes.filter(func(u: UnitScript) -> bool: return u.role in ["front", "fighter", "elite", "leader"])
		var backs := foes.filter(func(u: UnitScript) -> bool: return not (u.role in ["front", "fighter", "elite", "leader"]))
		var far := zone.duplicate()
		far.reverse()
		_spread(fronts, [zone], Vector2i.ZERO)
		_spread(backs, [far], Vector2i.ZERO)
	elif kind == "surround":
		var rows: Array = []
		for r in grid.rows:
			rows.append(zone.filter(func(c: Vector2i) -> bool: return c.y == r))
		_spread(foes, rows, Vector2i.ZERO)


## Hand out cells to units round-robin across the given lists (skipping taken cells).
func _spread(list: Array, pools: Array, _center: Vector2i) -> void:
	var taken := {}
	for u in units:
		if not list.has(u):
			taken[u.cell] = true
	var p := 0
	for u in list:
		for tries in pools.size():
			var pool: Array = pools[(p + tries) % pools.size()]
			var placed := false
			for c in pool:
				if not taken.has(c):
					u.cell = c
					taken[c] = true
					placed = true
					break
			if placed:
				break
		p += 1


## Reinforcements: the round before they arrive their spawn tiles are telegraphed.
func _reinforce() -> void:
	if reinforcements.is_empty():
		return
	var arrive := int(reinforcements.get("round", 3))
	if round_num == arrive - 1 or (round_num >= arrive and reinforcements["cells"].is_empty()):
		var spots: Array = []
		var cols: Array = range(grid.cols - 1, grid.cols / 2, -1)
		for c in cols:
			for r in grid.rows:
				var cell := Vector2i(c, r)
				if spots.size() < reinforcements["enemies"].size() and grid.walkable_terrain(cell) and unit_at(cell) == null:
					spots.append(cell)
		reinforcements["cells"] = spots
		_emit({ "t": "telegraph", "cells": spots, "name": "Reinforcements" })
	if round_num >= arrive:
		var i := 0
		for rec in reinforcements["enemies"]:
			var r: Dictionary = EnemyMods.apply(db, rec if typeof(rec) == TYPE_DICTIONARY else DT.index_under(db, "enemies/", "enemies").get(str(rec), {}))
			if r.is_empty():
				continue
			var cell: Vector2i = reinforcements["cells"][i] if i < reinforcements["cells"].size() else _free_near(Vector2i(grid.cols - 1, grid.rows / 2))
			if unit_at(cell) != null:
				cell = _free_near(cell)
			var s := UnitScript.from_enemy(r, float(r.get("scale", 1.0)))
			s.cell = cell
			s.role = "fighter"
			_add_unit(s)
			_emit({ "t": "spawn", "unit": s.id, "cell": cell, "prop": false })
			i += 1
		_emit({ "t": "log", "text": "Reinforcements arrive!" })
		reinforcements = {}
		_build_order_keep_current()


## Put a unit on its spawn cell, or the nearest free cell on its side.
func _place(u: UnitScript, spawns: Array, i: int, left_side: bool) -> void:
	var occ := occupied()
	var cell := Vector2i(-1, -1)
	if i < spawns.size() and not occ.has(spawns[i]):
		cell = spawns[i]
	else:
		var cols: Array = range(grid.cols) if left_side else range(grid.cols - 1, -1, -1)
		for c in cols:
			for r in grid.rows:
				var cand := Vector2i(c, r)
				if cell.x < 0 and grid.walkable_terrain(cand) and not occ.has(cand):
					cell = cand
	u.cell = cell
	_add_unit(u)


# --- Queries ------------------------------------------------------------------

## cell -> unit for every unit still on the grid (downed units stay as bodies).
func occupied(except: UnitScript = null) -> Dictionary:
	var out := {}
	for u in units:
		if u != except and not u.dead:
			out[u.cell] = u
	return out


## Status ids on a unit for display, in a fixed order (icons and names in data/ui.json).
func status_list(u: UnitScript) -> Array:
	var out: Array = []
	for s in ["root", "slow", "blind", "haste", "rally"]:
		if u.statuses.has(s):
			out.append(s)
	if not u.infusion.is_empty():
		out.append("infusion")
	if u.guard_active:
		out.append("guard")
	if u.shield > 0:
		out.append("shield")
	for s in ["rime", "tether", "pact", "regen", "taunting", "brace", "parry", "haste_full"]:
		if u.statuses.has(s):
			out.append(s)
	for k in u.statuses:
		if str(k).begins_with("empower_"):
			out.append("empowered")
			break
	return out


func unit_at(cell: Vector2i) -> UnitScript:
	for u in units:
		if not u.dead and u.cell == cell:
			return u
	return null


func unit_by_id(id: String) -> UnitScript:
	for u in units:
		if u.id == id:
			return u
	return null


func sight_blockers() -> Dictionary:
	var out := {}
	for u in units:
		if not u.dead and u.is_prop() and u.blocks_sight:
			out[u.cell] = true
	return out


func is_hostile(a: UnitScript, b: UnitScript) -> bool:
	return a.team != b.team and not a.is_prop() and not b.is_prop()


func opponents_of(u: UnitScript) -> Array:
	var out: Array = []
	for o in units:
		if o.alive() and is_hostile(u, o) and not o.statuses.has("burrowed"):
			out.append(o)
	return out


func allies_of(u: UnitScript, include_downed: bool = false) -> Array:
	var out: Array = []
	for o in units:
		if o.team == u.team and not o.is_prop() and not o.dead and (include_downed or not o.downed):
			out.append(o)
	return out


func form_rec(form_id: String) -> Dictionary:
	return forms.get(form_id, {})


func card_of(u: UnitScript, hand_index: int) -> Dictionary:
	if u.deck == null or hand_index < 0 or hand_index >= u.deck.hand.size():
		return {}
	return CardRules.resolve(db, str(u.deck.hand[hand_index]), library)


## MP cost of a card for this caster (Triage makes heals cheaper on hurt allies).
func card_cost(u: UnitScript, card: Dictionary, target: Vector2i = Vector2i(-1, -1)) -> int:
	var c := CardRules.cost(db, card)
	if u.perk == "prism" and CardRules.is_spell(card) and CardRules.ordered_vectors(db, card.get("vectors", {})).size() > 1:
		c = maxi(0, c - int(db.get("vectors", {}).get("hybridExtraCost", 1)))
	if (u.perk == "triage" or u.perk == "lifeline") and CardRules.heals(card):
		var t := unit_at(target)
		if t != null and t.team == u.team and t.hp_ratio() < 0.5:
			c = maxi(0, c - 1)
	return c


func reachable_cells(u: UnitScript) -> Dictionary:
	var r := grid.reachable(u.cell, u.move_left, occupied(u))
	r.erase(u.cell)
	return r


# --- Turn flow ----------------------------------------------------------------

func _build_order() -> void:
	order = []
	for u in units:
		if u.alive() and not u.is_prop():
			order.append(u)
	order.sort_custom(func(a: UnitScript, b: UnitScript) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		if a.team != b.team:
			return a.team == "party"
		return a.spawn_index < b.spawn_index)


## The rest of this round and the next round, for the timeline display.
func timeline_rounds() -> Dictionary:
	var now: Array = []
	for i in range(maxi(0, turn_index), order.size()):
		if order[i].alive():
			now.append(order[i])
	var next: Array = []
	for u in units:
		if u.alive() and not u.is_prop():
			next.append(u)
	next.sort_custom(func(a: UnitScript, b: UnitScript) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		if a.team != b.team:
			return a.team == "party"
		return a.spawn_index < b.spawn_index)
	return { "now": now, "next": next, "round": round_num }


## Units in timeline order from the current one, then the next round.
func timeline(count: int = 12) -> Array:
	var out: Array = []
	for i in range(maxi(0, turn_index), order.size()):
		if order[i].alive():
			out.append(order[i])
	var next: Array = []
	for u in units:
		if u.alive() and not u.is_prop():
			next.append(u)
	next.sort_custom(func(a: UnitScript, b: UnitScript) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		if a.team != b.team:
			return a.team == "party"
		return a.spawn_index < b.spawn_index)
	while out.size() < count and not next.is_empty():
		out.append_array(next)
	return out.slice(0, count)


func end_turn() -> void:
	_pending_decoys.clear()
	_check_end()
	if result != "" or current == null:
		return
	_end_cleanup(current)
	_advance()


func _advance() -> void:
	while result == "":
		turn_index += 1
		if turn_index >= order.size():
			_end_round()
			_build_order()
			turn_index = 0
			if order.is_empty():
				return
			_emit({ "t": "round", "n": round_num })
			_reinforce()
		var u: UnitScript = order[turn_index]
		if not u.alive():
			continue
		current = u
		_start_turn(u)
		# Burning tiles, hazards, auras and Fatigue can end the fight here.
		_check_end()
		if result != "":
			return
		if not u.alive():
			_end_cleanup(u)
			continue
		return


func _end_round() -> void:
	round_num += 1
	for d in delayed.duplicate():
		d["turns"] = int(d["turns"]) - 1
		if int(d["turns"]) <= 0:
			delayed.erase(d)
			var caster: UnitScript = d["caster"]
			_emit({ "t": "area", "cells": d["cells"], "vectors": d["spec"]["vectors"] })
			_emit({ "t": "log", "text": "%s lands." % d.get("name", "The strike") })
			for c in d["cells"]:
				var t := unit_at(c)
				if t != null and t.alive() and t != caster and (bool(d["neutral"]) or is_hostile(caster, t)):
					_hit_unit(caster, t, d["spec"], false)
			_check_end()
	revealed = maxi(0, revealed - 1)
	grid.tick_round()
	for g in glyphs.duplicate():
		g["turns"] = int(g["turns"]) - 1
		if int(g["turns"]) <= 0:
			glyphs.erase(g)
	for u in units:
		if u.is_prop() and not u.dead and u.expires > 0:
			u.expires -= 1
			if u.expires == 0:
				u.dead = true
				_emit({ "t": "vanish", "unit": u.id, "cell": u.cell })


func _start_turn(u: UnitScript) -> void:
	u.turns_taken += 1
	u.guard_active = false
	u.action_used = false
	u.quick_used = false
	u.moved_steps = 0
	u.undo_ok = true
	_emit({ "t": "turn", "unit": u.id })
	if u.shield_turns > 0:
		u.shield_turns -= 1
		if u.shield_turns == 0:
			u.shield = 0
	_resolve_help_calls(u)
	var cfg := Res.combat_cfg(db)
	if grid.burning.has(u.cell):
		_damage(u, int(cfg.get("burnDamage", 3)), null, "heat", "burn")
	if grid.get_terrain(u.cell) == GridScript.HAZARD:
		_damage(u, int(cfg.get("hazardDamage", 4)), null, "", "hazard")
	if grid.toxic.has(u.cell):
		_damage(u, int(cfg.get("toxicDamage", 3)), null, "corrosion", "toxic")
		u.defense_shred += 1
	for s in ["parry", "brace", "dash"]:
		u.statuses.erase(s)
	if bool(u.source.get("anchorRoot", false)) and u.alive():
		for o in opponents_of(u):
			if GridScript.manhattan(o.cell, u.cell) == 1 and not o.statuses.has("root"):
				o.statuses["root"] = 1
				_emit({ "t": "status", "unit": o.id, "status": "root" })
	if u.statuses.has("regen") and u.alive():
		_heal(u, u, int(str(u.links.get("regen", "3"))))
	if not u.alive():
		return
	for aura in u.auras.duplicate():
		_tick_aura(u, aura)
		aura["turns"] = int(aura["turns"]) - 1
		if int(aura["turns"]) <= 0:
			u.auras.erase(aura)
	if u.deck != null:
		var n := int(cfg.get("drawPerTurn", 2)) + int(u.mods.get("combat", {}).get("drawBonus", 0))
		if u.statuses.has("hype_draw"):
			n += 1
			u.statuses.erase("hype_draw")
		var drew := u.deck.draw(n, rng)
		if int(drew["fatigue"]) > 0:
			_emit({ "t": "log", "text": "%s reshuffles and takes %d Fatigue." % [u.name, int(drew["fatigue"])] })
			_damage(u, int(drew["fatigue"]), null, "", "fatigue")
			if not u.alive():
				return
	if u.max_mp > 0:
		u.mp = mini(u.max_mp, u.mp + u.mp_regen)
	u.move_left = u.movement + int(u.statuses.get("haste_amount", 0)) - (1 if u.statuses.has("slow") else 0)
	if u.statuses.has("root"):
		u.move_left = 0
	u.move_left = maxi(0, u.move_left)
	u.start_cell = u.cell
	if u.team == "party":
		refresh_intents()
	if u.guest and u.alive():
		var threatened := u.hp_ratio() < 0.6
		for o in opponents_of(u):
			if GridScript.manhattan(o.cell, u.cell) == 1:
				threatened = true
		if threatened:
			help_calls.append({ "unit": u.id, "round": round_num, "answered": false, "open": true })
			_emit({ "t": "say", "unit": u.id, "text": str(u.source.get("helpLine", "Help! A little help here?!")) })


func _end_cleanup(u: UnitScript) -> void:
	for s in ["slow", "root", "blind", "haste", "rally", "rime", "tether", "pact", "regen", "taunting", "haste_full"]:
		if u.statuses.has(s):
			u.statuses[s] = int(u.statuses[s]) - 1
			if int(u.statuses[s]) <= 0:
				u.statuses.erase(s)
				if s == "haste":
					u.statuses.erase("haste_amount")
				if s == "rally":
					u.rally_bonus = 0.0


## Open help calls from a guest close (ignored) when the guest's next turn comes.
func _resolve_help_calls(u: UnitScript) -> void:
	for call in help_calls:
		if bool(call["open"]) and str(call["unit"]) == u.id:
			call["open"] = false
			if not bool(call["answered"]):
				_emit({ "t": "log", "text": "Nobody came when %s called for help." % u.name })


func _answer_help(helper: UnitScript, target: UnitScript) -> void:
	if helper.ai_controlled:
		return
	for call in help_calls:
		if bool(call["open"]) and str(call["unit"]) == target.id:
			call["answered"] = true


# --- Movement -----------------------------------------------------------------

## Whether this unit may still move this turn under the turn mode.
func can_move(u: UnitScript) -> bool:
	if u.move_left <= 0:
		return false
	if u.action_used and turn_mode != "move_and_act" and not _moves_and_acts(u):
		return false
	return true


## Whether this unit may still take its action: under move_or_act, not after moving.
func act_block(u: UnitScript) -> String:
	if u.action_used:
		return "No action left"
	if turn_mode == "move_or_act" and u.moved_steps > 0 and not _moves_and_acts(u):
		return "Already moved (undo the move to act)"
	return ""


## Who may move and act in one turn. Enemies always telegraph during the
## player's turn and carry it out on their own. On Normal they either hit from
## where they stand or move into position; on Hard they move, then attack
## (data/combat_rules.json "difficulties", user decision Oct 24). Data
## "moveAndAct" (fast elites) or Haste lets anyone do both.
func _moves_and_acts(u: UnitScript) -> bool:
	if bool(u.source.get("moveAndAct", false)) or u.statuses.has("haste_full"):
		return true
	return u.team == "enemy" and bool(difficulty_rules().get("enemyMoveAndAct", false))


## The combat difficulty's rules (normal or hard).
func difficulty_rules() -> Dictionary:
	return db.get("combat_rules", {}).get("difficulties", {}).get(difficulty, {})


func move(u: UnitScript, dest: Vector2i) -> bool:
	if result != "" or u != current or not u.alive() or not can_move(u):
		return false
	var reach := reachable_cells(u)
	if not reach.has(dest):
		return false
	var path := grid.path(u.cell, dest, occupied(u))
	if path.is_empty() or path.size() > u.move_left:
		return false
	var walked: Array = []
	var prev := u.cell
	var slide_dir := Vector2i.ZERO
	for cell in path:
		u.cell = cell
		walked.append(cell)
		u.move_left -= 1
		u.moved_steps += 1
		if _enter_cell(u, cell):
			u.undo_ok = false
			break
		if grid.get_terrain(cell) == GridScript.ICE:
			slide_dir = cell - prev
			break
		prev = cell
	_emit({ "t": "move", "unit": u.id, "path": walked })
	_leave_trail(u, [u.start_cell] + walked.slice(0, walked.size() - 1))
	for pd in _pending_decoys.duplicate():
		if pd["cell"] != u.cell and unit_at(pd["cell"]) == null:
			_pending_decoys.erase(pd)
			var d: UnitScript = pd["prop"]
			d.cell = pd["cell"]
			_add_unit(d)
			_emit({ "t": "spawn", "unit": d.id, "cell": d.cell, "prop": true })
	if slide_dir != Vector2i.ZERO and u.alive():
		u.undo_ok = false
		_slide(u, slide_dir)
	_face_nearest(u)
	if u.intent.has("move"):
		u.intent["move"] = u.cell
	_check_end()
	return true


## Hazard makers (data "trail") leave fire, ice or glyphs behind them.
func _leave_trail(u: UnitScript, cells: Array) -> void:
	var kind := str(u.source.get("trail", ""))
	if kind == "" or cells.is_empty():
		return
	for c in cells:
		var cell: Vector2i = c
		if unit_at(cell) != null and unit_at(cell) != u:
			continue
		match kind:
			"burning":
				grid.burning[cell] = 2
			"ice":
				if grid.get_terrain(cell) == GridScript.FLOOR:
					grid.set_terrain(cell, GridScript.ICE)
			"glyph":
				glyphs.append({ "cell": cell, "spec": action_spec(u, { "form": "touch", "vectors": { "binding": 1.0 }, "power": 3, "name": "Snare Trail" }),
					"team": u.team, "caster": u, "turns": 3 })
	_emit({ "t": "tiles", "kind": kind, "cells": cells })


## Ice: a unit that steps or is pushed onto ice keeps going until something stops it.
func _slide(u: UnitScript, dir: Vector2i) -> void:
	var from := u.cell
	while u.alive():
		var next := u.cell + dir
		if not grid.in_bounds(next) or not grid.walkable_terrain(next) or unit_at(next) != null:
			break
		u.cell = next
		if _enter_cell(u, next):
			break
		if grid.get_terrain(next) != GridScript.ICE:
			break
	if u.cell != from:
		_shift_intent(u, u.cell - from)
		_emit({ "t": "slide", "unit": u.id, "from": from, "to": u.cell })


## Undo this turn's move (before acting): back to the start tile with full Movement.
func can_undo_move(u: UnitScript) -> bool:
	return u == current and u.moved_steps > 0 and u.undo_ok and not u.action_used and not u.quick_used and u.cell != u.start_cell \
		and (unit_at(u.start_cell) == null or unit_at(u.start_cell) == u)


func undo_move(u: UnitScript) -> bool:
	if not can_undo_move(u):
		return false
	var from := u.cell
	u.cell = u.start_cell
	u.move_left += u.moved_steps
	u.moved_steps = 0
	_face_nearest(u)
	_emit({ "t": "undo", "unit": u.id, "from": from, "to": u.cell })
	return true


## Effects of stepping onto a cell. Returns true if movement must stop.
func _enter_cell(u: UnitScript, cell: Vector2i) -> bool:
	var cfg := Res.combat_cfg(db)
	for g in glyphs.duplicate():
		if g["cell"] == cell and str(g["team"]) != u.team:
			glyphs.erase(g)
			_emit({ "t": "glyph", "cell": cell })
			var caster: UnitScript = g["caster"]
			var spec: Dictionary = g["spec"]
			_hit_unit(caster, u, spec, false)
			_apply_vector_effects(caster, spec, [cell], [u])
			return true
	if grid.get_terrain(cell) == GridScript.HAZARD:
		_damage(u, int(cfg.get("hazardDamage", 4)), null, "", "hazard")
		return not u.alive()
	if grid.burning.has(cell):
		_damage(u, int(cfg.get("burnDamage", 3)), null, "heat", "burn")
		return not u.alive()
	return false


func _face_nearest(u: UnitScript) -> void:
	var best: UnitScript = null
	for o in opponents_of(u):
		if best == null or GridScript.manhattan(o.cell, u.cell) < GridScript.manhattan(best.cell, u.cell):
			best = o
	if best != null and best.cell.x != u.cell.x:
		u.facing = signi(best.cell.x - u.cell.x)


# --- Cards --------------------------------------------------------------------

## Valid target cells for a card in hand.
func card_targets(u: UnitScript, card: Dictionary) -> Array:
	if card.is_empty():
		return []
	if card.has("targeting"):
		return _generic_targets(u, card["targeting"])
	if CardRules.is_spell(card):
		return _spell_targets(u, form_rec(str(card.get("form", ""))), CardRules.heals(card))
	match str(card.get("action", "")):
		"strike":
			return _adjacent_hostiles(u, int(card.get("range", 1)))
		"guard", "dash", "rally":
			return [u.cell]
		"heal":
			var out: Array = []
			for a in allies_of(u, true):
				if GridScript.manhattan(a.cell, u.cell) <= int(card.get("range", 1)):
					out.append(a.cell)
			return out
	return []


## Card "targeting": { "type": self | enemy | ally | unit | empty | any | dir, "range": n, "los": bool }.
func _generic_targets(u: UnitScript, tg: Dictionary) -> Array:
	var kind := str(tg.get("type", "any"))
	var reach := int(tg.get("range", 1))
	if kind == "self":
		return [u.cell]
	var out: Array = []
	for c in grid.all_cells():
		var cell: Vector2i = c
		var d := GridScript.manhattan(cell, u.cell)
		if d > reach or (d == 0 and kind != "ally" and kind != "unit"):
			continue
		if bool(tg.get("los", false)) and d > 0 and not grid.has_los(u.cell, cell, sight_blockers()):
			continue
		var t := unit_at(cell)
		match kind:
			"enemy":
				if t != null and is_hostile(u, t) and t.alive() and not t.statuses.has("burrowed"):
					out.append(cell)
			"ally":
				if t != null and t.team == u.team and not t.is_prop() and (t.alive() or bool(tg.get("downed", false))):
					out.append(cell)
			"unit":
				if t != null and t != u and not t.is_prop() and t.alive():
					out.append(cell)
			"empty":
				if t == null and grid.walkable_terrain(cell):
					out.append(cell)
			"dir":
				if (cell.x == u.cell.x or cell.y == u.cell.y) and grid.get_terrain(cell) != GridScript.WALL:
					out.append(cell)
			_:
				if grid.get_terrain(cell) != GridScript.WALL:
					out.append(cell)
	return out


func _spell_targets(u: UnitScript, form: Dictionary, heals: bool) -> Array:
	var cells := Forms.valid_targets(grid, form, u.cell, occupied(), sight_blockers())
	var kind := str(form.get("target", "any"))
	if kind == "ally":
		var out: Array = []
		for c in cells:
			var t := unit_at(c)
			if t != null and t.team == u.team and not t.is_prop() and (t.alive() or heals):
				out.append(c)
		return out
	return cells


func _adjacent_hostiles(u: UnitScript, reach: int) -> Array:
	var out: Array = []
	for o in units:
		if o.dead or o.downed or o == u:
			continue
		if (is_hostile(u, o) or o.is_prop()) and not o.statuses.has("burrowed") and GridScript.manhattan(o.cell, u.cell) <= reach:
			out.append(o.cell)
	return out


## Why a card can't be played right now, or "" (cost and action economy).
## Quick cards use the turn's quick slot; anything else, or a second quick
## card, uses the action.
func card_block(u: UnitScript, card: Dictionary) -> String:
	if card.is_empty():
		return "No card"
	if bool(card.get("quick", false)) and not u.quick_used:
		pass
	elif act_block(u) != "" and not (bool(card.get("moves", false)) and not u.action_used):
		return act_block(u)
	var cost := card_cost(u, card)
	if cost > u.mp:
		return "Needs %d MP" % cost
	return ""


## Spend the quick slot or the action for a card.
func _use_slot(u: UnitScript, card: Dictionary) -> void:
	if bool(card.get("quick", false)) and not u.quick_used:
		u.quick_used = true
	else:
		u.action_used = true
	u.undo_ok = false


## Play a card from hand at a target cell. Returns false if illegal.
func play_card(u: UnitScript, hand_index: int, target: Vector2i) -> bool:
	if result != "" or u != current or not u.alive():
		return false
	var card := card_of(u, hand_index)
	if card.is_empty() or not card_targets(u, card).has(target):
		return false
	var cost := card_cost(u, card, target)
	if cost > u.mp or card_block(u, card) != "":
		return false
	_use_slot(u, card)
	u.mp -= cost
	if u.team == "party" and CardRules.is_spell(card):
		last_party_card = card
	u.deck.play(hand_index, bool(card.get("consumable", false)) or bool(card.get("oncePerFight", false)))
	var cells := effect_cells(u, card, target)
	if CardRules.is_spell(card) and not bool(card.get("effectsOnly", false)):
		var mp_before := u.mp + cost
		_cast(u, card, target, false, cost, mp_before)
	elif not CardRules.is_spell(card) and str(card.get("action", "")) != "effects":
		_basic(u, card, target)
	else:
		_emit({ "t": "cast", "unit": u.id, "name": str(card.get("name", "")), "target": target, "improvised": false })
	if card.has("effects") and result == "":
		_effects_script().run(self, u, card, target, cells)
	_check_end()
	return true


func _effects_script() -> GDScript:
	if _fx == null:
		_fx = load("res://src/core/combat/card_effects.gd")
	return _fx


## The cells a card covers at a target (its Form's footprint, or the target tile).
func effect_cells(u: UnitScript, card: Dictionary, target: Vector2i) -> Array:
	if card.has("area"):
		var form := { "footprint": str(card["area"]), "range": int(card.get("targeting", {}).get("range", 4)) }
		return Forms.footprint(grid, form, u.cell, target, occupied())
	if CardRules.is_spell(card):
		return Forms.footprint(grid, _spell_spec(u, card)["form"], u.cell, target, occupied())
	return [target]


## The basic Strike (adjacent, STR): always available as the turn's action.
func strike(u: UnitScript, target: Vector2i) -> bool:
	if result != "" or u != current or act_block(u) != "" or not u.alive():
		return false
	if not _adjacent_hostiles(u, 1).has(target):
		return false
	u.action_used = true
	u.undo_ok = false
	_basic(u, { "action": "strike", "stat": "str", "mult": 1.0, "name": "Strike" }, target)
	_check_end()
	return true


## The basic Guard (uses the action; the Guard card is a quick card instead).
func guard(u: UnitScript) -> bool:
	if result != "" or u != current or act_block(u) != "" or not u.alive():
		return false
	u.action_used = true
	u.undo_ok = false
	u.guard_active = true
	_emit({ "t": "guard", "unit": u.id })
	_guard_aura(u)
	return true


## Guardian: Guard also shields every adjacent ally for 5.
func _guard_aura(u: UnitScript) -> void:
	if u.perk != "bulwark_aura":
		return
	for a in allies_of(u):
		if a != u and GridScript.manhattan(a.cell, u.cell) == 1:
			a.shield += 5
			a.shield_turns = maxi(a.shield_turns, 1)
			_emit({ "t": "shield", "unit": a.id, "amount": 5 })


## Improvise with the Vector Wheel: any legal spell from known Vectors and Forms.
## Costs ceil(cost x 1.5) + 1 MP and a card from hand as fuel; always rolls
## Instability with +3. Overchannel (Mage) improvises once per fight at normal cost.
func improvise_cost(u: UnitScript, card: Dictionary) -> int:
	if u.perk == "overchannel" and not u.perk_used:
		return CardRules.spell_cost(db, card)
	return CardRules.improvise_cost(db, card)


func improvise_error(u: UnitScript, vectors: Array, form: String, magnitude: String) -> String:
	var fake := { "knownVectors": u.known_vectors, "knownForms": u.known_forms, "knowledgeTier": u.knowledge_tier }
	var err := CardRules.design_error(db, fake, vectors, form, magnitude)
	if err != "":
		return err
	if act_block(u) != "":
		return act_block(u)
	if u.deck == null or u.deck.hand.is_empty():
		return "You need a card in hand to burn as fuel."
	var v := {}
	for a in vectors:
		v[a] = 1.0
	if improvise_cost(u, CardRules.make_spell(db, v, form, magnitude)) > u.mp:
		return "Not enough MP."
	return ""


func improvise(u: UnitScript, vectors: Array, form: String, magnitude: String, fuel_index: int, target: Vector2i) -> bool:
	if result != "" or u != current or not u.alive():
		return false
	if improvise_error(u, vectors, form, magnitude) != "":
		return false
	var v := {}
	for a in vectors:
		v[a] = 1.0
	var card := CardRules.make_spell(db, v, form, magnitude)
	if not card_targets(u, card).has(target):
		return false
	if fuel_index < 0 or fuel_index >= u.deck.hand.size():
		return false
	var cost := improvise_cost(u, card)
	var mp_before := u.mp
	if u.perk == "overchannel" and not u.perk_used:
		u.perk_used = true
	u.action_used = true
	u.undo_ok = false
	u.mp -= cost
	u.deck.discard_from_hand(fuel_index)
	card["name"] = "Improvised " + str(card["name"])
	_cast(u, card, target, true, cost, mp_before)
	_check_end()
	return true


## Preview a card or improvised spell: affected cells, expected hits and Instability odds.
func preview(u: UnitScript, card: Dictionary, target: Vector2i, improvised: bool = false) -> Dictionary:
	var out := { "cells": [], "hits": [], "chance": 1.0, "cost": 0 }
	if card.is_empty():
		return out
	if CardRules.is_spell(card):
		var form := Forms.at_magnitude(form_rec(str(card.get("form", ""))), str(card.get("magnitude", "")))
		var cells := Forms.footprint(grid, form, u.cell, target, occupied())
		out["cells"] = cells
		var cost := improvise_cost(u, card) if improvised else card_cost(u, card, target)
		out["cost"] = cost
		var spec := _spell_spec(u, card)
		out["chance"] = Res.stability_chance(db, u.stability + int(spec.get("stabilityBonus", 0)), cost, u.mp, improvised and u.perk != "unstable")
		var n := 0
		for c in area_order(cells, target):
			var t := unit_at(c)
			if t == null:
				continue
			if bool(spec["heal"]) and t.team == u.team:
				out["hits"].append({ "unit": t.id, "heal": _heal_value(u, spec) })
			elif float(spec["mult"]) > 0.0 and (is_hostile(u, t) or t.is_prop()):
				n += 1
				out["hits"].append({ "unit": t.id, "damage": roundi(_expected_hit(u, t, _area_spec(spec, n))), "status": _preview_statuses(spec["vectors"], t) })
		_preview_motion(u, spec, out)
	else:
		out["cells"] = [target]
		out["cost"] = card_cost(u, card, target)
		var t := unit_at(target)
		if t != null and str(card.get("action", "")) == "strike":
			out["hits"].append({ "unit": t.id, "damage": roundi(_expected_strike(u, t, card)) })
		elif t != null and str(card.get("action", "")) == "heal":
			out["hits"].append({ "unit": t.id, "heal": Res.heal_amount(float(card.get("amount", 10)), u) })
	return out


# --- Resolution ----------------------------------------------------------------

## Statuses a hit would leave (for the preview).
func _preview_statuses(v: Dictionary, t: UnitScript) -> Array:
	var out: Array = []
	if t.is_prop():
		return out
	for pair in [["cold", "slow"], ["binding", "root"], ["light", "blind"], ["corrosion", "corroded"]]:
		if v.has(pair[0]):
			out.append(pair[1])
	return out


## Where pushed or pulled units would land, collisions, hazards, slides and
## interrupted charges, added to a preview.
func _preview_motion(u: UnitScript, spec: Dictionary, out: Dictionary) -> void:
	var v: Dictionary = spec["vectors"]
	var pushes: Array = []
	var interrupts: Array = []
	for h in out["hits"]:
		if not h.has("damage"):
			continue
		var t := unit_by_id(str(h["unit"]))
		if t == null:
			continue
		var land := {}
		if v.has("force"):
			var share := float(VO.normalize_sum(v).get("force", 1.0))
			var steps := maxi(1, floori(float(spec["power"]) * share / 10.0)) + (1 if u.perk == "momentum" else 0)
			land = push_landing(u, t, Forms.direction_to(u.cell, t.cell) if u.cell != t.cell else Vector2i(u.facing, 0), steps, true)
		elif v.has("motion") and not t.is_prop() and GridScript.manhattan(t.cell, u.cell) > 1:
			land = push_landing(u, t, Forms.direction_to(t.cell, u.cell), 1, false)
		if not land.is_empty():
			pushes.append(land)
		if int(t.intent.get("charge", 0)) > 0:
			if v.has("light"):
				interrupts.append({ "unit": t.id, "effect": "cancels the charge" })
			elif v.has("cold"):
				interrupts.append({ "unit": t.id, "effect": "delays the charge" })
			elif not land.is_empty() and land["to"] != t.cell:
				interrupts.append({ "unit": t.id, "effect": "moves the charge" })
	out["pushes"] = pushes
	out["interrupts"] = interrupts


## Where a push would leave a unit, without moving it: { unit, from, to,
## collide, damage, hazard, slide }.
func push_landing(u: UnitScript, t: UnitScript, dir: Vector2i, steps: int, collide: bool) -> Dictionary:
	var cell := t.cell
	var out := { "unit": t.id, "from": t.cell, "to": t.cell, "collide": false, "damage": 0, "hazard": false, "slide": false }
	var budget := steps
	var sliding := false
	while budget > 0 or sliding:
		var next := cell + dir
		var blocker := unit_at(next)
		if not grid.in_bounds(next) or not grid.walkable_terrain(next) or (blocker != null and blocker != t):
			if collide and not sliding:
				out["collide"] = true
				out["damage"] = int(Res.combat_cfg(db).get("collisionDamage", 4)) + (4 if u.perk == "momentum" else 0)
			break
		cell = next
		budget -= 1
		var ter := grid.get_terrain(cell)
		if ter == GridScript.HAZARD or grid.burning.has(cell):
			out["hazard"] = true
		for g in glyphs:
			if g["cell"] == cell and str(g["team"]) != t.team:
				out["hazard"] = true
		sliding = ter == GridScript.ICE and budget <= 0
		if sliding:
			out["slide"] = true
	out["to"] = cell
	return out


## A spell as a resolution spec (shared by cards and enemy actions).
func _spell_spec(u: UnitScript, card: Dictionary) -> Dictionary:
	var form := Forms.at_magnitude(form_rec(str(card.get("form", ""))), str(card.get("magnitude", "")))
	# Flashover: a bigger area while standing in fire.
	if card.has("footprintIfBurning") and grid.burning.has(u.cell):
		form = form.duplicate()
		form["footprint"] = str(card["footprintIfBurning"])
	var power := CardRules.power(db, card) if card.has("magnitude") else float(card.get("power", 5))
	for axis in card.get("vectors", {}):
		power *= float(u.statuses.get("empower_" + str(axis), 1.0))
	return {
		"bonusVs": card.get("bonusVs", {}),
		"name": str(card.get("name", "Spell")),
		"vectors": card.get("vectors", {}),
		"form": form,
		"power": power,
		"mult": 0.0 if bool(card.get("noDamage", false)) else float(form.get("multiplier", 1.0)),
		"heal": CardRules.heals(card),
		"ranged": int(form.get("range", 1)) > 1,
		"kind": "spell",
		"critBonus": float(CardRules.property_mods(db, card).get("critPct", 0.0)),
		"stabilityBonus": int(CardRules.property_mods(db, card).get("stability", 0.0)),
	}


func _expected_hit(u: UnitScript, t: UnitScript, spec: Dictionary) -> float:
	var area := float(spec.get("areaMul", 1.0))
	# Shield bearers block hits from the front; flank them or push them around.
	var guard := float(t.source.get("frontGuard", 0.0))
	if guard > 0.0 and u.cell.x != t.cell.x and signi(u.cell.x - t.cell.x) == t.facing:
		area *= 1.0 - guard
	# Shatter and friends: bonus against targets with certain statuses.
	var bonus: Dictionary = spec.get("bonusVs", {})
	for s in bonus.get("statuses", []):
		if t.statuses.has(str(s)):
			area *= float(bonus.get("mul", 2.0))
			break
	if str(spec.get("kind", "spell")) == "strike":
		return Res.strike_damage(db, float(spec["base"]), u, t, _shared(u, t, false)) * area
	return Res.spell_damage(db, float(spec["power"]), float(spec["mult"]), spec["vectors"], u, t, _shared(u, t, bool(spec["ranged"]))) * area


## Area cells nearest the aim point first (for the falloff rule).
func area_order(cells: Array, target: Vector2i) -> Array:
	var out := cells.duplicate()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := GridScript.manhattan(a, target)
		var dbb := GridScript.manhattan(b, target)
		if da != dbb:
			return da < dbb
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## The nth target of an area attack: beyond the first `fullHits`, damage is reduced.
func _area_spec(spec: Dictionary, n: int) -> Dictionary:
	var fall: Dictionary = db.get("combat_rules", {}).get("areaFalloff", {})
	if n <= int(fall.get("fullHits", 2)):
		return spec
	var out := spec.duplicate()
	out["areaMul"] = float(fall.get("mul", 0.75))
	return out


func _expected_strike(u: UnitScript, t: UnitScript, card: Dictionary) -> float:
	var base := float(u.stats.get(str(card.get("stat", "str")), 5)) * float(card.get("mult", 1.0))
	base += float(u.mods.get("combat", {}).get("strikePower", 0.0))
	if not u.infusion.is_empty():
		base += float(u.infusion["power"]) * 0.5
	var dmg := Res.strike_damage(db, base, u, t, _shared(u, t, false))
	if not u.infusion.is_empty():
		dmg *= Res.contest_mult(db, u.infusion["vectors"], t)
	return dmg


func _shared(u: UnitScript, t: UnitScript, ranged: bool) -> float:
	var friend := false
	for a in allies_of(u):
		if a != u and GridScript.manhattan(a.cell, u.cell) == 1 and _bond_friendly(u, a):
			friend = true
	return Res.shared_mult(db, u, t, ranged, grid.get_terrain(t.cell) == GridScript.COVER, friend)


## Adjacent allies with Friend Bond or better (+5% damage). Party sources carry
## "bondWithParty" filled in by the game; enemies count as friendly packs.
func _bond_friendly(u: UnitScript, a: UnitScript) -> bool:
	if u.team == "enemy":
		return false
	var bonds: Dictionary = u.source.get("partyBonds", {})
	return float(bonds.get(a.id, 0)) >= 41.0


func _heal_value(u: UnitScript, spec: Dictionary) -> int:
	var base := float(spec["power"])
	if str(spec["form"].get("id", "")) == "aura":
		base *= float(spec["mult"])
	else:
		base *= float(Res.combat_cfg(db).get("shieldHealShare", 0.8))
	return Res.heal_amount(base, u)


func _cast(u: UnitScript, card: Dictionary, target: Vector2i, improvised: bool, cost: int, mp_before: int) -> void:
	var spec := _spell_spec(u, card)
	for axis in card.get("vectors", {}):
		u.statuses.erase("empower_" + str(axis))
	_emit({ "t": "cast", "unit": u.id, "name": spec["name"], "target": target, "improvised": improvised })
	var key := "%s:%s" % ["+".join(PackedStringArray(CardRules.ordered_vectors(db, spec["vectors"]))), str(spec["form"].get("id", ""))]
	var uses: Dictionary = u.source.get("pairUses", {})
	uses[key] = int(uses.get(key, 0)) + 1
	if u.team == "party":
		u.source["pairUses"] = uses
	var roll := Res.roll_stability(db, u.stability + int(spec.get("stabilityBonus", 0)), cost, mp_before, improvised and u.perk != "unstable", rng)
	if not bool(roll["ok"]):
		var failure := Res.roll_failure(db, rng)
		_emit({ "t": "instability", "unit": u.id, "result": failure, "roll": roll["roll"], "need": roll["target"],
			"text": str(db.get("vectors", {}).get("failureText", {}).get(failure, failure)) })
		match failure:
			"fizzle":
				return
			"backlash":
				var self_dmg := Res.spell_damage(db, float(spec["power"]), maxf(0.5, float(spec["mult"])), spec["vectors"], u, u) * 0.5
				_damage(u, maxi(1, roundi(self_dmg)), u, "", "backlash")
				return
			"misfire":
				var options := card_targets(u, card)
				if not options.is_empty():
					target = options[rng.randi_range(0, options.size() - 1)]
			"wild_surge":
				var axis := Res.wild_vector(db, rng)
				spec["vectors"] = { axis: 1.0 }
				spec["heal"] = (axis == "light" or axis == "vitality") and (str(spec["form"].get("id", "")) in ["shield", "aura"])
				wild_surges += 1
				if u.team == "party":
					u.source["wildSurges"] = int(u.source.get("wildSurges", 0)) + 1
				_emit({ "t": "log", "text": "Wild Surge! The spell comes out as %s." % str(axis).capitalize() })
	_resolve_spec(u, spec, target)


## Apply a spell spec at a target (cards, improvised casts and enemy actions).
func _resolve_spec(u: UnitScript, spec: Dictionary, target: Vector2i) -> void:
	var form: Dictionary = spec["form"]
	var fid := str(form.get("id", ""))
	match fid:
		"weapon_infusion":
			u.infusion = { "vectors": spec["vectors"], "power": float(spec["power"]), "strikes": int(form.get("strikes", 2)) + (1 if u.perk == "spellsteel" else 0) }
			_emit({ "t": "status", "unit": u.id, "status": "infused" })
			return
		"shield":
			var t := unit_at(target)
			if t == null:
				return
			if bool(spec["heal"]):
				_heal(u, t, _heal_value(u, spec))
			if t.alive():
				var amount := roundi(float(spec["power"]) * (1.0 + float(u.mods.get("combat", {}).get("shieldPct", 0.0))))
				t.shield += amount
				t.shield_turns = int(form.get("turns", 2))
				_emit({ "t": "shield", "unit": t.id, "amount": amount })
				_apply_ally_effects(u, spec, t)
			_note_support(u, t)
			return
		"aura":
			var aura := { "spec": spec, "turns": int(form.get("turns", 3)) }
			u.auras.append(aura)
			_emit({ "t": "status", "unit": u.id, "status": "aura" })
			_tick_aura(u, aura)
			aura["turns"] = int(aura["turns"]) - 1
			if int(aura["turns"]) <= 0:
				u.auras.erase(aura)
			return
		"construct":
			if occupied().has(target):
				return
			var hp_value := maxi(4, roundi(float(spec["power"]) * float(Res.combat_cfg(db).get("constructHpPerPower", 1))))
			if u.perk == "constructor":
				hp_value *= 2
			var prop := UnitScript.make_prop("construct", hp_value, int(form.get("turns", 3)) + (2 if u.perk == "constructor" else 0))
			prop.cell = target
			prop.name = "%s Construct" % str(spec["name"]).split(" ")[0]
			_add_unit(prop)
			_emit({ "t": "spawn", "unit": prop.id, "cell": target, "prop": true })
			return
		"glyph":
			glyphs.append({ "cell": target, "spec": spec, "team": u.team, "caster": u, "turns": int(form.get("turns", 6)) })
			_emit({ "t": "glyph_set", "cell": target, "team": u.team })
			return
	var cells := Forms.footprint(grid, form, u.cell, target, occupied())
	_emit({ "t": "area", "cells": cells, "vectors": spec["vectors"] })
	var hit: Array = []
	var n := 0
	for c in area_order(cells, target):
		var t := unit_at(c)
		if t == null or t == u:
			continue
		if bool(spec["heal"]):
			if t.team == u.team:
				_heal(u, t, _heal_value(u, spec))
				_note_support(u, t)
		elif is_hostile(u, t) or t.is_prop():
			n += 1
			if _hit_unit(u, t, _area_spec(spec, n), true):
				hit.append(t)
	_apply_vector_effects(u, spec, cells, hit)


## One damaging hit. Returns true if it connected.
func _hit_unit(u: UnitScript, t: UnitScript, spec: Dictionary, can_miss: bool) -> bool:
	if not t.alive():
		return false
	if can_miss and u.statuses.has("blind") and rng.randf() < float(Res.combat_cfg(db).get("blindMissChance", 0.35)):
		_emit({ "t": "miss", "unit": t.id })
		return false
	var dmg := Res.finalize(db, _expected_hit(u, t, spec), u, rng, float(spec.get("critBonus", 0.0)))
	_note = hit_note(u, t, spec["vectors"])
	_damage(t, int(dmg["amount"]), u, VO.dominant_axis(spec["vectors"], CardRules.arcane_axes(db)), "hit", bool(dmg["crit"]))
	_after_hit(u, t, int(dmg["amount"]))
	if spec["vectors"].has("vitality") and u.alive():
		_heal(u, u, maxi(1, roundi(float(dmg["amount"]) * float(Res.combat_cfg(db).get("vitalityDrainPct", 0.5)))))
	_note_support_attack(u, t)
	return true


## Leech enemies drain MP; vampiric ones heal from the hit.
func _after_hit(u: UnitScript, t: UnitScript, amount: int) -> void:
	if float(u.source.get("leech", 0.0)) > 0.0 and t.max_mp > 0 and t.mp > 0:
		var drained := mini(t.mp, maxi(1, ceili(float(amount) * float(u.source["leech"]))))
		t.mp -= drained
		_emit({ "t": "log", "text": "%s drains %d MP from %s." % [u.name, drained, t.name] })
	if float(u.source.get("vampiric", 0.0)) > 0.0 and u.alive() and amount > 0:
		_heal(u, u, maxi(1, roundi(float(amount) * float(u.source["vampiric"]))))


func _basic(u: UnitScript, card: Dictionary, target: Vector2i) -> void:
	var cfg := Res.combat_cfg(db)
	match str(card.get("action", "")):
		"strike":
			var t := unit_at(target)
			if t == null:
				return
			_face_toward(u, t.cell)
			_emit({ "t": "cast", "unit": u.id, "name": str(card.get("name", "Strike")), "target": target, "improvised": false })
			if parried(u, t):
				return
			if u.statuses.has("blind") and rng.randf() < float(cfg.get("blindMissChance", 0.35)):
				_emit({ "t": "miss", "unit": t.id })
				return
			var dmg := Res.finalize(db, _expected_strike(u, t, card), u, rng)
			var axis := ""
			if not u.infusion.is_empty():
				axis = VO.dominant_axis(u.infusion["vectors"], CardRules.arcane_axes(db))
			_note = hit_note(u, t, u.infusion.get("vectors", {}))
			_damage(t, int(dmg["amount"]), u, axis, "hit", bool(dmg["crit"]))
			_note_support_attack(u, t)
			if not u.infusion.is_empty():
				var spec := { "vectors": u.infusion["vectors"], "power": float(u.infusion["power"]), "form": form_rec("touch"), "heal": false, "mult": 1.0, "ranged": false, "name": "Infusion" }
				_apply_vector_effects(u, spec, [t.cell], [t] if t.alive() else [])
				u.infusion["strikes"] = int(u.infusion["strikes"]) - 1
				if int(u.infusion["strikes"]) <= 0:
					u.infusion = {}
		"guard":
			u.guard_active = true
			_emit({ "t": "guard", "unit": u.id })
			_guard_aura(u)
		"dash":
			u.move_left += int(card.get("amount", 2))
			_emit({ "t": "status", "unit": u.id, "status": "dash" })
		"rally":
			for a in allies_of(u):
				if GridScript.manhattan(a.cell, u.cell) <= int(card.get("range", 3)) or u.perk == "encore":
					a.rally_bonus = float(card.get("amount", 0.2))
					if a == u:
						a.statuses["rally"] = 2
						a.move_left += 1
					else:
						a.statuses["rally"] = 1
						a.statuses["haste"] = 1
						a.statuses["haste_amount"] = 1
					_emit({ "t": "status", "unit": a.id, "status": "rally" })
		"heal":
			var t := unit_at(target)
			if t == null:
				return
			_heal(u, t, Res.heal_amount(float(card.get("amount", 10)) * float(u.mods.get("combat", {}).get("foodMul", 1.0)), u))
			if t.alive() and int(card.get("mp", 0)) > 0:
				t.mp = mini(t.max_mp, t.mp + int(card.get("mp", 0)))
			_note_support(u, t)


## Why a hit lands the way it does, for the combat log: "weak", "resisted",
## "from behind", "cover".
func hit_note(u: UnitScript, t: UnitScript, vectors: Dictionary) -> String:
	var parts: Array = []
	var c := Res.contest_mult(db, vectors, t)
	if c > 1.05:
		parts.append("weak spot")
	elif c < 0.95:
		parts.append("resisted")
	if Res.is_behind(u, t):
		parts.append("from behind")
	if grid.get_terrain(t.cell) == GridScript.COVER and GridScript.manhattan(u.cell, t.cell) > 1:
		parts.append("cover")
	return ", ".join(PackedStringArray(parts))


## Parry: a melee hit on a parrying unit is turned back on the attacker.
func parried(u: UnitScript, t: UnitScript) -> bool:
	if not t.statuses.has("parry") or GridScript.manhattan(u.cell, t.cell) != 1 or not t.alive():
		return false
	t.statuses.erase("parry")
	_emit({ "t": "log", "text": "%s parries and strikes back!" % t.name })
	var dmg := Res.finalize(db, _expected_strike(t, u, { "stat": "str", "mult": 1.0 }), t, rng)
	_damage(u, int(dmg["amount"]), t, "", "hit", bool(dmg["crit"]))
	return true


## Pull enemy telegraphs onto a cell (decoys, Beacon, Taunt): attacks aimed at
## party units within `radius` of it are re-aimed at the cell if they can reach it.
func draw_telegraphs(cell: Vector2i, radius: int) -> void:
	for e in units:
		if e.team != "enemy" or not e.alive() or not str(e.intent.get("kind", "")) in ["attack", "special"]:
			continue
		var aimed: Vector2i = e.intent.get("target", e.cell)
		if GridScript.manhattan(aimed, cell) > radius or e.intent.has("pattern"):
			continue
		if not action_targets(e, e.intent.get("action", {}), e.intent.get("move", e.cell)).has(cell):
			continue
		e.intent["target"] = cell
		e.intent["cells"] = [cell]
		var who := unit_at(cell)
		if who != null:
			e.intent["unit"] = who.id
		_emit({ "t": "interrupt", "unit": e.id, "text": "%s turns toward the lure." % e.name })


func _face_toward(u: UnitScript, cell: Vector2i) -> void:
	if cell.x != u.cell.x:
		u.facing = signi(cell.x - u.cell.x)


func _tick_aura(u: UnitScript, aura: Dictionary) -> void:
	var spec: Dictionary = aura["spec"]
	var cells := Forms.footprint(grid, spec["form"], u.cell, u.cell, occupied())
	_emit({ "t": "area", "cells": cells, "vectors": spec["vectors"] })
	var hit: Array = []
	for c in cells:
		var t := unit_at(c)
		if t == null:
			continue
		if bool(spec["heal"]) and t.team == u.team and t.alive():
			_heal(u, t, _heal_value(u, spec))
		elif not bool(spec["heal"]) and (is_hostile(u, t) or t.is_prop()) and t.alive():
			if _hit_unit(u, t, spec, false):
				hit.append(t)
	if not bool(spec["heal"]):
		_apply_vector_effects(u, spec, [], hit)


## Positional Vector effects (DESIGN.md Section 9, "Vector effects on the grid").
func _apply_vector_effects(u: UnitScript, spec: Dictionary, cells: Array, hit: Array) -> void:
	var cfg := Res.combat_cfg(db)
	var v: Dictionary = spec["vectors"]
	var power := float(spec["power"])
	var root_bonus := int(u.mods.get("combat", {}).get("rootBonus", 0))
	if v.has("heat"):
		for c in cells:
			if grid.get_terrain(c) == GridScript.WATER:
				grid.steam[c] = int(cfg.get("steamTurns", 2))
			elif grid.get_terrain(c) == GridScript.ICE:
				grid.set_terrain(c, GridScript.WATER)
			elif grid.walkable_terrain(c):
				grid.burning[c] = int(cfg.get("burnTurns", 2))
		if not cells.is_empty():
			_emit({ "t": "tiles", "kind": "burning", "cells": cells })
	if v.has("cold"):
		for c in cells:
			if grid.get_terrain(c) == GridScript.WATER:
				grid.set_terrain(c, GridScript.ICE)
		for t in hit:
			if t.alive() and not t.is_prop():
				t.statuses["slow"] = int(cfg.get("slowTurns", 1))
				_emit({ "t": "status", "unit": t.id, "status": "slow" })
				_interrupt(t, "slow")
	if v.has("transmutation"):
		for c in cells:
			var ter := grid.get_terrain(c)
			if ter == GridScript.HAZARD or ter == GridScript.WATER:
				grid.set_terrain(c, GridScript.FLOOR)
			grid.burning.erase(c)
	if v.has("binding"):
		for t in hit:
			if t.alive() and not t.is_prop():
				t.statuses["root"] = int(cfg.get("rootTurns", 1)) + root_bonus
				_emit({ "t": "status", "unit": t.id, "status": "root" })
				_interrupt(t, "root")
				if t.intent.has("move"):
					t.intent["move"] = t.cell
	if v.has("light"):
		for t in hit:
			if t.alive() and not t.is_prop():
				t.statuses["blind"] = int(cfg.get("blindTurns", 1))
				_emit({ "t": "status", "unit": t.id, "status": "blind" })
				_interrupt(t, "blind")
	if v.has("corrosion"):
		for t in hit:
			t.defense_shred += int(cfg.get("corrosionDefense", 2))
			t.resist_shred += int(cfg.get("corrosionResist", 4))
			_emit({ "t": "status", "unit": t.id, "status": "corroded" })
	if v.has("force"):
		var share := float(VO.normalize_sum(v).get("force", 1.0))
		var steps := maxi(1, floori(power * share / 10.0)) + (1 if u.perk == "momentum" else 0)
		for t in hit:
			if t.alive():
				_push(u, t, Forms.direction_to(u.cell, t.cell) if u.cell != t.cell else Vector2i(u.facing, 0), steps)
	if v.has("motion"):
		for t in hit:
			if t.alive() and not t.is_prop() and GridScript.manhattan(t.cell, u.cell) > 1:
				_push(u, t, Forms.direction_to(t.cell, u.cell), 1, false)


## Push (or pull) a unit. Collisions with walls, edges or units deal bonus damage.
func _push(u: UnitScript, t: UnitScript, dir: Vector2i, steps: int, collide: bool = true) -> void:
	if t.statuses.has("brace") and t != u:
		_emit({ "t": "log", "text": "%s braces and doesn't budge." % t.name })
		return
	var from := t.cell
	for i in steps:
		var next := t.cell + dir
		var blocker := unit_at(next)
		if not grid.in_bounds(next) or not grid.walkable_terrain(next) or blocker != null:
			if collide:
				var dmg := int(Res.combat_cfg(db).get("collisionDamage", 4)) + (4 if u.perk == "momentum" else 0)
				_emit({ "t": "collide", "unit": t.id, "cell": next })
				_damage(t, dmg, u, "force", "collision")
				if blocker != null and blocker.alive():
					_damage(blocker, dmg, u, "force", "collision")
			break
		t.cell = next
		if _enter_cell(t, next):
			break
	if t.cell != from:
		_emit({ "t": "push", "unit": t.id, "from": from, "to": t.cell })
		_shift_intent(t, t.cell - from)
		if t.alive() and grid.get_terrain(t.cell) == GridScript.ICE:
			_slide(t, dir)


func _apply_ally_effects(u: UnitScript, spec: Dictionary, t: UnitScript) -> void:
	var v: Dictionary = spec["vectors"]
	if v.has("motion"):
		t.statuses["haste"] = 1
		t.statuses["haste_amount"] = 2
		_emit({ "t": "status", "unit": t.id, "status": "haste" })


func _note_support(u: UnitScript, t: UnitScript) -> void:
	if u == t or u.ai_controlled or u.team != "party":
		return
	support_log[t.id] = int(support_log.get(t.id, 0)) + 1
	_answer_help(u, t)


## Hitting an enemy that stands next to a guest also counts as answering a call.
func _note_support_attack(u: UnitScript, t: UnitScript) -> void:
	if u.ai_controlled or u.team != "party":
		return
	for g in units:
		if g.guest and g.alive() and GridScript.manhattan(g.cell, t.cell) == 1:
			_answer_help(u, g)


# --- Damage, healing, death ------------------------------------------------------

func _damage(t: UnitScript, amount: int, source: UnitScript, vector: String, cause: String, crit: bool = false) -> void:
	if t.dead or amount <= 0:
		return
	if t.downed or t.statuses.has("burrowed"):
		return
	if cause == "hit":
		# Pact: an ally shares half; Tether: the linked enemy takes half too.
		var pact := unit_by_id(str(t.links.get("pact", "")))
		if t.statuses.has("pact") and pact != null and pact.alive():
			var half := amount / 2
			amount -= half
			_damage(pact, half, source, vector, "pact")
		var tied := unit_by_id(str(t.links.get("tether", "")))
		if t.statuses.has("tether") and tied != null and tied.alive():
			_damage(tied, maxi(1, amount / 2), source, vector, "tether")
		if t.statuses.has("rime") and source != null and source.alive() and GridScript.manhattan(source.cell, t.cell) == 1:
			source.statuses["slow"] = 1
			_emit({ "t": "status", "unit": source.id, "status": "slow" })
	var absorbed := mini(t.shield, amount)
	t.shield -= absorbed
	var rest := amount - absorbed
	t.hp = maxi(0, t.hp - rest)
	_emit({ "t": "damage", "unit": t.id, "amount": rest, "absorbed": absorbed, "crit": crit, "vector": vector, "cause": cause,
		"source": source.id if source != null else "", "note": _note })
	_note = ""
	if t.hp <= 0:
		_on_zero_hp(t, source)
		return
	if t.perk == "second_wind" and not t.perk_used and t.hp_ratio() < float(Res.combat_cfg(db).get("secondWindBelowPct", 0.3)):
		t.perk_used = true
		_heal(t, t, maxi(1, roundi(float(t.max_hp) * float(Res.combat_cfg(db).get("secondWindHpPct", 0.2)))))
		_emit({ "t": "log", "text": "%s catches a Second Wind." % t.name })
	if t.boss:
		_check_phase(t)


func _on_zero_hp(t: UnitScript, source: UnitScript) -> void:
	if t.is_prop():
		t.dead = true
		_emit({ "t": "vanish", "unit": t.id, "cell": t.cell })
		return
	if t.team == "party":
		t.downed = true
		t.shield = 0
		_emit({ "t": "down", "unit": t.id })
		if t.is_player:
			result = "lose"
			_emit({ "t": "end", "result": "lose" })
		return
	t.dead = true
	kills.append(str(t.source.get("id", t.id)))
	xp_total += t.xp
	money_total += t.money
	_emit({ "t": "death", "unit": t.id })
	_on_enemy_death(t)
	if t.role == "leader":
		for m in units:
			if m.team == "enemy" and m.alive() and m.role == "minion":
				m.disposition = { "courage": -90, "loyalty": -40 }
				m.intent = {}
		_emit({ "t": "log", "text": "The leader falls. The swarm scatters!" })


## Splitters split; explosive ones blow up next to them.
func _on_enemy_death(t: UnitScript) -> void:
	var boom := int(t.source.get("explodeOnDeath", 0))
	if boom > 0:
		_emit({ "t": "area", "cells": pattern_cells(t, "square_self", t.cell), "vectors": { "force": 1.0 } })
		_emit({ "t": "log", "text": "%s explodes!" % t.name })
		for c in pattern_cells(t, "square_self", t.cell):
			var o := unit_at(c)
			if o != null and o.alive():
				_damage(o, boom, null, "force", "hazard")
	var split := str(t.source.get("splitInto", ""))
	if split != "":
		var rec: Dictionary = DT.index_under(db, "enemies/", "enemies").get(split, {})
		var made := 0
		for d in GridScript.DIRS:
			if made >= int(t.source.get("splitCount", 2)) or rec.is_empty():
				break
			var c: Vector2i = t.cell + d
			if grid.in_bounds(c) and grid.walkable_terrain(c) and unit_at(c) == null:
				var s := UnitScript.from_enemy(EnemyMods.apply(db, rec), 1.0)
				s.cell = c
				_add_unit(s)
				_emit({ "t": "spawn", "unit": s.id, "cell": c, "prop": false })
				made += 1
		if made > 0:
			_emit({ "t": "log", "text": "%s splits apart!" % t.name })
			_build_order_keep_current()


func _heal(u: UnitScript, t: UnitScript, amount: int) -> void:
	if t.dead or t.is_prop():
		return
	var revived := false
	if t.downed:
		t.downed = false
		revived = true
	var before := t.hp
	t.hp = mini(t.max_hp, t.hp + amount)
	_emit({ "t": "heal", "unit": t.id, "amount": t.hp - before, "revived": revived })


func _check_phase(t: UnitScript) -> void:
	while t.phase_index + 1 < t.phases.size():
		var next: Dictionary = t.phases[t.phase_index + 1]
		if t.hp_ratio() > float(next.get("hpBelow", 0.0)):
			return
		t.phase_index += 1
		_emit({ "t": "phase", "unit": t.id, "index": t.phase_index, "text": str(next.get("say", "")) })
		if next.has("actions"):
			t.actions = next["actions"].duplicate(true)
		if next.has("movement"):
			t.movement = int(next["movement"])
		if next.has("disposition"):
			t.disposition = next["disposition"]
		# The boss reshapes the field: empty floor tiles turn into hazards.
		var free: Array = []
		for c in grid.all_cells():
			var cell: Vector2i = c
			if grid.get_terrain(cell) == GridScript.FLOOR and unit_at(cell) == null and not grid.exits.has(cell):
				free.append(cell)
		var made: Array = []
		for i in mini(int(next.get("hazards", 0)), free.size()):
			var pick: Vector2i = free.pop_at(rng.randi_range(0, free.size() - 1))
			grid.set_terrain(pick, GridScript.HAZARD)
			made.append(pick)
		if not made.is_empty():
			_emit({ "t": "tiles", "kind": "hazard", "cells": made })
		t.intent = {}
		for summon in next.get("summon", []):
			var rec: Dictionary = summon if typeof(summon) == TYPE_DICTIONARY else DT.index_under(db, "enemies/", "enemies").get(str(summon), {})
			if rec.is_empty():
				continue
			var s := UnitScript.from_enemy(rec, 1.0)
			_place(s, [], 0, false)
			_emit({ "t": "spawn", "unit": s.id, "cell": s.cell, "prop": false })
		_build_order_keep_current()


## Rebuild the order after summons without losing the current turn.
func _build_order_keep_current() -> void:
	var cur := current
	_build_order()
	turn_index = order.find(cur)
	if turn_index < 0:
		turn_index = 0


# --- Enemy actions --------------------------------------------------------------

## An enemy (or AI) action from data: { form, vectors, power } or { kind: "strike", mult }.
func action_spec(u: UnitScript, action: Dictionary) -> Dictionary:
	if str(action.get("kind", "attack")) == "strike":
		var base := float(u.stats.get(str(action.get("stat", "str")), 5)) * float(action.get("mult", 1.0)) + float(action.get("power", 0))
		return { "name": str(action.get("name", "Strike")), "vectors": action.get("vectors", {}), "form": form_rec("touch"),
			"power": float(action.get("power", 0)), "mult": 1.0, "heal": false, "ranged": false, "kind": "strike", "base": base }
	var form := Forms.at_magnitude(form_rec(str(action.get("form", "bolt"))), str(action.get("magnitude", "standard")))
	var heal: bool = (str(form.get("id", "")) == "shield" or str(form.get("id", "")) == "aura") and (action.get("vectors", {}).has("light") or action.get("vectors", {}).has("vitality"))
	return { "name": str(action.get("name", "Attack")), "vectors": action.get("vectors", {}), "form": form,
		"power": float(action.get("power", 5)), "mult": float(form.get("multiplier", 1.0)), "heal": heal,
		"ranged": int(form.get("range", 1)) > 1, "kind": "spell" }


func action_targets(u: UnitScript, action: Dictionary, from_cell: Vector2i) -> Array:
	var saved := u.cell
	u.cell = from_cell
	var spec := action_spec(u, action)
	var out: Array = []
	if str(spec["kind"]) == "strike":
		out = _adjacent_hostiles(u, 1)
	else:
		out = _spell_targets(u, spec["form"], bool(spec["heal"]))
	u.cell = saved
	return out


func perform_action(u: UnitScript, action: Dictionary, target: Vector2i) -> bool:
	if result != "" or u != current or not u.alive() or act_block(u) != "":
		return false
	if not action_targets(u, action, u.cell).has(target):
		return false
	u.action_used = true
	var spec := action_spec(u, action)
	_emit({ "t": "cast", "unit": u.id, "name": spec["name"], "target": target, "improvised": false })
	if str(spec["kind"]) == "strike":
		var t := unit_at(target)
		if t != null and not parried(u, t):
			_face_toward(u, t.cell)
			if u.statuses.has("blind") and rng.randf() < float(Res.combat_cfg(db).get("blindMissChance", 0.35)):
				_emit({ "t": "miss", "unit": t.id })
			else:
				var dmg := Res.finalize(db, Res.strike_damage(db, float(spec["base"]), u, t, _shared(u, t, false)), u, rng)
				_damage(t, int(dmg["amount"]), u, VO.dominant_axis(spec["vectors"], CardRules.arcane_axes(db)), "hit", bool(dmg["crit"]))
				if not spec["vectors"].is_empty() and t.alive():
					_apply_vector_effects(u, spec, [t.cell], [t])
	else:
		_face_toward(u, target)
		_resolve_spec(u, spec, target)
	_check_end()
	return true


## Expected damage of a spec on a target, for the AI.
func expected_damage(u: UnitScript, t: UnitScript, spec: Dictionary) -> float:
	return _expected_hit(u, t, spec)


# --- Intents (telegraphs, CU) -------------------------------------------------------
# An enemy picks its next action at the start of a party turn and commits to
# it: intent = { kind: attack | special | buff | defend | move, action, move,
# target, cells, mode: locked | tracking, unit (tracked unit id), charge }.
# Locked attacks hit whatever stands on their tiles when they resolve, so
# moving out dodges them and pushing an enemy in makes enemies hit each other.

func _ai_script() -> GDScript:
	if _ai == null:
		_ai = load("res://src/core/combat/enemy_ai.gd")
	return _ai


## Every enemy without an intent picks one now.
func refresh_intents() -> void:
	for u in units:
		if u.team == "enemy" and u.alive() and u.intent.is_empty():
			u.intent = _ai_script().plan_intent(self, u)
			if not u.intent.is_empty():
				_emit({ "t": "intent", "unit": u.id, "kind": str(u.intent.get("kind", "")) })


## Tiles an intent threatens right now (tracking intents follow their target).
func intent_cells(u: UnitScript) -> Array:
	var it: Dictionary = u.intent
	if it.is_empty() or not str(it.get("kind", "")) in ["attack", "special"] or bool(it.get("summon", false)):
		return []
	if str(it.get("mode", "locked")) == "tracking":
		var t := unit_by_id(str(it.get("unit", "")))
		return [t.cell] if t != null and t.alive() else []
	return it.get("cells", [])


## Tiles enemies plan to heal or summon onto (shown in green, not red).
func support_cells() -> Array:
	var out: Array = reinforcements.get("cells", []).duplicate() if not reinforcements.is_empty() else []
	for u in units:
		if u.team == "enemy" and u.alive() and (str(u.intent.get("kind", "")) == "buff" or bool(u.intent.get("summon", false))):
			out.append_array(u.intent.get("cells", []))
	return out


## The resolution spec of an intent's action. Telegraphed attacks can be
## dodged, so they hit harder (data/stats.json combat "telegraphDamageMul").
func intent_spec(u: UnitScript, action: Dictionary = {}) -> Dictionary:
	var spec := action_spec(u, action if not action.is_empty() else u.intent.get("action", {}))
	var mul := float(Res.combat_cfg(db).get("telegraphDamageMul", 1.0)) * float(difficulty_rules().get("enemyDamageMul", 1.0))
	spec["power"] = float(spec["power"]) * mul
	if spec.has("base"):
		spec["base"] = float(spec["base"]) * mul
	return spec


## Expected damage an intent deals on a tile: to whoever stands there, or to
## the player as an estimate for an empty tile.
func intent_damage(u: UnitScript, cell: Vector2i) -> int:
	var spec := intent_spec(u)
	if bool(spec.get("heal", false)):
		return 0
	var t := unit_at(cell)
	if t == null or t == u or t.is_prop():
		for p in units:
			if p.is_player:
				t = p
	if t == null or t == u:
		return 0
	return roundi(_expected_hit(u, t, spec))


## cell -> [{ "unit": enemy id, "damage": n, "charge": n }] for every telegraph.
func threats() -> Dictionary:
	var out := {}
	for u in units:
		if u.team != "enemy" or not u.alive():
			continue
		for c in intent_cells(u):
			if not out.has(c):
				out[c] = []
			out[c].append({ "unit": u.id, "damage": intent_damage(u, c), "charge": int(u.intent.get("charge", 0)) })
	for d in delayed:
		var caster: UnitScript = d["caster"]
		for c in d["cells"]:
			if not out.has(c):
				out[c] = []
			var victim := unit_at(c)
			var dmg := roundi(_expected_hit(caster, victim, d["spec"])) if victim != null and victim != caster else roundi(float(d["spec"]["power"]))
			out[c].append({ "unit": caster.id, "damage": dmg, "charge": int(d["turns"]), "neutral": bool(d["neutral"]), "delayed": true })
	return out


## Expected damage waiting on a tile for a unit of `team` (for the AI and the hover info).
func threat_at(cell: Vector2i, team: String = "party") -> int:
	var total := 0
	for h in threats().get(cell, []):
		var src := unit_by_id(str(h["unit"]))
		if src != null and (src.team != team or bool(h.get("neutral", false))):
			total += int(h["damage"])
	return total


## Cells of a boss pattern, from the caster's position at planning time.
func pattern_cells(u: UnitScript, pattern: String, target: Vector2i) -> Array:
	var out: Array = []
	for c in grid.all_cells():
		var cell: Vector2i = c
		if not grid.walkable_terrain(cell) or cell == u.cell:
			continue
		var d := GridScript.manhattan(cell, u.cell)
		match pattern:
			"ring":
				if d == 2 or d == 3:
					out.append(cell)
			"checker":
				if (cell.x + cell.y + round_num) % 2 == 0:
					out.append(cell)
			"cross":
				if cell.x == target.x or cell.y == target.y:
					out.append(cell)
			"rows":
				if absi(cell.y - target.y) % 2 == 0:
					out.append(cell)
			"line":
				if cell.y == u.cell.y and signi(cell.x - u.cell.x) == signi(target.x - u.cell.x):
					out.append(cell)
			"square_self":
				if absi(cell.x - u.cell.x) <= 1 and absi(cell.y - u.cell.y) <= 1:
					out.append(cell)
			"resurface":
				if GridScript.manhattan(cell, target) <= 1:
					out.append(cell)
	if pattern == "charge_line":
		# A straight run toward the target until a wall or the edge.
		out = []
		var dir := Forms.direction_to(u.cell, target)
		var c := u.cell + dir
		while grid.in_bounds(c) and grid.walkable_terrain(c):
			out.append(c)
			c += dir
	return out


## Pushed or pulled while charging: the charged area moves with the caster.
func _shift_intent(u: UnitScript, delta: Vector2i) -> void:
	if u.intent.is_empty() or delta == Vector2i.ZERO:
		return
	if int(u.intent.get("charge", 0)) <= 0:
		# A normal attack pushed out of range is cancelled.
		if str(u.intent.get("kind", "")) == "attack" and str(u.intent.get("mode", "locked")) == "locked":
			var tgt: Vector2i = u.intent.get("target", u.cell)
			if not action_targets(u, u.intent.get("action", {}), u.cell).has(tgt):
				u.intent = {}
				_emit({ "t": "interrupt", "unit": u.id, "text": "%s is knocked out of range." % u.name })
		return
	var moved: Array = []
	for c in u.intent.get("cells", []):
		var cell: Vector2i = c + delta
		if grid.in_bounds(cell):
			moved.append(cell)
	u.intent["cells"] = moved
	_emit({ "t": "interrupt", "unit": u.id, "text": "%s's charge is knocked aside." % u.name })


## Blind cancels a charge (and, under move_or_act, any attack); Slow delays a
## charge a turn; Root cancels a planned move.
func _interrupt(t: UnitScript, status: String) -> void:
	if t.intent.is_empty():
		return
	var kind := str(t.intent.get("kind", ""))
	if status == "root" and kind == "move":
		t.intent = {}
		_emit({ "t": "interrupt", "unit": t.id, "text": "%s is rooted and can't get into position." % t.name })
		return
	if status == "blind" and kind in ["attack", "special"] and turn_mode == "move_or_act":
		t.intent = {}
		_emit({ "t": "interrupt", "unit": t.id, "text": "%s is blinded and loses its target." % t.name })
		return
	if int(t.intent.get("charge", 0)) <= 0:
		return
	if status == "blind":
		t.intent = {}
		_emit({ "t": "interrupt", "unit": t.id, "text": "%s loses focus. The charge fizzles." % t.name })
	elif status == "slow":
		t.intent["charge"] = int(t.intent["charge"]) + 1
		_emit({ "t": "interrupt", "unit": t.id, "text": "%s's charge is slowed down." % t.name })


## An enemy carries out its intent. Returns false if the AI should choose
## freshly instead (a tracking target that's gone, or nothing planned).
func execute_intent(u: UnitScript) -> bool:
	var it: Dictionary = u.intent
	if it.is_empty() or u != current:
		return false
	if int(it.get("charge", 0)) > 0:
		it["charge"] = int(it["charge"]) - 1
		u.action_used = true
		_emit({ "t": "charge", "unit": u.id, "name": str(it.get("action", {}).get("name", "")) })
		return true
	u.intent = {}
	var kind := str(it.get("kind", ""))
	if str(it.get("mode", "locked")) == "tracking" and kind in ["attack", "special"]:
		# Follow the target: take the planned step, then hit it if it's still in reach.
		var t := unit_by_id(str(it.get("unit", "")))
		if t == null or not t.alive():
			return false
		var step: Vector2i = it.get("move", u.cell)
		if step != u.cell and can_move(u) and reachable_cells(u).has(step):
			move(u, step)
		if result != "" or not u.alive():
			return true
		var act: Dictionary = it.get("action", {})
		if action_targets(u, act, u.cell).has(t.cell):
			return perform_action(u, act, t.cell) or true
		_emit({ "t": "log", "text": "%s can't reach %s." % [u.name, t.name] })
		return true
	var dest: Vector2i = it.get("move", u.cell)
	if dest != u.cell and u.move_left > 0 and reachable_cells(u).has(dest):
		move(u, dest)
	if result != "" or not u.alive():
		return true
	match kind:
		"move":
			pass
		"defend":
			guard(u)
		"buff":
			var tgt: Vector2i = it.get("target", u.cell)
			if not perform_action(u, it.get("action", {}), tgt):
				return false
		"attack", "special":
			_resolve_locked(u, it)
	return true


## A locked attack lands on its tiles: everyone standing there is hit, even
## the caster's own side.
func _resolve_locked(u: UnitScript, it: Dictionary) -> void:
	u.action_used = true
	var act: Dictionary = it.get("action", {})
	var spec := intent_spec(u, act)
	var cells: Array = it.get("cells", [])
	var target: Vector2i = it.get("target", u.cell)
	if bool(act.get("burrow", false)):
		_burrow(u, target)
		return
	if bool(act.get("summon", false)):
		_summon(u, cells)
		return
	if bool(act.get("resurface", false)):
		u.statuses.erase("burrowed")
		var land := target if unit_at(target) == null or unit_at(target) == u else _free_near(target)
		var from := u.cell
		u.cell = land
		_emit({ "t": "blink", "unit": u.id, "from": from, "to": land })
	if bool(act.get("run", false)):
		# Chargers run the whole line, stopping before the first thing in the way.
		var from := u.cell
		for c in cells:
			var cell: Vector2i = c
			if unit_at(cell) != null and unit_at(cell) != u:
				break
			u.cell = cell
		if u.cell != from:
			_emit({ "t": "push", "unit": u.id, "from": from, "to": u.cell })
	_face_toward(u, target)
	_emit({ "t": "cast", "unit": u.id, "name": spec["name"], "target": target, "improvised": false })
	_emit({ "t": "area", "cells": cells, "vectors": spec["vectors"] })
	var hit: Array = []
	for c in cells:
		var t := unit_at(c)
		if t == null or t == u or not t.alive():
			continue
		if bool(spec["heal"]):
			if t.team == u.team:
				_heal(u, t, _heal_value(u, spec))
		elif str(spec.get("kind", "")) == "strike" and parried(u, t):
			continue
		elif _hit_unit(u, t, spec, true):
			hit.append(t)
	if not bool(spec["heal"]):
		_apply_vector_effects(u, spec, cells, hit)
	if bool(act.get("selfDestruct", false)) and u.alive():
		u.hp = 0
		_on_zero_hp(u, null)
	_check_end()


## Burrowers dig in (can't be hurt) and telegraph where they'll come up.
func _burrow(u: UnitScript, target: Vector2i) -> void:
	u.statuses["burrowed"] = 99
	_emit({ "t": "log", "text": "%s burrows underground." % u.name })
	var victim: UnitScript = null
	for o in opponents_of(u):
		if victim == null or GridScript.manhattan(o.cell, u.cell) < GridScript.manhattan(victim.cell, u.cell):
			victim = o
	var spot := victim.cell if victim != null else target
	var rise := { "id": "resurface", "name": "Resurface", "form": "touch", "power": float(u.source.get("resurfacePower", 9)), "vectors": { "force": 1.0 }, "resurface": true }
	u.intent = { "kind": "special", "action": rise, "move": u.cell, "target": spot, "cells": pattern_cells(u, "resurface", spot), "mode": "locked", "charge": 0 }


## Summoners call a minion onto a telegraphed tile.
func _summon(u: UnitScript, cells: Array) -> void:
	var rec: Dictionary = DT.index_under(db, "enemies/", "enemies").get(str(u.source.get("summons", "")), {})
	if rec.is_empty():
		return
	for c in cells:
		var cell: Vector2i = c
		if grid.walkable_terrain(cell) and unit_at(cell) == null:
			var s := UnitScript.from_enemy(EnemyMods.apply(db, rec), 1.0)
			s.cell = cell
			_add_unit(s)
			_emit({ "t": "spawn", "unit": s.id, "cell": cell, "prop": false })
			_emit({ "t": "log", "text": "%s calls %s." % [u.name, s.name] })
			_build_order_keep_current()
			return


func _free_near(cell: Vector2i) -> Vector2i:
	for r in range(1, 4):
		for c in grid.all_cells():
			var x: Vector2i = c
			if GridScript.manhattan(x, cell) == r and grid.walkable_terrain(x) and unit_at(x) == null:
				return x
	return cell


# --- End of fight -------------------------------------------------------------------

func can_flee() -> bool:
	if not flee_allowed or result != "":
		return false
	for u in units:
		if u.team == "party" and u.alive() and not grid.exits.has(u.cell):
			return false
	return true


func flee() -> bool:
	if not can_flee():
		return false
	result = "flee"
	_emit({ "t": "end", "result": "flee" })
	return true


func _check_end() -> void:
	if result != "":
		return
	var enemies_left := false
	var player_alive := false
	for u in units:
		if u.team == "enemy" and u.alive():
			enemies_left = true
		if u.is_player and not u.downed and not u.dead:
			player_alive = true
	var has_player := false
	for u in units:
		if u.is_player:
			has_player = true
	if has_player and not player_alive:
		result = "lose"
		_emit({ "t": "end", "result": "lose" })
	elif not enemies_left:
		result = "win"
		_emit({ "t": "end", "result": "win" })


## Call after any action: also used by the AI driver.
func check_end() -> void:
	_check_end()


## Write HP and MP back to the character records (MP carries over between
## fights in a night) and summarize the fight.
func finish() -> Dictionary:
	var party: Array = []
	for u in units:
		if u.team != "party":
			continue
		u.source["hp"] = maxi(1, u.hp) if u.downed else u.hp
		u.source["mp"] = u.mp
		party.append({ "id": u.id, "hp": u.hp, "mp": u.mp, "downed": u.downed })
	var remaining: Array = []
	for u in units:
		if u.team == "enemy" and u.alive():
			remaining.append(str(u.source.get("id", u.id)))
	var ignored := 0
	var answered := 0
	for call in help_calls:
		if bool(call["answered"]):
			answered += 1
		elif not bool(call["open"]) or result != "":
			ignored += 1
	return {
		"result": result, "xp": xp_total, "money": money_total, "party": party, "kills": kills,
		"remaining": remaining, "wildSurges": wild_surges, "support": support_log,
		"helpAnswered": answered, "helpIgnored": ignored, "rounds": round_num,
	}


func _emit(e: Dictionary) -> void:
	events.append(e)


## Drain events for the scene.
func take_events() -> Array:
	var out := events
	events = []
	return out

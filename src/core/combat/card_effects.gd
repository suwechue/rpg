## Card effects beyond damage (docs/ARENA.md Part 3). A card lists "effects"
## in data, each { "op": name, ...numbers }, run after the card's normal
## resolution with the cells it covered. `st` is the CombatState (untyped:
## combat_state.gd loads this script, so it can't be preloaded both ways).
extends RefCounted

const Str := preload("res://src/core/strings.gd")

const GridScript := preload("res://src/core/combat/grid.gd")
const Forms := preload("res://src/core/combat/forms.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")

## Every op name the data may use (DataDB validates cards against this list).
const OPS := ["burn_tiles", "fire_wall", "empower", "detonate", "self_burn", "steam", "cleanse", "ice_tiles", "cancel_charge", "rime",
	"delayed", "push", "pin", "gravity", "breach", "brace", "recoil", "dash", "blink", "swap", "haste_full", "reposition", "lunge", "decoy",
	"tailwind", "tether", "leash", "regen", "root_area", "pact", "heal", "taunt", "reveal", "halo", "radiance", "parry", "throw", "overwatch",
	"transmute_ground", "strip", "toxic_tiles", "shred", "once_heal_pct",
	"hit_and_run", "shadow_step", "blind_adjacent", "free_move", "ward", "pull_ally", "sanctuary", "intercept", "encore",
	"strike_x", "dash_line", "pull_root", "status_target", "status_self", "status_area"]
const TARGETING := ["self", "enemy", "ally", "unit", "empty", "any", "dir"]

## Statuses that count as "bad" for Cleanse.
const NEGATIVE := ["root", "slow", "blind", "tether"]


static func run(st, u: UnitScript, card: Dictionary, target: Vector2i, cells: Array) -> void:
	for e in card.get("effects", []):
		var fx: Dictionary = e
		if st.result != "" or not u.alive():
			return
		_op(st, u, card, fx, target, cells)


## Units standing on the cells (not the caster), alive.
static func units_in(st, cells: Array, u: UnitScript) -> Array:
	var out: Array = []
	for c in cells:
		var t: UnitScript = st.unit_at(c)
		if t != null and t != u and t.alive():
			out.append(t)
	return out


static func _foes(st, cells: Array, u: UnitScript) -> Array:
	return units_in(st, cells, u).filter(func(t: UnitScript) -> bool: return st.is_hostile(u, t))


static func _allies(st, cells: Array, u: UnitScript) -> Array:
	return units_in(st, cells, u).filter(func(t: UnitScript) -> bool: return t.team == u.team and not t.is_prop())


static func _spec(st, u: UnitScript, card: Dictionary, power: float, vectors: Dictionary = {}) -> Dictionary:
	return { "name": str(card.get("name", "")), "vectors": vectors if not vectors.is_empty() else card.get("vectors", {}),
		"form": st.form_rec("touch"), "power": power, "mult": 1.0, "heal": false, "ranged": true, "kind": "spell" }


static func _op(st, u: UnitScript, card: Dictionary, fx: Dictionary, target: Vector2i, cells: Array) -> void:
	var grid: GridScript = st.grid
	var turns := int(fx.get("turns", 2))
	match str(fx.get("op", "")):
		# --- Heat ---
		"burn_tiles":
			for c in cells:
				if grid.walkable_terrain(c):
					grid.burning[c] = turns
			st._emit({ "t": "tiles", "kind": "burning", "cells": cells })
		"fire_wall":
			for c in cells:
				if grid.walkable_terrain(c) and st.unit_at(c) == null:
					grid.burning[c] = turns
					grid.fire_walls[c] = turns
			st._emit({ "t": "tiles", "kind": "burning", "cells": cells })
		"empower":
			u.statuses["empower_" + str(fx.get("vector", ""))] = float(fx.get("mul", 1.5))
			st._emit({ "t": "status", "unit": u.id, "status": "empowered" })
		"detonate":
			var spec := _spec(st, u, card, float(fx.get("power", 8)), { "heat": 1.0 })
			for c in grid.burning.keys():
				var t: UnitScript = st.unit_at(c)
				if t != null and t.alive() and t != u:
					st._hit_unit(u, t, spec, false)
				grid.burning.erase(c)
			st._emit({ "t": "tiles", "kind": "burning", "cells": [] })
		"self_burn":
			grid.burning[u.cell] = 1
		"steam":
			for c in cells:
				grid.steam[c] = turns
			st._emit({ "t": "tiles", "kind": "steam", "cells": cells })
		"cleanse":
			var t: UnitScript = st.unit_at(target)
			if t != null and t.alive():
				for s in NEGATIVE:
					if t.statuses.has(s):
						t.statuses.erase(s)
						st._emit({ "t": "log", "text": Str.t(st.db, "card_effects.shakes_off") % [t.name, s] })
						if not bool(fx.get("all", false)):
							break
				if fx.has("heal"):
					st._heal(u, t, int(fx["heal"]))
		# --- Cold ---
		"ice_tiles":
			for c in cells:
				var ter := grid.get_terrain(c)
				if ter == GridScript.FLOOR or ter == GridScript.WATER:
					grid.set_terrain(c, GridScript.ICE)
			st._emit({ "t": "tiles", "kind": "ice", "cells": cells })
			for t in units_in(st, cells, u):
				var dir := Forms.direction_to(target, t.cell) if t.cell != target else Vector2i(t.facing, 0)
				st._slide(t, dir)
		"cancel_charge":
			for t in _foes(st, cells, u):
				if not t.intent.is_empty():
					t.intent = {}
					st._emit({ "t": "interrupt", "unit": t.id, "text": Str.t(st.db, "card_effects.s_attack_is_snapped_off") % t.name })
		"rime":
			var t: UnitScript = st.unit_at(target)
			if t != null:
				t.statuses["rime"] = turns
				st._emit({ "t": "status", "unit": t.id, "status": "rime" })
		"delayed":
			# Telegraphed for everyone; lands at the end of `turns` rounds.
			var picked: Array = cells
			if int(fx.get("random", 0)) > 0:
				picked = []
				var pool: Array = []
				for c in grid.all_cells():
					if grid.walkable_terrain(c) and GridScript.manhattan(c, target) <= int(fx.get("radius", 3)):
						pool.append(c)
				for i in mini(int(fx["random"]), pool.size()):
					picked.append(pool.pop_at(st.rng.randi_range(0, pool.size() - 1)))
			st.delayed.append({ "cells": picked, "turns": turns, "spec": _spec(st, u, card, float(fx.get("power", 10))), "caster": u,
				"neutral": bool(fx.get("neutral", false)), "name": str(card.get("name", "")) })
			st._emit({ "t": "telegraph", "cells": picked, "name": str(card.get("name", "")) })
		# --- Force ---
		"push":
			for t in _foes(st, cells, u) if not bool(fx.get("anyone", false)) else units_in(st, cells, u):
				if t.alive():
					st._push(u, t, Forms.direction_to(u.cell, t.cell) if u.cell != t.cell else Vector2i(u.facing, 0), int(fx.get("steps", 1)))
		"pin":
			for t in _foes(st, cells, u):
				var dir := Forms.direction_to(u.cell, t.cell)
				var blocked: bool = not grid.in_bounds(t.cell + dir) or not grid.walkable_terrain(t.cell + dir) or st.unit_at(t.cell + dir) != null
				st._push(u, t, dir, 1)
				if blocked and t.alive():
					t.statuses["root"] = 1
					st._emit({ "t": "status", "unit": t.id, "status": "root" })
					st._interrupt(t, "root")
		"gravity":
			var order: Array = units_in(st, cells, u)
			order.sort_custom(func(a: UnitScript, b: UnitScript) -> bool: return GridScript.manhattan(a.cell, target) < GridScript.manhattan(b.cell, target))
			for t in order:
				if t.cell != target and t.alive():
					st._push(u, t, Forms.direction_to(t.cell, target), int(fx.get("steps", 1)), false)
		"breach":
			for c in cells:
				if grid.get_terrain(c) == GridScript.COVER:
					grid.set_terrain(c, GridScript.FLOOR)
				var t: UnitScript = st.unit_at(c)
				if t != null and t.is_prop():
					st._damage(t, 999, u, "force", "hit")
			st._emit({ "t": "tiles", "kind": "breach", "cells": cells })
		"brace":
			u.statuses["brace"] = 1
			st._emit({ "t": "status", "unit": u.id, "status": "brace" })
		"recoil":
			var back := -Forms.direction_to(u.cell, target)
			st._push(u, u, back, int(fx.get("self", 1)), false)
		# --- Motion ---
		"dash":
			st.grant_move(u, int(fx.get("tiles", 2)))
		"blink":
			if st.unit_at(target) == null and grid.walkable_terrain(target):
				var from := u.cell
				u.cell = target
				st._emit({ "t": "blink", "unit": u.id, "from": from, "to": target })
				st._enter_cell(u, target)
		"swap":
			var t: UnitScript = st.unit_at(target)
			if t != null and t != u and not t.is_prop():
				var a := u.cell
				u.cell = t.cell
				t.cell = a
				st._emit({ "t": "blink", "unit": u.id, "from": t.cell, "to": u.cell })
				st._emit({ "t": "blink", "unit": t.id, "from": u.cell, "to": t.cell })
				st._shift_intent(t, t.cell - u.cell)
		"haste_full":
			for t in _allies(st, [target], u) + ([u] if target == u.cell else []):
				t.statuses["haste_full"] = 2
				st._emit({ "t": "status", "unit": t.id, "status": "haste" })
		"reposition":
			var t: UnitScript = st.unit_at(target)
			if t != null and t.team == u.team:
				st._push(u, t, Forms.direction_to(u.cell, t.cell) if u.cell != t.cell else Vector2i(u.facing, 0), int(fx.get("steps", 2)), false)
		"lunge":
			var t: UnitScript = st.unit_at(target)
			var dir := Forms.direction_to(u.cell, target)
			# PT Part 4: the lunge passes over hazards and gaps without triggering them
			# (not through walls or units); only the landing tile counts.
			var path: Array = []
			var land := u.cell
			var probe := u.cell
			for i in int(fx.get("tiles", 2)):
				if GridScript.manhattan(probe, target) <= 1:
					break
				var next := probe + dir
				if not grid.in_bounds(next) or grid.get_terrain(next) == GridScript.WALL or st.unit_at(next) != null:
					break
				probe = next
				path.append(next)
				if grid.walkable_terrain(next) and grid.get_terrain(next) != GridScript.HAZARD:
					land = next
			if land != u.cell:
				u.cell = land
				st._emit({ "t": "move", "unit": u.id, "path": path.slice(0, path.find(land) + 1) })
				st._enter_cell(u, land)
			if t != null and t.alive() and GridScript.manhattan(u.cell, t.cell) == 1:
				st._basic(u, { "action": "strike", "stat": str(fx.get("stat", "str")), "mult": float(fx.get("mult", 1.0)), "name": str(card.get("name", "Lunge")) }, t.cell)
		"decoy":
			var at: Vector2i = u.cell if bool(fx.get("atSelf", false)) else target
			if bool(fx.get("atSelf", false)) and fx.has("thenMove"):
				u.move_left += int(fx["thenMove"])
			if st.unit_at(at) == null or at == u.cell:
				var d := UnitScript.make_prop("decoy", int(fx.get("hp", 6)), int(fx.get("lasts", 2)))
				d.name = "Decoy"
				d.blocks_sight = false
				if at == u.cell:
					st._pending_decoys.append({ "prop": d, "cell": at })
				else:
					d.cell = at
					st._add_unit(d)
					st._emit({ "t": "spawn", "unit": d.id, "cell": at, "prop": true })
				# PT Part 4: the decoy takes the next tracking attack aimed at its caster.
				u.links["decoy"] = d.id
				st.draw_telegraphs(at, int(fx.get("draw", 2)))
		"tailwind":
			for a in st.allies_of(u):
				a.statuses["haste"] = 1
				a.statuses["haste_amount"] = int(fx.get("tiles", 1))
				if a == u:
					st.grant_move(u, int(fx.get("tiles", 1)))
				st._emit({ "t": "status", "unit": a.id, "status": "haste" })
		# --- Binding ---
		"tether":
			var t: UnitScript = st.unit_at(target)
			if t != null and st.is_hostile(u, t):
				var best: UnitScript = null
				for o in st.allies_of(t):
					if o != t and (best == null or GridScript.manhattan(o.cell, t.cell) < GridScript.manhattan(best.cell, t.cell)):
						best = o
				if best != null:
					t.statuses["tether"] = turns
					best.statuses["tether"] = turns
					t.links["tether"] = best.id
					best.links["tether"] = t.id
					st._emit({ "t": "status", "unit": t.id, "status": "tether" })
					if bool(fx.get("pull", false)):
						st._push(u, best, Forms.direction_to(best.cell, t.cell), 3, true)
		"leash":
			var t: UnitScript = st.unit_at(target)
			if t != null and t.alive() and not t.is_prop():
				st._push(u, t, Forms.direction_to(t.cell, u.cell), maxi(0, GridScript.manhattan(t.cell, u.cell) - 1), false)
		"regen":
			for t in _allies(st, cells, u) + ([u] if cells.has(u.cell) else []):
				t.statuses["regen"] = turns
				t.links["regen"] = str(int(fx.get("amount", 3)))
				st._emit({ "t": "status", "unit": t.id, "status": "regen" })
		"root_area":
			for t in _foes(st, cells, u):
				t.statuses["root"] = turns
				st._emit({ "t": "status", "unit": t.id, "status": "root" })
				st._interrupt(t, "root")
		"pact":
			var t: UnitScript = st.unit_at(target)
			if t != null and t != u and t.team == u.team and not t.is_prop():
				u.statuses["pact"] = turns
				t.statuses["pact"] = turns
				u.links["pact"] = t.id
				t.links["pact"] = u.id
				st._emit({ "t": "status", "unit": u.id, "status": "pact" })
		# --- Light ---
		"heal":
			var t: UnitScript = st.unit_at(target)
			if t != null and t.team == u.team:
				st._heal(u, t, int(fx.get("amount", 8)))
		"taunt":
			u.statuses["taunting"] = turns
			st._emit({ "t": "status", "unit": u.id, "status": "taunting" })
			st.draw_telegraphs(u.cell, int(fx.get("radius", 4)))
			st.taunt_replan(u, int(fx.get("radius", 4)))
		"reveal":
			st.revealed = turns
			for o in st.units:
				if o.statuses.has("burrowed"):
					o.statuses.erase("burrowed")
					st._emit({ "t": "log", "text": Str.t(st.db, "card_effects.is_dragged_into_the_light") % o.name })
			st._emit({ "t": "log", "text": Str.t(st.db, "card_effects.every_enemy_plan_is_laid") })
		# --- Class roles (CT Part 5) ---
		"hit_and_run":
			var t: UnitScript = st.unit_at(target)
			if t != null and t.alive():
				st._basic(u, { "action": "strike", "stat": str(fx.get("stat", "dex")), "mult": float(fx.get("mult", 1.0)), "name": str(card.get("name", "")) }, t.cell)
			st.grant_free_move(u, int(fx.get("tiles", 2)))
		"free_move":
			st.grant_free_move(u, int(fx.get("tiles", 1)))
		"shadow_step":
			var t: UnitScript = st.unit_at(target)
			if t != null and t.alive():
				var spots: Array = [t.cell - Vector2i(t.facing, 0)]
				for dd in GridScript.DIRS:
					spots.append(t.cell + dd)
				for c in spots:
					var cell: Vector2i = c
					if grid.in_bounds(cell) and grid.walkable_terrain(cell) and st.unit_at(cell) == null:
						var from := u.cell
						u.cell = cell
						st._emit({ "t": "blink", "unit": u.id, "from": from, "to": cell })
						break
				if GridScript.manhattan(u.cell, t.cell) == 1:
					st._face_toward(u, t.cell)
					st._basic(u, { "action": "strike", "stat": str(fx.get("stat", "dex")), "mult": float(fx.get("mult", 1.2)), "name": str(card.get("name", "")) }, t.cell)
		"blind_adjacent":
			for t in st.opponents_of(u):
				if t.alive() and GridScript.manhattan(t.cell, u.cell) == 1:
					t.statuses["blind"] = int(fx.get("turns", 1))
					st._emit({ "t": "status", "unit": t.id, "status": "blind" })
		"ward":
			var t: UnitScript = st.unit_at(target)
			if t != null and t.alive() and t.team == u.team:
				var amount := int(fx.get("amount", 8))
				if st.threat_at(t.cell, t.team) > 0 or st.tracking_threat(t, t.cell) > 0:
					amount *= 2
				t.shield += amount
				t.shield_turns = maxi(t.shield_turns, 1)
				st._emit({ "t": "shield", "unit": t.id, "amount": amount })
		"pull_ally":
			var t: UnitScript = st.unit_at(target)
			if t != null and t != u and t.team == u.team:
				st._push(u, t, Forms.direction_to(t.cell, u.cell), mini(int(fx.get("steps", 3)), GridScript.manhattan(t.cell, u.cell) - 1), false)
		"sanctuary":
			for a in st.allies_of(u, true):
				if GridScript.manhattan(a.cell, u.cell) <= int(fx.get("radius", 1)):
					a.statuses["sanctuary"] = int(fx.get("turns", 1)) + 1
					st._emit({ "t": "status", "unit": a.id, "status": "sanctuary" })
		"intercept":
			u.statuses["intercept"] = int(fx.get("turns", 1)) + 1
			st._emit({ "t": "status", "unit": u.id, "status": "intercept" })
		"encore":
			var t: UnitScript = st.unit_at(target)
			if t != null and t.alive() and t != u and st.acted_this_round(t):
				st.give_encore(t)
		"halo":
			for a in st.allies_of(u):
				if GridScript.manhattan(a.cell, u.cell) <= 1:
					a.shield += int(fx.get("amount", 5))
					a.shield_turns = maxi(a.shield_turns, 2)
					st._emit({ "t": "shield", "unit": a.id, "amount": int(fx.get("amount", 5)) })
		"radiance":
			var spec := _spec(st, u, card, float(fx.get("power", 6)), { "light": 1.0 })
			for c in grid.all_cells():
				if GridScript.manhattan(c, u.cell) != int(fx.get("ring", 1)) and GridScript.manhattan(c, u.cell) != 0:
					continue
				var t: UnitScript = st.unit_at(c)
				if t == null or not t.alive():
					continue
				if t.team == u.team:
					st._heal(u, t, int(fx.get("heal", 5)))
				elif st.is_hostile(u, t):
					st._hit_unit(u, t, spec, false)
		# --- Basic and weapon ---
		# --- PT Part 7: class pools ---
		"strike_x":
			# A weapon hit in a shape: single, cleave (the 3 tiles in front), cone, or twin (a second foe within 2).
			var stat := str(fx.get("stat", "str"))
			var mult := float(fx.get("mult", 1.0))
			var victims: Array = []
			match str(fx.get("pattern", "single")):
				"cleave":
					victims = _foes(st, Forms.footprint(grid, { "footprint": "cleave" }, u.cell, target, {}), u)
				"cone":
					victims = _foes(st, Forms.footprint(grid, { "footprint": "cone" }, u.cell, target, {}), u)
				_:
					var t0: UnitScript = st.unit_at(target)
					if t0 != null and t0.alive():
						victims.append(t0)
					if str(fx.get("pattern", "")) == "twin" and t0 != null:
						for o in st.opponents_of(u):
							if o != t0 and o.alive() and GridScript.manhattan(o.cell, t0.cell) <= 2:
								victims.append(o)
								break
			for t in victims:
				if t.alive():
					st._basic(u, { "action": "strike", "stat": stat, "mult": mult, "name": str(card.get("name", "")), "breaker": bool(fx.get("breaker", false)) }, t.cell)
					if fx.has("status") and t.alive():
						st.add_status(t, str(fx["status"]), int(fx.get("turns", -1)))
		"dash_line":
			# Shoulder Charge: run up to N tiles toward the target, slam it, knock it back.
			var dir2 := Forms.direction_to(u.cell, target)
			for i in int(fx.get("tiles", 3)):
				var nx: Vector2i = u.cell + dir2
				if not grid.in_bounds(nx) or not grid.walkable_terrain(nx) or st.unit_at(nx) != null:
					break
				u.cell = nx
				st._emit({ "t": "move", "unit": u.id, "path": [nx] })
			var hit_u: UnitScript = st.unit_at(u.cell + dir2)
			if hit_u != null and st.is_hostile(u, hit_u):
				st._basic(u, { "action": "strike", "stat": "str", "mult": float(fx.get("mult", 1.0)), "name": str(card.get("name", "")) }, hit_u.cell)
				if hit_u.alive():
					st._push(u, hit_u, dir2, int(fx.get("knock", 1)))
		"pull_root":
			var t: UnitScript = st.unit_at(target)
			if t != null and t.alive() and st.is_hostile(u, t):
				if GridScript.manhattan(t.cell, u.cell) > 1:
					st._push(u, t, Forms.direction_to(t.cell, u.cell), GridScript.manhattan(t.cell, u.cell) - 1, false)
				t.statuses["root"] = int(fx.get("turns", 1))
				st._emit({ "t": "status", "unit": t.id, "status": "root" })
		"status_target":
			st.add_status(st.unit_at(target), str(fx.get("status", "")), int(fx.get("turns", -1)))
		"status_self":
			st.add_status(u, str(fx.get("status", "")), int(fx.get("turns", -1)))
			if bool(fx.get("adjacent", false)):
				for a in st.allies_of(u):
					if a != u and GridScript.manhattan(a.cell, u.cell) == 1:
						st.add_status(a, str(fx.get("status", "")), int(fx.get("turns", -1)))
		"status_area":
			for t in _foes(st, cells if not cells.is_empty() else [target], u):
				st.add_status(t, str(fx.get("status", "")), int(fx.get("turns", -1)))
		"parry":
			u.statuses["parry"] = 1
			if fx.has("mult"):
				u.links["parry_mult"] = str(fx["mult"])
			st._emit({ "t": "status", "unit": u.id, "status": "parry" })
		"throw":
			var t: UnitScript = st.unit_at(target)
			if t != null and t.alive():
				var mult := float(fx.get("mult", 1.0))
				for p in st.units:
					if p.is_prop() and not p.dead and p.name == "Crate" and GridScript.manhattan(p.cell, u.cell) == 1:
						mult *= 1.5
						st._damage(p, 999, u, "", "hit")
						break
				st._basic(u, { "action": "strike", "stat": "str", "mult": mult, "name": "Throw" }, t.cell)
		"overwatch":
			st.glyphs.append({ "cell": target, "spec": _spec(st, u, card, float(u.stats.get("dex", 5)) * float(fx.get("mult", 1.2)), {}), "team": u.team, "caster": u, "turns": turns })
			st._emit({ "t": "glyph_set", "cell": target, "team": u.team })
		# --- Tier 3 ---
		"transmute_ground":
			for c in cells:
				var ter := grid.get_terrain(c)
				if ter in [GridScript.HAZARD, GridScript.WATER, GridScript.ICE]:
					grid.set_terrain(c, GridScript.FLOOR)
				grid.burning.erase(c)
				grid.toxic.erase(c)
			st._emit({ "t": "tiles", "kind": "floor", "cells": cells })
		"strip":
			var t: UnitScript = st.unit_at(target)
			if t != null and st.is_hostile(u, t):
				var stolen := t.shield
				t.shield = 0
				for s in ["haste", "rally", "guard"]:
					t.statuses.erase(s)
				t.guard_active = false
				if stolen > 0:
					u.shield += stolen
					u.shield_turns = maxi(u.shield_turns, 2)
					st._emit({ "t": "shield", "unit": u.id, "amount": stolen })
				st._emit({ "t": "log", "text": Str.t(st.db, "card_effects.is_stripped_of_protection") % t.name })
		"toxic_tiles":
			for c in cells:
				if grid.walkable_terrain(c):
					grid.toxic[c] = turns
			st._emit({ "t": "tiles", "kind": "toxic", "cells": cells })
		"shred":
			for t in _foes(st, cells, u):
				t.defense_shred += int(fx.get("defense", 2))
				t.resist_shred += int(fx.get("resist", 4))
				st._emit({ "t": "status", "unit": t.id, "status": "corroded" })
		"once_heal_pct":
			st._heal(u, u, maxi(1, roundi(float(u.max_hp) * float(fx.get("pct", 0.25)))))
		_:
			push_warning("card_effects: unknown op %s" % fx.get("op", ""))

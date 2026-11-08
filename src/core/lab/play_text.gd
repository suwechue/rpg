## The Lab as text (docs/LAB_TUNER.md Part 5), for agent playtesters and
## tools/lab_play.gd. A game is a fight, a preset, a seed and the list of
## inputs so far: replaying them always gives the same fight, so nothing is
## saved. Enemies play themselves; the party waits for the next input.
## Inputs: a number (the option to play), "u" (undo, when the rules allow it), or a
## named step: m3.2 (move to 3,2), s4.2 (Strike at 4,2), c2@4.2 (hand card 2 at
## 4,2; c2 alone aims it at yourself; c2@4.2#Spark picks Spark for its choice),
## e (end the turn), surge, gauge, delay, p2 (let party member 2 go now), h2 (hold card 2).
extends RefCounted

const StateScript := preload("res://src/core/combat/combat_state.gd")
const Setup := preload("res://src/core/lab/lab_setup.gd")
const Rules := preload("res://src/core/combat/rules.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const Legal := preload("res://src/core/lab/players/legal.gd")
const Sim := preload("res://src/core/lab/players/sim.gd")
const Eval := preload("res://src/core/lab/players/evaluator.gd")
const CardRules := preload("res://src/core/card.gd")
const GridScript := preload("res://src/core/combat/grid.gd")
const Extras := preload("res://src/core/combat/extras.gd")
const Str := preload("res://src/core/strings.gd")
const Sweep := preload("res://src/core/lab/sweep.gd")

const MAX_STEPS := 3000
const TERRAIN_CHARS := { "floor": ".", "wall": "#", "rubble": ",", "cover": "=", "hazard": "^", "water": "~", "ice": "*", "pit": "O", "collapse": "k",
	"dark": ":", "ledge": "_", "spikes": "w", "conv_r": ">", "conv_l": "<", "conv_u": "A", "conv_d": "V" }
const TERRAIN_WORDS := { ".": "floor", "#": "wall", ",": "rubble (half cover)", "=": "cover", "^": "hazard (hurts on entry)", "~": "water", "*": "ice (pushed units slide)",
	"O": "pit (enemies pushed in die)", "k": "cracked floor (gives way)", ":": "darkness", "_": "ledge (pushed off, you fall)", "w": "spikes", ">": "conveyor", "<": "conveyor",
	"A": "conveyor", "V": "conveyor" }


## Play the inputs. Returns { st, error, events (since the last input), steps }.
static func replay(db: Dictionary, fight_id: String, preset: String, seed_value: int, inputs: Array, levers: Dictionary = {}) -> Dictionary:
	var out := { "st": null, "error": "", "events": [], "notes": [], "fight": fight_id }
	if Setup.fight(db, fight_id).is_empty():
		out["error"] = "There's no fight called '%s'. Fights: %s." % [fight_id, ", ".join(PackedStringArray(Setup.fights(db).map(func(f: Dictionary) -> String: return str(f["id"]))))]
		return out
	if Rules.preset_rec(db, preset).is_empty():
		out["error"] = "There's no preset called '%s'." % preset
		return out
	var built := Setup.build(db, fight_id, preset, levers, [], seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st: Object = StateScript.new(db, rng, built["setup"])
	out["st"] = st
	var events: Array = []
	var ticks := 0
	var i := 0
	while st.result == "" and st.current != null and ticks < MAX_STEPS:
		ticks += 1
		var u: Object = st.current
		if u.team != "party" or u.ai_controlled:
			AI.take_turn(st, u)
			events.append_array(st.take_events())
			continue
		if i >= inputs.size():
			break
		var tok := str(inputs[i]).strip_edges()
		i += 1
		if i == inputs.size():
			events = []
		if tok == "u":
			if not _undo(st, u):
				out["notes"].append("Undo isn't allowed here: %s" % _undo_reason(st, u))
			events.append_array(st.take_events())
			continue
		var opts := options(st)
		var n := -1
		if tok.is_valid_int():
			n = int(tok)
			if n < 1 or n > opts.size():
				out["error"] = "Input %d: there's no option %d (pick 1 to %d)." % [i, n, opts.size()]
				break
		else:
			n = find_named(st, opts, tok)
			if n < 0:
				out["error"] = "Input %d ('%s'): %s" % [i, tok, _named_error(tok)]
				break
		Legal.apply(st, u, opts[n - 1]["step"])
		events.append_array(st.take_events())
	if i < inputs.size() and out["error"] == "" and st.result != "":
		out["notes"].append("The fight is over: inputs after %d were not used." % i)
	out["events"] = events
	return out


## The option number (1-based) a named step means, or -1.
static func find_named(st: Object, opts: Array, tok: String) -> int:
	var t := tok.to_lower()
	for i in opts.size():
		if _matches(st, opts[i]["step"], t):
			return i + 1
	return -1


static func _at(text: String) -> Vector2i:
	var p := text.split(".")
	if p.size() != 2 or not p[0].is_valid_int() or not p[1].is_valid_int():
		return Vector2i(-99, -99)
	return Vector2i(int(p[0]), int(p[1]))


static func _matches(st: Object, s: Dictionary, t: String) -> bool:
	var u: Object = st.current
	var kind := str(s["kind"])
	if t == "e" or t == "end":
		return kind == "end"
	if t in ["surge", "gauge", "delay"]:
		return kind == t
	if t.begins_with("m") and t.substr(1).contains("."):
		return kind in ["move", "climb"] and s["cell"] == _at(t.substr(1))
	if t.begins_with("s") and t.substr(1).contains("."):
		return kind == "strike" and s["target"] == _at(t.substr(1))
	if t.begins_with("p") and t.substr(1).is_valid_int():
		return kind == "pick" and letter(st, st.unit_by_id(str(s["unit"]))) == t.substr(1)
	if t.begins_with("h") and t.substr(1).is_valid_int():
		return kind == "hold" and int(s["hand"]) == int(t.substr(1)) - 1
	if t.begins_with("c"):
		var body := t.substr(1)
		var choice := ""
		if body.contains("#"):
			choice = body.get_slice("#", 1)
			body = body.get_slice("#", 0)
		var hand_n := body.get_slice("@", 0)
		if not hand_n.is_valid_int() or kind != "card" or u.deck == null:
			return false
		var hi := int(hand_n) - 1
		if hi < 0 or hi >= u.deck.hand.size() or str(u.deck.hand[hi]) != str(s["id"]):
			return false
		var target: Vector2i = u.cell if not body.contains("@") else _at(body.get_slice("@", 1))
		if s["target"] != target:
			return false
		if choice == "":
			return true
		var ch: Variant = s.get("choice")
		return ch != null and (str(ch).to_lower() == choice or str(CardRules.resolve(st.db, str(ch), st.library).get("name", "")).to_lower() == choice)
	return false


static func _named_error(tok: String) -> String:
	var t := tok.to_lower()
	if t.begins_with("m"):
		return "you can't move there now (see the Moves list)."
	if t.begins_with("s"):
		return "there's nothing to Strike there, or your Strike is used."
	if t.begins_with("c"):
		return "that card can't be played there now (check the hand and the numbered options)."
	return "I don't know that step. Use an option number, m<x>.<y>, s<x>.<y>, c<card>@<x>.<y>, e, surge, gauge, delay, p<n>, h<card> or u."


static func _undo(st: Object, u: Object) -> bool:
	if st.rules.text("undo", "stack") == "off":
		return false
	if st.can_undo(u):
		return st.undo(u)
	if st.can_undo_move(u):
		return st.undo_move(u)
	return false


static func _undo_reason(st: Object, u: Object) -> String:
	if st.rules.text("undo", "stack") == "off":
		return "this preset has no undo."
	var why: String = st.undo_reason(u)
	return why if why != "" else "nothing to take back."


## Every option for the acting character, checked by trying it: [{ step, label, preview }].
static func options(st: Object) -> Array:
	var u: Object = st.current
	var out: Array = []
	if u == null or st.result != "":
		return out
	var ctx := Sim.begin(st)
	var root: Dictionary = ctx["root"]
	for s in Legal.steps(st, u):
		Sim.restore(st, root)
		if str(s["kind"]) == "end":
			out.append({ "step": s, "label": "End %s's turn" % u.name, "preview": "" })
			continue
		var before := _picture(st)
		var sig := [u.cell, u.mp, u.actions_left, u.action_used, u.quick_used, u.move_left, st.current, u.deck.hand.size() if u.deck != null else 0, st.surge, u.held_id]
		if not Legal.apply(st, u, s):
			continue
		var sig2 := [u.cell, u.mp, u.actions_left, u.action_used, u.quick_used, u.move_left, st.current, u.deck.hand.size() if u.deck != null else 0, st.surge, u.held_id]
		var changes := _diff(st, u, before, _picture(st), str(s["kind"]) in ["move", "climb"])
		if sig == sig2 and changes.is_empty():
			continue
		out.append({ "step": s, "label": label(st, u, s, before), "preview": "; ".join(PackedStringArray(changes)) })
	Sim.finish(st, ctx)
	return out


static func letter(st: Object, x: Object) -> String:
	var party := 0
	var foes := 0
	for y in st.units:
		if y.is_prop():
			continue
		if y.team == "party" and not bool(y.source.get("object", false)):
			party += 1
			if y == x:
				return str(party)
		elif y.team == "enemy":
			if y == x:
				return char(97 + foes % 26)
			foes += 1
	if bool(x.source.get("object", false)):
		return "&"
	return str(x.name).substr(0, 1).to_upper() if x.is_prop() else "?"


static func who(st: Object, x: Object) -> String:
	return "%s %s" % [letter(st, x), x.name]


static func _cell(c: Vector2i) -> String:
	return "(%d,%d)" % [c.x, c.y]


static func label(st: Object, u: Object, s: Dictionary, before: Dictionary) -> String:
	match str(s["kind"]):
		"move":
			return "Move to %s" % _cell(s["cell"])
		"climb":
			return "Climb to %s" % _cell(s["cell"])
		"card":
			var card: Dictionary = CardRules.resolve(st.db, str(s["id"]), st.library)
			var at: Vector2i = s["target"]
			var t: Object = _unit_in(before, at)
			var aim := (" at " + who(st, t)) if t != null and t != u else (" on yourself" if at == u.cell else " at " + _cell(at))
			var ch: Variant = s.get("choice")
			var pick := "" if ch == null else " (choosing %s)" % str(CardRules.resolve(st.db, str(ch), st.library).get("name", ch))
			return "Play %s%s%s" % [str(card.get("name", s["id"])), aim, pick]
		"strike":
			var t: Object = _unit_in(before, s["target"])
			return "Strike %s" % (who(st, t) if t != null else _cell(s["target"]))
		"surge":
			return "Spend Surge (your next card this turn is free)"
		"gauge":
			return "Spend your class gauge"
		"delay":
			return "Delay: act after the next enemy"
		"pick":
			return "Let %s go now instead" % who(st, st.unit_by_id(str(s["unit"])))
		"together":
			return "Cast together with an ally at %s" % _cell(s["target"])
		"hold":
			return "Hold %s for next turn" % str(CardRules.resolve(st.db, str(s["id"]), st.library).get("name", s["id"]))
		"reserve":
			return "Bring in the reserve for %s" % who(st, st.unit_by_id(str(s["unit"])))
	return str(s["kind"])


static func _unit_in(pic: Dictionary, cell: Vector2i) -> Object:
	for x in pic["units"]:
		var r: Dictionary = pic["units"][x]
		if r["cell"] == cell and bool(r["alive"]) and not bool(r["prop"]):
			return x
	for x in pic["units"]:
		var r: Dictionary = pic["units"][x]
		if r["cell"] == cell and bool(r["alive"]):
			return x
	return null


## What a reader can see: every unit's tile, HP, statuses and plan, the tiles, Surge.
static func _picture(st: Object) -> Dictionary:
	var units := {}
	for x in st.units:
		units[x] = { "cell": x.cell, "hp": x.hp, "shield": x.shield, "alive": x.alive(), "prop": x.is_prop(), "statuses": x.statuses.keys(), "intent": st.intent_cells(x) if x.team == "enemy" else [],
			"mp": x.mp }
	var tiles := {}
	for c in st.grid.all_cells():
		tiles[c] = _tile_char(st, c)
	return { "units": units, "tiles": tiles, "surge": st.surge }


static func _tile_char(st: Object, c: Vector2i) -> String:
	if st.grid.burning.has(c):
		return "f"
	if st.grid.oil.has(c):
		return "o"
	if st.grid.wet.has(c):
		return "~"
	return str(TERRAIN_CHARS.get(st.grid.get_terrain(c), "?"))


static func _diff(st: Object, u: Object, a: Dictionary, b: Dictionary, moved_self: bool = false) -> Array:
	var out: Array = []
	for x in b["units"]:
		var nb: Dictionary = b["units"][x]
		if not a["units"].has(x):
			if bool(nb["alive"]):
				out.append("%s appears at %s" % [who(st, x), _cell(nb["cell"])])
			continue
		var na: Dictionary = a["units"][x]
		var nm := who(st, x) if x != u else "you"
		if bool(na["alive"]) and not bool(nb["alive"]):
			out.append("%s %s" % [nm, "is destroyed" if bool(na["prop"]) else ("die" if x == u else "dies")])
		elif int(nb["hp"]) != int(na["hp"]):
			out.append("%s %d -> %d HP" % [nm, int(na["hp"]), int(nb["hp"])])
		if int(nb["shield"]) != int(na["shield"]):
			out.append("%s shield %d -> %d" % [nm, int(na["shield"]), int(nb["shield"])])
		if nb["cell"] != na["cell"] and bool(nb["alive"]) and not (x == u and moved_self):
			out.append("%s %s %s -> %s" % [nm, "move" if x == u else "moves", _cell(na["cell"]), _cell(nb["cell"])])
		for s in nb["statuses"]:
			if not (na["statuses"] as Array).has(s) and not str(s).begins_with("_"):
				out.append("%s gains %s" % [nm, s])
		if x.team == "enemy" and not (na["intent"] as Array).is_empty() and (nb["intent"] as Array).is_empty() and bool(nb["alive"]):
			out.append("%s's attack is cancelled" % who(st, x))
		elif x.team == "enemy" and str(na["intent"]) != str(nb["intent"]) and bool(nb["alive"]) and not (nb["intent"] as Array).is_empty():
			out.append("%s's attack now aims at %s" % [who(st, x), ", ".join(PackedStringArray((nb["intent"] as Array).map(func(c: Vector2i) -> String: return _cell(c))))])
	var changed: Array = []
	for c in b["tiles"]:
		if str(b["tiles"][c]) != str(a["tiles"].get(c, "")):
			changed.append("%s %s -> %s" % [_cell(c), _tile_word(str(a["tiles"].get(c, ""))), _tile_word(str(b["tiles"][c]))])
	if not changed.is_empty():
		out.append("tiles: " + ", ".join(PackedStringArray(changed.slice(0, 6))) + (" and %d more" % (changed.size() - 6) if changed.size() > 6 else ""))
	if int(b["surge"]) != int(a["surge"]):
		out.append("Surge %d -> %d" % [int(a["surge"]), int(b["surge"])])
	if u.alive():
		var hit := int(Eval.incoming(st).get(u, 0))
		if hit > 0:
			out.append("you'd stand in %d telegraphed damage" % hit)
		elif _any_telegraph(st):
			out.append("you'd be out of every telegraph")
	return out


static func _any_telegraph(st: Object) -> bool:
	for e in st.units:
		if e.team == "enemy" and e.alive() and not st.intent_cells(e).is_empty():
			return true
	return false


static func _tile_word(ch: String) -> String:
	match ch:
		"f":
			return "burning"
		"o":
			return "oil"
	return str(TERRAIN_WORDS.get(ch, ch)).get_slice(" (", 0)


static func dice_note(st: Object) -> String:
	var dice: Array = []
	if st.rules.flag("crits"):
		dice.append("crits")
	if st.rules.flag("misses"):
		dice.append("misses")
	if st.rules.flag("instability"):
		dice.append("Instability rolls")
	return "" if dice.is_empty() else "This preset rolls dice (%s): previews show one possible roll." % ", ".join(PackedStringArray(dice))


## The whole screen as text.
static func render(db: Dictionary, r: Dictionary, preset: String, brief: bool = false) -> String:
	var st: Object = r["st"]
	var out: Array = []
	var f := Setup.fight(db, str(r.get("fight", "")))
	out.append("=== %s | preset %s | round %d ===" % [str(f.get("name", "")), preset, st.round_num])
	if str(f.get("text", "")) != "" and not brief:
		out.append(str(f["text"]))
	var goal: String = st.goal_line()
	out.append("Goal: " + (goal if goal != "" else "defeat every enemy."))
	for n in r.get("notes", []):
		out.append("NOTE: " + str(n))
	var log := _log_lines(r.get("events", []))
	if not log.is_empty():
		out.append("")
		out.append("What just happened:")
		for l in log:
			out.append("  " + l)
	if st.result != "":
		out.append("")
		out.append("FIGHT OVER: %s after %d rounds." % ["you WON" if st.result == "win" else ("you LOST" if st.result == "lose" else st.result), st.round_num])
		out.append("Fill in your rating card for this fight.")
		return "\n".join(PackedStringArray(out))
	out.append("")
	out.append_array(board(st))
	out.append("")
	out.append_array(unit_lines(st))
	out.append("")
	out.append_array(hand_lines(st))
	out.append("")
	var opts := options(st)
	out.append("Your options (pass numbers or named steps in --actions):")
	var note := dice_note(st)
	if note != "":
		out.append("  " + note)
	var moves: Array = []
	for i in opts.size():
		var o: Dictionary = opts[i]
		if brief and str(o["step"]["kind"]) == "move":
			var pv := str(o["preview"])
			var danger := pv.get_slice("stand in ", 1).get_slice(" telegraphed", 0) if pv.contains("stand in ") else ""
			moves.append("%d:m%d.%d%s" % [i + 1, o["step"]["cell"].x, o["step"]["cell"].y, "" if danger == "" else "(!%s)" % danger])
			continue
		out.append("  %d. %s%s" % [i + 1, o["label"], "" if str(o["preview"]) == "" else " -> " + str(o["preview"])])
	if not moves.is_empty():
		out.append("  Moves (number:step; (!n) = you'd stand in n telegraphed damage): " + " ".join(PackedStringArray(moves)))
	if st.rules.text("undo", "stack") != "off":
		out.append("  u. Undo the last step (%s)" % ("allowed" if st.can_undo(st.current) or st.can_undo_move(st.current) else _undo_reason(st, st.current)))
	return "\n".join(PackedStringArray(out))


static func _log_lines(events: Array) -> Array:
	var out: Array = []
	for e in events:
		match str(e.get("t", "")):
			"log", "say":
				var t := str(e.get("text", ""))
				if t != "" and (out.is_empty() or out[-1] != t):
					out.append(t)
			"round":
				out.append("-- round %d --" % int(e.get("n", 0)))
	return out.slice(maxi(0, out.size() - 30))


static func board(st: Object) -> Array:
	var out: Array = []
	var cols: int = st.grid.cols
	var rows: int = st.grid.rows
	var head := "    "
	for x in cols:
		head += str(x % 10) + " "
	out.append("Board (numbers are your party, lowercase letters enemies; x,y = column,row):")
	out.append(head + "     Enemy plans (the letter of who will hit that tile):")
	var used := {}
	var plan := {}
	for e in st.units:
		if e.team == "enemy" and e.alive():
			for c in st.intent_cells(e):
				plan[c] = "+" if plan.has(c) else letter(st, e).to_upper()
	for y in rows:
		var line := "%2d  " % y
		var pl := "%2d  " % y
		for x in cols:
			var c := Vector2i(x, y)
			var ch := _tile_char(st, c)
			used[ch] = true
			var t: Object = st.unit_at(c)
			if t != null and t.alive():
				ch = letter(st, t)
				if t.is_prop():
					used["prop:" + ch + ":" + str(t.name)] = true
			line += ch + " "
			pl += str(plan.get(c, ".")) + " "
		out.append(line + "    " + pl)
	var legend: Array = []
	for k in used:
		var s := str(k)
		if s.begins_with("prop:"):
			legend.append("%s = %s (prop)" % [s.get_slice(":", 1), s.get_slice(":", 2)])
		elif s == "f":
			legend.append("f = burning")
		elif s == "o":
			legend.append("o = oil")
		elif s != ".":
			legend.append("%s = %s" % [s, TERRAIN_WORDS.get(s, s)])
	if not legend.is_empty():
		out.append("Tiles: " + ", ".join(PackedStringArray(legend)))
	var extra: Array = []
	if not st.grid.high.is_empty():
		extra.append("high ground " + " ".join(PackedStringArray(st.grid.high.keys().map(func(c: Vector2i) -> String: return _cell(c)))))
	if not st.grid.collapsing.is_empty():
		extra.append("floor collapsing soon " + " ".join(PackedStringArray(st.grid.collapsing.keys().map(func(c: Vector2i) -> String: return _cell(c)))))
	if not st.grid.doors.is_empty():
		extra.append("doors " + " ".join(PackedStringArray(st.grid.doors.keys().map(func(c: Vector2i) -> String: return _cell(c)))))
	if not st.grid.fog.is_empty():
		extra.append("fog " + " ".join(PackedStringArray(st.grid.fog.keys().map(func(c: Vector2i) -> String: return _cell(c)))))
	if not st.grid.exits.is_empty():
		extra.append("exit " + " ".join(PackedStringArray(st.grid.exits.map(func(c: Vector2i) -> String: return _cell(c)))))
	if not extra.is_empty():
		out.append("Also: " + "; ".join(PackedStringArray(extra)))
	return out


static func unit_lines(st: Object) -> Array:
	var out: Array = ["Units:"]
	for x in st.units:
		if x.is_prop() or (not x.alive() and x.team == "enemy"):
			continue
		var bits: Array = ["%s at %s" % [who(st, x), _cell(x.cell)], "HP %d/%d" % [maxi(0, x.hp), x.max_hp]]
		if x.shield > 0:
			bits.append("shield %d" % x.shield)
		if x.team == "party" and x.max_mp > 0:
			bits.append("MP %d/%d" % [x.mp, x.max_mp])
		var sts: Array = st.status_list(x)
		if not sts.is_empty():
			bits.append("status: " + ", ".join(PackedStringArray(sts)))
		if st.rules.flag("facing"):
			bits.append("facing %s" % _dir(x.facing_dir))
		if st.rules.flag("classGauges") and x.team == "party":
			bits.append("gauge %d" % x.gauge)
		if x.downed:
			bits.append("DOWNED")
		if x == st.current:
			bits.append("<- acting now (Move left %d, Action %s, Quick %s)" % [x.move_left, "used" if x.action_used or (st.uses_actions(x) and x.actions_left <= 0) else "ready",
				"used" if x.quick_used else "ready"])
		elif st.acted_this_round(x):
			bits.append("(already acted this round)")
		if x.team == "enemy":
			if Extras.plan_hidden(st, x):
				bits.append("plan: hidden in fog (?)")
			else:
				var w: String = st.intent_words(x)
				bits.append("plan: " + (w if w != "" else "nothing"))
		out.append("  " + ", ".join(PackedStringArray(bits)))
	var order: Array = []
	for i in st.order.size():
		var x: Object = st.order[i]
		if x.alive() and not x.is_prop():
			order.append(("[" + who(st, x) + "]") if x == st.current else who(st, x))
	out.append("Turn order: " + " > ".join(PackedStringArray(order)))
	if st.rules.flag("surge"):
		out.append("Surge: %d/%d (full Surge makes one card free)" % [st.surge, st.rules.count("surgeSize", 5)])
	return out


static func _dir(d: Vector2i) -> String:
	return { Vector2i(1, 0): "east", Vector2i(-1, 0): "west", Vector2i(0, 1): "south", Vector2i(0, -1): "north" }.get(d, "?")


static func hand_lines(st: Object) -> Array:
	var u: Object = st.current
	var out: Array = []
	if u == null or u.deck == null:
		return out
	out.append("%s's hand:" % u.name)
	for i in u.deck.hand.size():
		var card: Dictionary = st.card_of(u, i)
		var block: String = st.card_block(u, card)
		var tags: Array = []
		if st.is_quick_now(u, card):
			tags.append("Quick")
		out.append("  - %s (cost %d MP%s): %s%s" % [str(card.get("name", "?")), st.card_cost(u, card), (", " + ", ".join(PackedStringArray(tags))) if not tags.is_empty() else "",
			CardRules.describe(st.db, card), "" if block == "" else " [can't play now: %s]" % block])
	out.append("  Draw pile %d cards, discard %d, exhausted %d." % [u.deck.draw_pile.size(), u.deck.discard.size(), u.deck.exhausted.size()])
	return out


static func show_discard(st: Object) -> String:
	var u: Object = st.current
	if u == null or u.deck == null:
		return "Nobody is acting."
	if u.deck.discard.is_empty():
		return "%s's discard pile is empty." % u.name
	var names: Array = []
	for id in u.deck.discard:
		names.append(str(CardRules.resolve(st.db, str(id), st.library).get("name", id)))
	return "%s's discard pile (newest last): %s." % [u.name, ", ".join(PackedStringArray(names))]


static func ally_decks(st: Object) -> String:
	var bits: Array = []
	for x in st.units:
		if x.team == "party" and x.deck != null:
			bits.append("%s: hand %d, draw pile %d, discard %d" % [who(st, x), x.deck.hand.size(), x.deck.draw_pile.size(), x.deck.discard.size()])
	return "Deck sizes: " + "; ".join(PackedStringArray(bits)) + "."


## A lever's rules text, as the Lab's lever panel shows it.
static func explain(db: Dictionary, preset: String, lever: String) -> String:
	var values := Rules.values_for(db, preset)
	for s in Rules.lever_specs(db):
		if str(s["id"]).to_lower() == lever.to_lower() or str(s.get("name", "")).to_lower() == lever.to_lower():
			return "%s (%s): %s%s" % [str(s["name"]), str(s["id"]), _value_words(values.get(str(s["id"]))), (". " + str(s["hint"])) if s.has("hint") else "."]
	return "There's no lever called '%s'. Try 'rules' to see this preset's levers." % lever


static func _value_words(v: Variant) -> String:
	if typeof(v) == TYPE_BOOL:
		return "on" if bool(v) else "off"
	return Sweep.norm(v)


## The rules as a player learns them: the tutorial's lessons, then this preset's
## lever panel (the core levers always, the extras only when on).
static func rules_text(db: Dictionary, preset: String) -> String:
	var out: Array = ["RULES FOR PRESET %s" % preset]
	var rec := Rules.preset_rec(db, preset)
	out.append(str(rec.get("text", "")))
	out.append("")
	out.append("From the game's tutorial (it teaches today's rules; where the preset's levers below say otherwise, the levers win):")
	for room in db.get("story/tutorial_floor", {}).get("rooms", []):
		for step in room.get("lesson", []):
			var key := str(step.get("text", ""))
			if key != "":
				var t := Str.t(db, key)
				if t != key:
					out.append("- " + t)
	out.append("")
	out.append("This preset's levers (the Lab's lever panel):")
	var values := Rules.values_for(db, preset)
	for s in Rules.lever_specs(db):
		var id := str(s["id"])
		if str(s.get("group", "")) == "feel":
			continue
		var extra: bool = s.has("tag")
		var v: Variant = values.get(id)
		if extra and (typeof(v) == TYPE_BOOL and not bool(v) or str(v) == str(s.get("offValue", "<no off value>"))):
			continue
		out.append("- %s: %s%s" % [str(s["name"]), _value_words(v), (". " + str(s["hint"])) if s.has("hint") else ""])
	return "\n".join(PackedStringArray(out))

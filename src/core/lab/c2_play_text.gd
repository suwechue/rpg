## Combat 2.0 as text, for agent playtests (docs/COMBAT_2.md Part 5): replays
## inputs from the start of a slice fight (enemy turns play themselves) and shows
## the timeline, the board, every unit with its known markings, the acting
## character's kit with charges and cooldowns, and every option with its exact
## preview. Inputs: m3.2 move, a2@4.3 Ability 2 at a tile (a2 alone for self),
## b2 Baton Pass to party member 2, allout, i1 item 1, e end turn (Brace), or an
## option number. Pure data apart from reading the state.
extends RefCounted

const C2Setup := preload("res://src/core/combat2/c2_setup.gd")
const C2AI := preload("res://src/core/combat2/c2_ai.gd")
const Shapes := preload("res://src/core/combat2/shapes.gd")
const Kits := preload("res://src/core/combat2/kits.gd")
const Play := preload("res://src/core/lab/play_text.gd")
const GridScript := preload("res://src/core/combat/grid.gd")


static func replay(db: Dictionary, fight_id: String, level: int, seed_value: int, inputs: Array, levers: Dictionary = {}, carry: Dictionary = {}) -> Dictionary:
	var out := { "st": null, "error": "", "events": [], "fight": fight_id, "level": level }
	if C2Setup.fight(db, fight_id).is_empty():
		out["error"] = "There's no slice fight called '%s'. Fights: %s." % [fight_id, ", ".join(PackedStringArray(C2Setup.fights(db).map(func(f: Dictionary) -> String: return str(f["id"]))))]
		return out
	var st: Object = C2Setup.state(db, C2Setup.build(db, fight_id, { "level": level, "seed": seed_value, "c2Levers": levers, "carry": carry }))
	out["st"] = st
	_run_enemies(st)
	st.take_events()
	var recent: Array = []
	for i in inputs.size():
		if st.result != "":
			break
		var step := str(inputs[i])
		var why := _do(st, step)
		if why != "":
			out["error"] = "Sorry: input %d ('%s') didn't work: %s. Nothing after it was played." % [i + 1, step, why]
			break
		recent = st.take_events()
		_run_enemies(st)
		recent.append_array(st.take_events())
	out["events"] = recent
	return out


## Let everyone who isn't a party member waiting for orders take their turn.
static func _run_enemies(st: Object) -> void:
	var n := 0
	while st.result == "" and st.current != null and n < 200:
		n += 1
		var u: Object = st.current
		if u.team == "party" and not st.must_skip(u):
			return
		C2AI.take_turn(st, u)


static func _cell(s: String) -> Vector2i:
	var bits := s.split(".")
	return Vector2i(int(bits[0]), int(bits[1])) if bits.size() == 2 else Vector2i(-1, -1)


## One input. Returns "" when it worked, or why not.
static func _do(st: Object, step: String) -> String:
	var u: Object = st.current
	if u == null or u.team != "party":
		return "it isn't a party member's turn"
	if step.is_valid_int():
		var opts := options(st)
		var n := int(step)
		if n < 1 or n > opts.size():
			return "there's no option %d" % n
		step = str(opts[n - 1]["step"])
	if step == "e":
		st.end_turn()
		return ""
	if step == "allout":
		return "" if st.all_out(u) else "no All-Out Attack now (every enemy must be knocked down)"
	if step.begins_with("m"):
		var c := _cell(step.substr(1))
		if not st.reachable_cells(u).has(c):
			return "you can't move there (Move left %d)" % u.move_left
		st.move(u, c)
		return ""
	if step.begins_with("b"):
		var who := _party_member(st, int(step.substr(1)))
		if who == null:
			return "no party member %s" % step.substr(1)
		var why: String = st.baton_block(u, who)
		if why != "":
			return why
		st.baton_pass(u, who)
		return ""
	if step.begins_with("i"):
		var idx := int(step.substr(1)) - 1
		var why: String = st.item_block(u, idx)
		if why != "":
			return why
		st.use_item(u, idx)
		return ""
	if step.begins_with("a"):
		var body := step.substr(1)
		var at := body.find("@")
		var n := int(body.substr(0, at) if at >= 0 else body)
		var list: Array = st.abilities(u)
		if n < 1 or n > list.size():
			return "there's no Ability %d" % n
		var ab: Dictionary = list[n - 1]
		var why: String = st.ability_block(u, ab)
		if why != "":
			return why
		var target: Vector2i = _cell(body.substr(at + 1)) if at >= 0 else u.cell
		if not st.ability_targets(u, ab).has(target):
			return "%s can't be aimed at %d,%d" % [str(ab.get("name", "")), target.x, target.y]
		st.use_ability(u, str(ab["uid"]), target)
		return ""
	return "unknown input (use m, a, b, i, allout, e or an option number)"


static func _party_member(st: Object, n: int) -> Object:
	var i := 0
	for x in st.units:
		if x.team == "party" and not x.is_prop():
			i += 1
			if i == n:
				return x
	return null


## Every option for the acting party member: [{ step, label, preview }].
static func options(st: Object) -> Array:
	var u: Object = st.current
	var out: Array = []
	if u == null or u.team != "party" or st.result != "":
		return out
	if st.all_out_ready:
		out.append({ "step": "allout", "label": "ALL-OUT ATTACK (every enemy is down)", "preview": _all_out_preview(st, u) })
	if not st.one_more.is_empty():
		var i := 0
		for x in st.units:
			if x.team == "party" and not x.is_prop():
				i += 1
				if x != u and st.baton_block(u, x) == "":
					out.append({ "step": "b%d" % i, "label": "Baton Pass to %s (they act now: +damage, +1 Move)" % x.name, "preview": "" })
	var list: Array = st.abilities(u)
	for n in list.size():
		var ab: Dictionary = list[n]
		if st.ability_block(u, ab) != "":
			continue
		for t in st.ability_targets(u, ab):
			var pv: Dictionary = st.ability_preview(u, str(ab["uid"]), t)
			var words := _preview_words(st, pv)
			if words == "" and str(ab.get("target", "")) != "self" and not bool(ab.get("scan", false)) and not ab.has("terrain"):
				continue
			out.append({ "step": "a%d@%d.%d" % [n + 1, t.x, t.y] if t != u.cell or str(ab.get("shape", "")) not in ["self", "burst"] else "a%d" % (n + 1), "label": "%s at %d,%d" % [str(ab.get("name", "")), t.x, t.y], "preview": words })
	var brace := " (Brace: %d%% less damage until your next turn)" % roundi(st.c2.num("braceReduction", 0.25) * 100.0)
	out.append({ "step": "e", "label": "End turn" + (brace if not bool(st.acted.get(u.id, false)) else ""), "preview": "" })
	return out


static func _preview_words(st: Object, pv: Dictionary) -> String:
	var bits: Array = []
	for id in pv.get("units", {}):
		var r: Dictionary = pv["units"][id]
		var w := "%s %d -> %d HP" % [str(r["name"]), int(r["hp"]), int(r["hpAfter"])]
		if bool(r["dies"]):
			w = "%s defeated" % str(r["name"])
		elif bool(r["knocked"]):
			w += ", KNOCKED DOWN"
		if r["cell"] != r["cellAfter"]:
			w += ", moves to %d,%d" % [r["cellAfter"].x, r["cellAfter"].y]
		bits.append(w)
	if bool(pv.get("oneMore", false)):
		bits.append("ONE MORE")
	if bool(pv.get("allOut", false)):
		bits.append("All-Out ready")
	return "; ".join(PackedStringArray(bits))


static func _all_out_preview(st: Object, u: Object) -> String:
	var n := 0
	for e in st.units:
		if e.team == "enemy" and e.alive() and e.statuses.has("knocked"):
			for a in st.allies_of(u):
				if GridScript.manhattan(a.cell, e.cell) <= a.movement + st.c2.count("allOutRange", 1):
					n += 1
					break
	return "%d knocked-down enemies in reach" % n


static func render(db: Dictionary, r: Dictionary, brief: bool = false) -> String:
	if str(r.get("error", "")) != "" and r.get("st") == null:
		return str(r["error"])
	var st: Object = r["st"]
	var out: Array = []
	if str(r.get("error", "")) != "":
		out.append(str(r["error"]))
		out.append("")
	var f := C2Setup.fight(db, str(r["fight"]))
	out.append("%s, round %d. %s" % [str(f.get("name", "")), st.round_num, str(f.get("teaches", ""))])
	out.append("Goal: defeat every enemy. You lose if the whole party is down.")
	var log := _log_lines(st, r.get("events", []))
	if not log.is_empty():
		out.append("")
		out.append("What just happened:")
		for l in log:
			out.append("  " + l)
	if st.result != "":
		out.append("")
		out.append("FIGHT OVER: %s after %d rounds." % ["you WON" if st.result == "win" else "you LOST", st.round_num])
		if r.has("night") and st.result == "win":
			out.append(_night_next(db, r, st))
		out.append("Fill in your rating card for this fight.")
		return "\n".join(PackedStringArray(out))
	out.append("")
	var tl: Array = []
	for e in st.c2_timeline():
		tl.append(("" if int(e["round"]) == st.round_num else "r%d:" % int(e["round"])) + str(e["unit"].name))
	out.append("Turn order: " + " > ".join(PackedStringArray(tl.slice(0, 14))))
	out.append("")
	for line in Play.board(st):
		var l := str(line)
		if l.contains("Enemy plans"):
			l = l.get_slice("     Enemy plans", 0)
		elif l.length() > 3 and l.substr(0, 2).strip_edges().is_valid_int() and l.rfind("    ") > 0:
			l = l.substr(0, l.rfind("    "))
		if l.begins_with("Also: exit"):
			continue
		out.append(l.replace("Board (numbers are your party, lowercase letters enemies; x,y = column,row):", "Board (numbers are your party, letters are enemies; x,y = column,row):"))
	for bid in st.boss_plans:
		var p: Dictionary = st.boss_plans[bid]
		out.append("BIG ATTACK MARKED: %s's %s lands on its next turn on %s" % [st.unit_by_id(str(bid)).name, str(p["name"]), ", ".join(PackedStringArray((p["cells"] as Array).map(func(c: Vector2i) -> String: return "%d,%d" % [c.x, c.y])))])
	out.append("")
	out.append("Units:")
	for x in st.units:
		if x.is_prop() or not x.alive():
			continue
		var bits: Array = ["%s %s at %d,%d" % [Play.letter(st, x), x.name, x.cell.x, x.cell.y], "HP %d/%d" % [maxi(0, x.hp), x.max_hp]]
		if x.shield > 0:
			bits.append("shield %d" % x.shield)
		bits.append("faces %s" % _dir(x.facing_dir))
		if not x.statuses.is_empty():
			bits.append("status: " + ", ".join(PackedStringArray(x.statuses.keys())))
		if x.team == "enemy":
			var known: Dictionary = st.known_of(x)
			var marks: Array = []
			for k in known:
				marks.append("%s %s" % [k, known[k]])
			bits.append("markings: " + (", ".join(PackedStringArray(marks)) if not marks.is_empty() else "?") + ("" if known.size() >= (x.source.get("marks", {}) as Dictionary).size() else " (rest unknown)"))
		else:
			var k: Dictionary = st.kit_of(x)
			bits.append("weak to %s; resists %s" % [", ".join(PackedStringArray(k.get("weak", []))) if not (k.get("weak", []) as Array).is_empty() else "nothing", ", ".join(PackedStringArray(k.get("resist", []))) if not (k.get("resist", []) as Array).is_empty() else "nothing"])
			bits.append("ultimate %d/%d" % [int(st.meter.get(x.id, 0)), st.c2.count("ultMax", 100)])
		if x == st.current:
			bits.append("<- acting now (Move left %d%s)" % [x.move_left, ", ONE MORE waiting" if not st.one_more.is_empty() else ""])
		out.append("  " + ", ".join(PackedStringArray(bits)))
	var u: Object = st.current
	out.append("")
	out.append("%s's kit (a1, a2...):" % u.name)
	var list: Array = st.abilities(u)
	for n in list.size():
		var ab: Dictionary = list[n]
		var state_word: String = st.ability_block(u, ab)
		var extra := ""
		if str(ab.get("kind", "")) == "spell":
			extra = ", %d of %d charges left tonight" % [int(st.charges_left.get(u.id, {}).get(str(ab["uid"]), 0)), int(ab.get("maxCharges", 1))]
		out.append("  a%d. %s [%s]: %s%s%s" % [n + 1, str(ab.get("name", "")), str(ab.get("kind", "")), _quick(ab), extra, (" (can't now: %s)" % state_word) if state_word != "" else ""])
	if not st.backpack_c2.is_empty():
		var items: Array = []
		for k in st.backpack_c2.size():
			var it := Kits.item(db, str(st.backpack_c2[k]))
			items.append("i%d %s (%s)" % [k + 1, str(it.get("name", "")), str(it.get("text", ""))])
		out.append("Items (one free use per turn, doesn't end it): " + "; ".join(PackedStringArray(items)))
	out.append("")
	var opts := options(st)
	out.append("Your options (pass numbers or named steps in --actions):")
	var moves: Array = []
	if u.move_left > 0 and st.can_move(u):
		var threat: Dictionary = st.all_threat()
		var reach: Array = st.reachable_cells(u).keys()
		reach.sort()
		for c in reach:
			moves.append("m%d.%d%s" % [c.x, c.y, "(!%d)" % (threat[c] as Array).size() if threat.has(c) else ""])
	for i in opts.size():
		var o: Dictionary = opts[i]
		out.append("  %d. %s%s  [%s]" % [i + 1, str(o["label"]), "" if str(o["preview"]) == "" else " -> " + str(o["preview"]), str(o["step"])])
	if not moves.is_empty():
		out.append("  Moves (move first, then one Ability ends your turn; (!n) = n enemies can reach and hit that tile next turn): " + " ".join(PackedStringArray(moves)))
	return "\n".join(PackedStringArray(out))


static func _quick(ab: Dictionary) -> String:
	var bits: Array = [str(ab.get("shape", "")) + (" range %d" % int(ab["range"]) if ab.has("range") else "")]
	if float(ab.get("power", 0)) > 0.0:
		bits.append("%s %d" % [str(ab.get("type", "")), roundi(float(ab["power"]))])
	for k in ["push", "pull", "heal", "shield"]:
		if ab.has(k):
			bits.append("%s %d" % [k, roundi(float(ab[k]))])
	if ab.has("status"):
		bits.append("%s %d" % [str(ab["status"].get("id", "")), int(ab["status"].get("turns", 1))])
	if bool(ab.get("scan", false)):
		bits.append("reveals markings")
	if bool(ab.get("knockdown", false)):
		bits.append("knocks down")
	if bool(ab.get("actNow", false)):
		bits.append("the ally acts next")
	if bool(ab.get("delay", false)):
		bits.append("delays the target")
	if bool(ab.get("allAlliesAct", false)):
		bits.append("every ally acts again")
	if int(ab.get("cooldown", 0)) > 0:
		bits.append("cooldown %d" % int(ab["cooldown"]))
	return ", ".join(PackedStringArray(bits))


static func _dir(d: Vector2i) -> String:
	match d:
		Vector2i(1, 0):
			return "right"
		Vector2i(-1, 0):
			return "left"
		Vector2i(0, 1):
			return "down"
		Vector2i(0, -1):
			return "up"
	return "right"


static func _log_lines(st: Object, events: Array) -> Array:
	var out: Array = []
	for e in events:
		var who: Object = st.unit_by_id(str(e.get("unit", ""))) if e.has("unit") else null
		var nm: String = who.name if who != null else "Someone"
		match str(e.get("t", "")):
			"log":
				out.append(str(e.get("text", "")))
			"cast":
				out.append("%s uses %s." % [nm, str(e.get("name", ""))])
			"damage":
				out.append("%s takes %d damage%s." % [nm, int(e.get("amount", 0)), (" (%s)" % str(e["cause"])) if str(e.get("cause", "hit")) != "hit" else ""])
			"down":
				out.append("%s goes down." % nm)
			"death":
				out.append("%s is defeated." % nm)
			"push":
				out.append("%s is pushed to %d,%d." % [nm, e["to"].x, e["to"].y] if e.get("to") is Vector2i else "%s is pushed." % nm)
			"cutin":
				out.append("*** %s ***" % str(e.get("text", "")))
			"reveal":
				if e.has("type"):
					out.append("Learned: %s is %s to %s." % [nm, str(e.get("mark", "")), str(e["type"])])
			"round":
				out.append("-- round %d --" % int(e.get("n", 0)))
	return out.slice(maxi(0, out.size() - 40))


## The rules in plain words, for --cmd=rules (numbers come from the levers).
static func rules_text(db: Dictionary) -> String:
	var r: RefCounted = (load("res://src/core/combat2/c2_rules.gd") as GDScript).build(db)
	var lines: Array = [
		"COMBAT 2.0 RULES",
		"- Turn order: everyone (your party and the enemies) acts in one shared order by Initiative, shown as 'Turn order'. Haste moves a unit up, Slow down.",
		"- Your turn: move first (up to your Move), then use ONE Ability. Using an Ability ends your turn%s." % ("" if r.flag("moveAfterAct") else "; you can't move after it"),
		"- Abilities: class moves (unlimited, some have a cooldown in your own turns), spells (limited charges for the whole night; they don't come back between fights) and an ultimate (needs a full meter, filled by dealing and taking damage, knockdowns and Baton Passes).",
		"- One free item use per turn; it doesn't end your turn.",
		"- Ending your turn without an Ability is Brace: you take %d%% less damage until your next turn." % roundi(r.num("braceReduction") * 100.0),
		"- Facing: units face the way they last moved or acted. Hits from behind deal x%.2f, from the side x%.2f." % [r.num("backMul"), r.num("sideMul")],
		"- Markings: every enemy is weak, resistant or immune to some types (blunt, blade, pierce, and Vectors like heat, cold, lightning, sound, shadow, force, poison, light). They show as '?' until you hit with that type or scan the enemy. Weak x%.2f, resist x%.2f, immune 0." % [r.num("weakMul"), r.num("resistMul")],
		"- Knockdown: hitting a weakness knocks the enemy down. Knocked-down enemies take x%.2f damage and spend their next turn getting up." % r.num("knockdownMul"),
		"- ONE MORE: knocking down an enemy that wasn't down gives you one extra Ability right away (no Move), once per turn.",
		"- Baton Pass: instead of using your One More, pass it to an ally: they act right now with +%d%% damage (stacks up to +%d%%) and +%d Move." % [roundi(r.num("batonBonus") * 100.0), roundi(r.num("batonMax") * 100.0), r.count("batonMove")],
		"- ALL-OUT ATTACK: when every enemy is knocked down, you may launch it: every ally hits every knocked-down enemy within their Move + %d for big damage, then the enemies stand up. You can decline it." % r.count("allOutRange"),
		"- Enemies: their attacks land on their own turn (no dodging after the fact); move out of their reach or put the tank in front. Some enemies knock YOU down by hitting your party's weaknesses and get their own One More. Bosses mark their big attacks a turn ahead: leave the marked tiles.",
		"- Pushes into walls, units, pits and spikes hurt. Barrels and oil react to fire; ice slides.",
		"- You lose only if the whole party is down.",
		"INPUTS: m3.2 move to column 3 row 2; a2@4.3 use Ability 2 at that tile (a2 alone for self abilities); b2 Baton Pass to party member 2; allout; i1 use item 1; e end turn; or an option number.",
	]
	return "
".join(PackedStringArray(lines))


## A night fight is over: the carry for the next fight (after the rest room if one comes next).
static func _night_next(db: Dictionary, r: Dictionary, st: Object) -> String:
	var steps: Array = C2Setup.night(db, str(r["night"])).get("steps", [])
	var fights: Array = steps.filter(func(x: Variant) -> bool: return str(x) != "rest")
	var n := int(r.get("step", 1))
	if n >= fights.size():
		return "That was the last fight of the night."
	var carry: Dictionary = st.carry_out()
	var at := steps.find(fights[n - 1])
	var rested := at + 1 < steps.size() and str(steps[at + 1]) == "rest"
	if rested:
		var Night: GDScript = load("res://src/core/combat2/night.gd")
		var rules: RefCounted = (load("res://src/core/combat2/c2_rules.gd") as GDScript).build(db)
		var kits: Array = []
		for x in st.units:
			if x.team == "party" and not x.is_prop():
				kits.append(st.kit_of(x))
		carry = Night.rest_room(carry, kits, rules)
	return "%sNext: --night=%s --step=%d --carry='%s'" % ["You rest first: a rest room gives +1 charge on each spell and some HP. " if rested else "", str(r["night"]), n + 1, JSON.stringify(carry)]


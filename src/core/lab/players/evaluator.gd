## The state score the Lab players share (docs/LAB_TUNER.md Part 2), from the
## party's side: their HP, kills, the telegraphs still aimed at them (one enemy
## turn of lookahead), Surge and setups. Weights: data/lab/players.json.
extends RefCounted


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("lab/players", {})


## The base weights with a profile's on top.
static func weights(db: Dictionary, profile: Dictionary) -> Dictionary:
	var w: Dictionary = cfg(db).get("weights", {}).duplicate()
	w.merge(profile.get("weights", {}), true)
	return w


static func score(st: Object, w: Dictionary) -> float:
	if st.result == "win":
		return float(w.get("win", 60.0)) + _board(st, w)
	if st.result == "lose":
		return -float(w.get("loss", 60.0)) + _board(st, w)
	return _board(st, w)


static func _board(st: Object, w: Dictionary) -> float:
	var s := 0.0
	var incoming_at: Dictionary = incoming(st) if float(w.get("threat", 0.0)) != 0.0 or float(w.get("lethal", 0.0)) != 0.0 else {}
	for x in st.units:
		if x.is_prop():
			continue
		if x.team == "party":
			if bool(x.source.get("object", false)):
				s += float(w.get("objectHp", 1.5)) * float(maxi(0, x.hp))
			elif not x.alive():
				s -= float(w.get("downed", 8.0))
				continue
			else:
				s += float(w.get("partyHp", 1.0)) * float(x.hp)
				s += float(w.get("shield", 0.5)) * float(x.shield)
				s += float(w.get("allyStatus", 0.0)) * float(x.statuses.size())
				s += float(w.get("mp", 0.0)) * float(x.mp)
				s += float(w.get("gauge", 0.0)) * float(x.gauge)
				s += float(w.get("firedUp", 0.0)) * float(int(x.links.get("fired_up", "0")))
				if x.deck != null:
					s += float(w.get("handCard", 0.0)) * float(x.deck.hand.size())
			if x.alive() and incoming_at.has(x):
				var hit := int(incoming_at[x])
				s -= float(w.get("threat", 0.9)) * float(mini(hit, x.hp + x.shield))
				if hit >= x.hp + x.shield:
					s -= float(w.get("lethal", 5.0))
				elif hit > 0 and st.rules.flag("firedUp"):
					s += float(w.get("firedUp", 0.0)) * float(st.fired_up_bonus(hit))
		elif x.team == "enemy":
			if x.alive():
				s -= float(w.get("enemyHp", 1.2)) * float(x.hp + x.shield)
				s -= float(w.get("enemyAlive", 4.0))
				s += float(w.get("enemyStatus", 0.0)) * float(x.statuses.size())
	s += float(w.get("surge", 0.0)) * float(st.surge)
	return s


## Telegraphed damage aimed at each party member where they stand now: the same
## numbers as CombatState.threats(), worked out only for the tiles they're on.
static func incoming(st: Object) -> Dictionary:
	var out := {}
	var party: Array = []
	for x in st.units:
		if x.team == "party" and x.alive() and not x.is_prop():
			party.append(x)
	if party.is_empty():
		return out
	if not st.delayed.is_empty() or not st.charges.is_empty():
		var all: Dictionary = st.threats()
		for x in party:
			for h in all.get(x.cell, []):
				var src: Object = st.unit_by_id(str(h["unit"]))
				if src != null and (src.team != "party" or bool(h.get("neutral", false))):
					out[x] = int(out.get(x, 0)) + int(h["damage"])
		return out
	for e in st.units:
		if e.team != "enemy" or not e.alive() or e.intent.is_empty():
			continue
		var cells: Array = st.intent_cells(e)
		if cells.is_empty():
			continue
		for x in party:
			if cells.has(x.cell):
				out[x] = int(out.get(x, 0)) + st.intent_damage(e, x.cell) * int(e.intent.get("repeat", 1))
	return out

## Encounter templates (docs/ARENA.md Part 4b, data/encounters.json): a
## fight's enemies are role slots filled with this week's enemies, weighted by
## the week's signature, sized by an enemy budget (minions count as half).
extends RefCounted

const VO := preload("res://src/core/vector_ops.gd")
const DT := preload("res://src/core/data_tables.gd")
const Sig := preload("res://src/core/dungeon/signature.gd")
const EnemyMods := preload("res://src/core/combat/enemy_mods.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("encounters", {})


## Roles an enemy can fill (from data "roles", or inferred from its behavior and stats).
static func roles_of(rec: Dictionary) -> Array:
	if rec.has("roles"):
		return rec["roles"]
	var out: Array = ["fighter"]
	var tier := str(rec.get("tier", "normal"))
	if tier == "minion":
		return ["minion"]
	if tier == "elite":
		out.append("elite")
	match str(rec.get("behavior", "")):
		"healer":
			out = ["healer"]
		"summoner":
			out.append("summoner")
		"shield_bearer", "anchor":
			out.append("front")
		"sniper":
			out.append("ranged")
		"hazard_maker":
			out.append("hazard")
		"charger":
			out.append("fast")
	if int(rec.get("movement", 3)) >= 5 and not out.has("fast"):
		out.append("fast")
	var ranged: bool = not rec.get("actions", []).is_empty()
	for a in rec.get("actions", []):
		if str(a.get("kind", "")) == "strike" or str(a.get("form", "")) == "touch":
			ranged = false
	if ranged and not out.has("ranged"):
		out.append("ranged")
	return out


## Enemies available this week for a role, weighted by the signature (tier filter: minions only for "minion").
static func pool(db: Dictionary, run: Dictionary, week: int, role: String) -> Dictionary:
	var out := {}
	var tiers := ["minion"] if role == "minion" else (["elite"] if role == "elite" else ["normal"])
	for t in tiers:
		var w := Sig.enemy_weights(db, run, week, t)
		var idx := DT.index_under(db, "enemies/", "enemies")
		for id in w:
			if roles_of(idx.get(str(id), {})).has(role):
				out[id] = w[id]
	return out


static func _pick(db: Dictionary, run: Dictionary, week: int, role: String, fallback: String, rng: RandomNumberGenerator) -> String:
	var p := pool(db, run, week, role)
	if p.is_empty() and fallback != "":
		p = pool(db, run, week, fallback)
	if p.is_empty():
		return ""
	return str(VO.sample(p, rng, p.keys()))


## The enemy budget for a room type this week (an inclusive [min, max] range rolled with the rng).
static func _in_week(db: Dictionary, id: String, week: int) -> bool:
	var rec: Dictionary = DT.index_under(db, "enemies/", "enemies").get(id, {})
	var weeks: Array = rec.get("weeks", [])
	return weeks.has(week) or weeks.has(float(week))


static func budget(db: Dictionary, week: int, room_type: String, rng: RandomNumberGenerator) -> int:
	var counts: Dictionary = cfg(db).get("counts", {})
	var wk := str(clampi(week, 1, 5))
	var span: Array = counts.get(wk, {}).get(room_type, counts.get(wk, {}).get("combat", [3, 4]))
	return rng.randi_range(int(span[0]), int(span[1]))


static func template(db: Dictionary, id: String) -> Dictionary:
	for t in cfg(db).get("templates", []):
		if str(t["id"]) == id:
			return t
	return {}


## Pick a template for this week (elite rooms always use an elite one).
static func pick_template(db: Dictionary, week: int, elite: bool, rng: RandomNumberGenerator) -> Dictionary:
	var w := {}
	var order: Array = []
	for t in cfg(db).get("templates", []):
		if bool(t.get("elite", false)) != elite:
			continue
		var weight := float(t.get("weights", {}).get(str(clampi(week, 1, 5)), 1.0 if elite else 0.0))
		if weight <= 0.0:
			continue
		w[str(t["id"])] = weight
		order.append(str(t["id"]))
	if order.is_empty():
		return {}
	return template(db, str(VO.sample(w, rng, order)))


## Build one encounter: { "template", "enemies": [ids], "roles": [role per enemy],
## "affixes": { index: [affix ids] }, "formation", "big", "layoutTag", "reinforcements" }.
static func build(db: Dictionary, run: Dictionary, week: int, room_type: String, rng: RandomNumberGenerator, budget_override: float = -1.0, template_week: int = -1) -> Dictionary:
	var elite := room_type == "elite"
	var tpl := pick_template(db, week if template_week < 0 else template_week, elite, rng)
	var base := float(budget(db, week, room_type, rng)) if budget_override < 0.0 else budget_override
	var total := base + float(tpl.get("minionBonus", 0)) * float(cfg(db).get("minionWeight", 0.5))
	var reinforce: Dictionary = tpl.get("reinforce", {})
	var main_budget := total * (1.0 - float(reinforce.get("share", 0.0)))
	var out := { "template": str(tpl.get("id", "")), "enemies": [], "roles": [], "affixes": {}, "formation": str(tpl.get("formation", "default")),
		"big": bool(tpl.get("big", false)), "layoutTag": str(tpl.get("layoutTag", "")), "reinforcements": {} }
	var spent := 0.0
	var minion_w := float(cfg(db).get("minionWeight", 0.5))
	for slot in tpl.get("slots", []):
		var role := str(slot["role"])
		var count := int(slot.get("count", 0))
		var same_id := ""
		var placed := 0
		while (count > 0 and placed < count) or (bool(slot.get("fill", false)) and spent < main_budget - 0.01):
			var id := same_id if same_id != "" else _pick(db, run, week, role, str(slot.get("fallback", "fighter")), rng)
			if slot.has("id") and _in_week(db, str(slot["id"]), week):
				# Combo-themed groups name their key enemy (PT Part 8).
				id = str(slot["id"])
			if id == "":
				break
			if bool(slot.get("same", false)):
				same_id = id
			var cost := minion_w if role == "minion" else 1.0
			if bool(slot.get("fill", false)) and spent + cost > main_budget + 0.01 and placed > 0:
				break
			out["enemies"].append(id)
			out["roles"].append("leader" if bool(slot.get("leader", false)) else role)
			if bool(slot.get("affixes", false)):
				var span: Array = cfg(db).get("eliteAffixes", [1, 2])
				out["affixes"][out["enemies"].size() - 1] = EnemyMods.roll(db, rng.randi_range(int(span[0]), int(span[1])), rng)
			spent += cost
			placed += 1
			if out["enemies"].size() > 12:
				break
	if not reinforce.is_empty():
		var extra: Array = []
		var left := total - spent
		while left > 0.5 and extra.size() < 6:
			var id := _pick(db, run, week, str(reinforce.get("role", "fighter")), "fighter", rng)
			if id == "":
				break
			extra.append(id)
			left -= 1.0
		if not extra.is_empty():
			out["reinforcements"] = { "round": int(reinforce.get("round", 3)), "enemies": extra }
	return out


## Party-size scaling (count and power), keeping at least `min` enemies and
## giving a full party one more.
static func scale_for_party(db: Dictionary, ids: Array, party_size: int, rng: RandomNumberGenerator) -> Dictionary:
	var ps: Dictionary = cfg(db).get("partyScale", {}).get(str(clampi(party_size, 1, 4)), {})
	var keep := maxi(int(ps.get("min", 2)), roundi(float(ids.size()) * float(ps.get("count", 1.0))))
	var picks: Array = range(mini(keep, ids.size()))
	for i in int(ps.get("extra", 0)):
		if not ids.is_empty():
			picks.append(rng.randi_range(0, ids.size() - 1))
	return { "indices": picks, "power": float(ps.get("power", 1.0)) }

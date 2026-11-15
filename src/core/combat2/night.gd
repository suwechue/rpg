## Combat 2.0 nights (docs/COMBAT_2.md Parts 2 and 5): fights in a row with HP
## and spell charges carried over, rest rooms between them, and the refills.
## A night's carry is { char id: { hp, charges: { spell uid: n } } }. Pure data.
extends RefCounted

const Kits := preload("res://src/core/combat2/kits.gd")


## Full HP and every charge: sleeping at home (and an arena checkpoint).
static func refill_all(kits: Array) -> Dictionary:
	var out := {}
	for k in kits:
		var ch := {}
		for s in k.get("spells", []):
			ch[str(s["uid"])] = int(s.get("maxCharges", 1))
		out[str(k["char"])] = { "hp": roundi(float(k.get("stats", {}).get("hp", 1))), "charges": ch }
	return out


static func home(kits: Array) -> Dictionary:
	return refill_all(kits)


static func checkpoint(kits: Array) -> Dictionary:
	return refill_all(kits)


## A rest room: +restRoomRefill charge on each spell (up to its max) and restRoomHeal of max HP.
static func rest_room(carry: Dictionary, kits: Array, rules: RefCounted) -> Dictionary:
	var out := carry.duplicate(true)
	for k in kits:
		var cid := str(k["char"])
		var max_hp := roundi(float(k.get("stats", {}).get("hp", 1)))
		var c: Dictionary = out.get(cid, { "hp": max_hp, "charges": {} })
		c["hp"] = mini(max_hp, int(c.get("hp", max_hp)) + roundi(float(max_hp) * rules.num("restRoomHeal", 0.3)))
		var ch: Dictionary = c.get("charges", {})
		for s in k.get("spells", []):
			var uid := str(s["uid"])
			ch[uid] = mini(int(s.get("maxCharges", 1)), int(ch.get(uid, s.get("maxCharges", 1))) + rules.count("restRoomRefill", 1))
		c["charges"] = ch
		out[cid] = c
	return out


## Charges spent and left across a night: { spent, left, max } (the "are charges hoarded?" metric).
static func charge_use(start: Dictionary, end: Dictionary) -> Dictionary:
	var spent := 0
	var left := 0
	var mx := 0
	for cid in start:
		var a: Dictionary = start[cid].get("charges", {})
		var b: Dictionary = end.get(cid, {}).get("charges", {})
		for uid in a:
			mx += int(a[uid])
			left += int(b.get(uid, a[uid]))
	spent = mx - left
	return { "spent": spent, "left": left, "max": mx }


## Where loadouts can change: home (free), the workbench, arena checkpoints and the
## campfire (free), dungeon rest rooms (one swap per character), never mid-fight.
static func swap_limit(place: String) -> int:
	match place:
		"home", "workbench", "checkpoint", "campfire":
			return -1
		"rest_room":
			return 1
	return 0

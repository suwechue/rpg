## Combat 2.0 perk and gear effects (docs/COMBAT_2.md Part 4): every effect line
## in data/combat2/perks.json and gear.json has a kind; the state asks this
## script what a kit's effects add up to. Pure data apart from reading the state.
extends RefCounted

const GridScript := preload("res://src/core/combat/grid.gd")


## The sum of every effect of this kind on a kit (perks and gear).
static func value(kit: Dictionary, kind: String) -> float:
	var n := 0.0
	for e in kit.get("effects", []):
		if str(e.get("kind", "")) == kind:
			n += float(e.get("value", 0))
	return n


static func has(kit: Dictionary, kind: String) -> bool:
	for e in kit.get("effects", []):
		if str(e.get("kind", "")) == kind:
			return true
	return false


## Extra damage share from damagePct effects whose filter matches this hit.
## ctx: { weak, downed, back }.
static func damage_pct(kit: Dictionary, ab: Dictionary, ctx: Dictionary) -> float:
	var n := 0.0
	for e in kit.get("effects", []):
		if str(e.get("kind", "")) != "damagePct":
			continue
		var f: Dictionary = e.get("filter", {})
		var ok := true
		if f.has("type") and str(f["type"]) != str(ab.get("type", "")):
			ok = false
		if f.has("shape") and str(f["shape"]) != str(ab.get("shape", "")):
			ok = false
		if f.has("tag") and not (ab.get("tags", []) as Array).has(str(f["tag"])):
			ok = false
		for k in ["weak", "downed", "back"]:
			if f.has(k) and bool(f[k]) != bool(ctx.get(k, false)):
				ok = false
		if ok:
			n += float(e.get("value", 0))
	return n


## Pin Down: a knocked-down unit can't stand while an enemy with the perk is next to it.
static func pinned(st: Object, u: Object) -> bool:
	for o in st.units:
		if o.alive() and o.team != u.team and not o.is_prop() and GridScript.manhattan(o.cell, u.cell) == 1:
			if value(st.kit_of(o), "pinDowned") > 0.0:
				return true
	return false


## The party's Bond tier as a number (0 none ... 4 unbreakable). The Lab sets it by lever;
## a story fight passes "bondTier" in the setup.
static func bond_tier(st: Object) -> int:
	var tiers: Array = st.db.get("combat2/rules", {}).get("bondTiers", ["none", "acquaintance", "friend", "close", "unbreakable"])
	var tier := str(st.c2_setup.get("bondTier", st.c2.text("labBondTier", "friend")))
	return maxi(0, tiers.find(tier))


## blunt, blade and pierce are physical; everything else is a Vector.
static func physical(db: Dictionary, vtype: String) -> bool:
	return (db.get("combat2/rules", {}).get("physicalTypes", ["blunt", "blade", "pierce"]) as Array).has(vtype)

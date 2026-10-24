## Class advancement (DESIGN.md Section 6, "Advancement"). At levels 5 and 12
## a Class Change offers every class whose Gate you meet: previous class,
## stats, and story requirements (attendance, shifts, Bonds, flags, Wild
## Surges survived). Taking one swaps growth weights and the signature perk;
## you keep one perk from your old class.
class_name ClassChange
extends RefCounted

const RM := preload("res://src/core/run/run_model.gd")
const Char := preload("res://src/core/character.gd")
const DT := preload("res://src/core/data_tables.gd")


static func classes(db: Dictionary) -> Array:
	return db.get("classes", {}).get("classes", [])


## Highest tier on offer at this level marker.
static func max_tier_at(level: int) -> int:
	return 3 if level >= 12 else 2


## Why this class isn't available to this character, or "".
static func requirement_error(db: Dictionary, run: Dictionary, ch: Dictionary, cls: Dictionary) -> String:
	var req: Dictionary = cls.get("requires", {})
	if str(cls.get("id", "")) == str(ch.get("class", "")) or Array(ch.get("classHistory", [])).has(str(cls.get("id", ""))):
		return "Already taken."
	if req.has("classes"):
		var ok := false
		for c in req["classes"]:
			ok = ok or Array(ch.get("classHistory", [ch.get("class", "")])).has(str(c))
		if not ok:
			return "Needs: %s." % ", ".join(PackedStringArray(Array(req["classes"]).map(func(c: Variant) -> String: return str(c).capitalize())))
	var st := Char.effective_stats(db, ch)
	for s in req.get("stats", {}):
		if int(st.get(s, 0)) < int(req["stats"][s]):
			return "Needs %s %d." % [str(s).to_upper(), int(req["stats"][s])]
	for v in req.get("knownVectorsAll", []):
		if not ch.get("knownVectors", []).has(v):
			return "Needs to know %s." % str(v).capitalize()
	if req.has("knownVectorsAny"):
		var any := false
		for v in req["knownVectorsAny"]:
			any = any or ch.get("knownVectors", []).has(v)
		if not any:
			return "Needs to know %s." % " or ".join(PackedStringArray(Array(req["knownVectorsAny"]).map(func(v: Variant) -> String: return str(v).capitalize())))
	for f in req.get("knownForms", []):
		if not ch.get("knownForms", []).has(f):
			return "Needs the %s Form." % str(f).capitalize()
	for c in req.get("attended", {}):
		if int(run.get("attendance", {}).get(c, 0)) < int(req["attended"][c]):
			return "Needs %s attended %d times." % [str(c).capitalize(), int(req["attended"][c])]
	for c in req.get("counters", {}):
		if int(run.get("shifts", {}).get(c, 0)) < int(req["counters"][c]):
			return "Needs %d %s." % [int(req["counters"][c]), str(c).replace("_", " ")]
	for npc in req.get("minBond", {}):
		if RM.bond(run, str(npc)) < float(req["minBond"][npc]):
			return "Needs Bond %d with %s." % [int(req["minBond"][npc]), str(db.get("npcs/" + str(npc), {}).get("name", npc))]
	for f in req.get("flags", []):
		if not RM.flag(run, str(f)):
			return "Something has to happen first."
	if req.has("wildSurges") and int(ch.get("wildSurges", 0)) < int(req["wildSurges"]):
		return "Needs %d Wild Surges survived." % int(req["wildSurges"])
	return ""


## Classes on offer: tier 2 (and 3 from level 12), split into available and locked.
static func options(db: Dictionary, run: Dictionary, ch: Dictionary) -> Dictionary:
	var avail: Array = []
	var locked: Array = []
	var top := max_tier_at(int(ch.get("level", 1)))
	for c in classes(db):
		var t := int(c.get("tier", 1))
		if t < 2 or t > top:
			continue
		var err := requirement_error(db, run, ch, c)
		if err == "":
			avail.append(str(c["id"]))
		elif err != "Already taken." and not bool(c.get("hidden", false)):
			locked.append({ "id": str(c["id"]), "why": err })
	return { "available": avail, "locked": locked }


## Change class. keep_perk must be one of the character's perks (or "").
static func apply(db: Dictionary, run: Dictionary, ch: Dictionary, class_id: String, keep_perk: String = "") -> String:
	var cls := DT.record(db, "classes", class_id)
	if cls.is_empty():
		return "No such class."
	ch["class"] = class_id
	ch["classHistory"] = ch.get("classHistory", []) + [class_id]
	ch["perks"] = [keep_perk] if keep_perk != "" and Array(ch.get("perks", [])).has(keep_perk) else []
	for f in cls.get("grantForms", []):
		if not ch["knownForms"].has(f):
			ch["knownForms"].append(f)
	for v in cls.get("grantVectors", []):
		if not ch["knownVectors"].has(v):
			ch["knownVectors"].append(v)
	ch.erase("pendingClassChange")
	Char.clamp_pools(db, ch)
	return ""


## Decline (wait for the next marker).
static func decline(ch: Dictionary) -> void:
	ch.erase("pendingClassChange")


## Party members advance into their dossier class at the first marker.
static func auto_advance(db: Dictionary, run: Dictionary, ch: Dictionary) -> String:
	var target := str(ch.get("advancedClass", ""))
	if target == "" or DT.record(db, "classes", target).is_empty() or ch.get("classHistory", []).has(target):
		ch.erase("pendingClassChange")
		return ""
	var keep := str(ch["perks"][0]) if not ch.get("perks", []).is_empty() else ""
	apply(db, run, ch, target, keep)
	return target

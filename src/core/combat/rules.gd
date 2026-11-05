## The Rules view (docs/COMBAT_LAB.md Part 1): every rule the Lab can switch is
## read here, built from the lever list in data/lab/lab.json, a preset from
## data/lab/presets.json and any changes on top. Fights that name no preset
## use "current", today's rules. Pure data: no nodes, no autoloads.
extends RefCounted

const CURRENT := "current"

var preset := CURRENT
var levers: Dictionary = {}
var changed: Dictionary = {}    # levers changed on top of the preset
var _queued: Dictionary = {}    # changes made mid-fight: they apply from the next turn


static func lever_specs(db: Dictionary) -> Array:
	return db.get("lab/lab", {}).get("levers", [])


static func presets(db: Dictionary) -> Array:
	return db.get("lab/presets", {}).get("presets", [])


static func preset_rec(db: Dictionary, id: String) -> Dictionary:
	for p in presets(db):
		if str(p.get("id", "")) == id:
			return p
	return {}


static func _game_value(db: Dictionary, path: String) -> Variant:
	var at: Variant = db
	for key in path.split("."):
		if typeof(at) != TYPE_DICTIONARY or not (at as Dictionary).has(key):
			return null
		at = at[key]
	return at


## Lever values for a preset: defaults, then the preset, then its fromGame reads.
static func values_for(db: Dictionary, preset_id: String) -> Dictionary:
	var out := {}
	for s in lever_specs(db):
		out[str(s["id"])] = s["default"]
	var rec := preset_rec(db, preset_id)
	out.merge(rec.get("levers", {}), true)
	for k in rec.get("fromGame", {}):
		var v: Variant = _game_value(db, str(rec["fromGame"][k]))
		if v != null:
			out[str(k)] = v
	return out


static func build(db: Dictionary, preset_id: String = CURRENT, overrides: Dictionary = {}) -> RefCounted:
	var r: RefCounted = (load("res://src/core/combat/rules.gd") as GDScript).new()
	r.preset = preset_id
	r.levers = values_for(db, preset_id)
	r.levers.merge(overrides, true)
	r.changed = overrides.duplicate()
	return r


## Levers that differ between two value sets, for the logs and the Lab screen.
static func diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for k in b:
		if a.get(k) != b[k]:
			out[k] = b[k]
	return out


func v(key: String, fallback: Variant = null) -> Variant:
	return levers.get(key, fallback)


func flag(key: String, fallback: bool = false) -> bool:
	return bool(levers.get(key, fallback))


func num(key: String, fallback: float = 0.0) -> float:
	return float(levers.get(key, fallback))


func count(key: String, fallback: int = 0) -> int:
	return int(levers.get(key, fallback))


func text(key: String, fallback: String = "") -> String:
	return str(levers.get(key, fallback))


func is_current() -> bool:
	return preset == CURRENT and changed.is_empty()


## A lever changed during a fight waits for the next turn.
func queue(key: String, value: Variant) -> void:
	_queued[key] = value


func has_queued() -> bool:
	return not _queued.is_empty()


## Apply queued changes. Returns what changed.
func apply_queued() -> Dictionary:
	var done := _queued
	_queued = {}
	for k in done:
		levers[k] = done[k]
		changed[k] = done[k]
	return done


## The turn mode these levers describe.
func turn_mode() -> String:
	if flag("moveSeparate"):
		return "move_and_act"
	return "two_actions" if count("actionsPerTurn", 2) >= 2 else "move_or_act"


# --- Numbers --------------------------------------------------------------------

func small() -> bool:
	return flag("smallNumbers")


func damage_scale() -> float:
	return num("damageScale", 1.0) if small() else 1.0


func enemy_damage_scale() -> float:
	return num("enemyDamageScale", 1.0) if small() else 1.0


func enemy_hp_scale(boss: bool) -> float:
	var scale := (num("bossHpScale", 1.0) if boss else num("hpScale", 1.0)) if small() else 1.0
	return scale * num("enemyHpMul", 1.0)


func party_hp_scale() -> float:
	return num("partyHpScale", 1.0) if small() else 1.0


## A damaging number scaled down, never below 1.
func scaled(amount: float) -> int:
	return maxi(1, roundi(amount * damage_scale())) if amount > 0.0 else 0


## A number written on a Lab card (already small).
func flat(amount: float) -> int:
	return maxi(1, roundi(amount * num("flatDamageMul", 1.0))) if amount > 0.0 else 0

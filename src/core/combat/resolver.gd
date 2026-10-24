## Damage, healing and Instability math for combat (DESIGN.md Sections 8 and 9).
## Spell damage = Magnitude x Form multiplier x (1 + affinity bonus)
##   x Contest(card Vectors, target resistances) x (1 - Magic Resistance %).
## Physical damage = stat x card multiplier - Physical Defense.
class_name CombatResolver
extends RefCounted

const VO := preload("res://src/core/vector_ops.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")


static func combat_cfg(db: Dictionary) -> Dictionary:
	return db.get("stats", {}).get("combat", {})


## Contest multiplier of a card's Vector direction against a target.
static func contest_mult(db: Dictionary, vectors: Dictionary, target: UnitScript) -> float:
	var dir := VO.normalize_sum(vectors)
	if dir.is_empty():
		return 1.0
	return VO.contest(dir, target.resist, db.get("matchups", {}))


## Small bonus on the caster's strongest axes: affinity share x scale.
static func affinity_bonus(db: Dictionary, vectors: Dictionary, caster: UnitScript) -> float:
	var dir := VO.normalize_sum(vectors)
	var b := 0.0
	for axis in dir:
		b += float(dir[axis]) * float(caster.affinity.get(axis, 0.0))
	return b * float(combat_cfg(db).get("affinityBonusScale", 0.5))


static func magic_resist_pct(db: Dictionary, target: UnitScript) -> float:
	var cfg := combat_cfg(db)
	var mr := float(maxi(0, target.magic_resist - target.resist_shred)) * float(cfg.get("magicResistPctPerPoint", 2))
	if target.guard_active:
		mr += float(cfg.get("guardMagicResistPct", 15))
	return minf(mr, float(cfg.get("maxMagicResistPct", 60))) / 100.0


static func phys_defense(db: Dictionary, target: UnitScript) -> int:
	var d := target.phys_defense - target.defense_shred
	if target.guard_active:
		d += int(float(combat_cfg(db).get("guardDefense", 3)) * float(target.mods.get("combat", {}).get("guardMul", 1.0)))
	return maxi(0, d)


## Is the attacker behind or on the flank of the target (Backstab)?
static func is_flanking(attacker: UnitScript, target: UnitScript) -> bool:
	var dx := attacker.cell.x - target.cell.x
	if dx != 0 and signi(dx) == -target.facing:
		return true
	return attacker.cell.y != target.cell.y and absi(dx) <= 1


## Multipliers that apply to every hit from this attacker on this target.
static func shared_mult(db: Dictionary, attacker: UnitScript, target: UnitScript, ranged: bool, target_on_cover: bool, friend_adjacent: bool) -> float:
	var cfg := combat_cfg(db)
	var m := 1.0 + attacker.rally_bonus
	if attacker.perk == "backstab" and is_flanking(attacker, target):
		m *= float(cfg.get("flankMul", 1.5))
	if ranged and target_on_cover:
		m *= float(cfg.get("halfCoverRangedMul", 0.75))
	if friend_adjacent:
		m *= 1.0 + float(cfg.get("adjacentFriendDamagePct", 0.05))
	return m


## Expected spell damage before crit (used by previews and the AI).
static func spell_damage(db: Dictionary, power: float, form_mult: float, vectors: Dictionary, caster: UnitScript, target: UnitScript, extra_mult: float = 1.0) -> float:
	var dmg := power * form_mult * (1.0 + affinity_bonus(db, vectors, caster))
	dmg *= contest_mult(db, vectors, target)
	dmg *= 1.0 - magic_resist_pct(db, target)
	dmg *= 1.0 + float(caster.mods.get("combat", {}).get("spellDamagePct", 0.0))
	return dmg * extra_mult


## Physical damage before crit: stat x mult (+ infusion), minus defense.
static func strike_damage(db: Dictionary, base: float, attacker: UnitScript, target: UnitScript, extra_mult: float = 1.0) -> float:
	var dmg := base * (1.0 + float(attacker.mods.get("combat", {}).get("strikeDamagePct", 0.0))) * extra_mult
	return maxf(1.0, dmg - float(phys_defense(db, target)))


## Roll crit and round. Damaging hits deal at least 1.
static func finalize(db: Dictionary, dmg: float, attacker: UnitScript, rng: RandomNumberGenerator, crit_bonus: float = 0.0) -> Dictionary:
	var crit := rng.randf() * 100.0 < attacker.crit_pct + crit_bonus
	if crit:
		dmg *= float(combat_cfg(db).get("critMultiplier", 1.5))
	return { "amount": maxi(1, roundi(dmg)), "crit": crit }


## Healing amount for Light/Vitality Shield and Aura and heal items.
static func heal_amount(base: float, caster: UnitScript) -> int:
	return maxi(1, roundi(base * (1.0 + float(caster.mods.get("combat", {}).get("healPct", 0.0)))))


# --- Instability ---------------------------------------------------------------

## Does this cast need an Instability roll? Improvised: always. Prepared cards:
## only when they spend more than half the caster's current MP.
static func needs_roll(cost: int, current_mp: int, improvised: bool) -> bool:
	return improvised or float(cost) > float(current_mp) / 2.0


## Target number: 10 + 10 x (cost / current MP), +3 for improvised casts.
static func instability_target(db: Dictionary, cost: int, current_mp: int, improvised: bool) -> float:
	var t := 10.0 + 10.0 * float(cost) / float(maxi(1, current_mp))
	if improvised:
		t += float(db.get("vectors", {}).get("improvise", {}).get("instabilityBonus", 3))
	return t


## Chance that d20 + Stability / 2 meets the target.
static func stability_chance(db: Dictionary, stability: int, cost: int, current_mp: int, improvised: bool) -> float:
	if not needs_roll(cost, current_mp, improvised):
		return 1.0
	var need := ceili(instability_target(db, cost, current_mp, improvised) - float(stability) / 2.0)
	return clampf(float(21 - need) / 20.0, 0.0, 1.0)


## Roll d20 + Stability / 2. Returns { "ok": bool, "roll": n, "target": t }.
static func roll_stability(db: Dictionary, stability: int, cost: int, current_mp: int, improvised: bool, rng: RandomNumberGenerator) -> Dictionary:
	if not needs_roll(cost, current_mp, improvised):
		return { "ok": true, "roll": 0, "target": 0.0 }
	var d20 := rng.randi_range(1, 20)
	var total := float(d20) + float(stability) / 2.0
	var target := instability_target(db, cost, current_mp, improvised)
	return { "ok": total >= target, "roll": d20, "target": target }


## Sample the failure table (data/vectors.json "failures").
static func roll_failure(db: Dictionary, rng: RandomNumberGenerator) -> String:
	var table: Dictionary = db.get("vectors", {}).get("failures", { "fizzle": 4, "backlash": 3, "misfire": 2, "wild_surge": 1 })
	return VO.sample(table, rng, ["fizzle", "backlash", "misfire", "wild_surge"])


## A random Vector from the whole space with equal weights (Wild Surge).
static func wild_vector(db: Dictionary, rng: RandomNumberGenerator) -> String:
	var axes: Array = db.get("spaces", {}).get("arcane", {}).get("axes", [])
	var eq := {}
	for a in axes:
		eq[a] = 1.0
	return VO.sample(eq, rng, axes)

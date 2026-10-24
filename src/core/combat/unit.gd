## One unit on the combat grid: a party member (built from a character record),
## an enemy (built from data/enemies) or a prop (crate, construct).
class_name CombatUnit
extends RefCounted

const Char := preload("res://src/core/character.gd")
const DeckScript := preload("res://src/core/deck.gd")

var id := ""
var name := ""
var team := "party"          # "party", "enemy" or "prop"
var source: Dictionary = {}  # the character record or enemy record
var is_player := false
var ai_controlled := false
var guest := false
var boss := false
var cell := Vector2i.ZERO
var facing := 1              # +1 faces right (party), -1 faces left (enemies)
var spawn_index := 0

var hp := 1
var max_hp := 1
var mp := 0
var max_mp := 0
var movement := 3
var initiative := 0
var phys_defense := 0
var magic_resist := 0
var stability := 0
var crit_pct := 5.0
var mp_regen := 2
var stats: Dictionary = {}
var mods: Dictionary = {}
var resist: Dictionary = { "weakTo": [], "strongAgainst": [] }
var affinity: Dictionary = {}    # normalized Vector affinity
var known_vectors: Array = []
var known_forms: Array = []
var knowledge_tier := 1
var perk := ""
var disposition: Dictionary = {}
var actions: Array = []          # enemy actions from data
var xp := 0
var money := 0
var signature: Dictionary = {}
var sprite := ""
var sprite_frame: Array = []     # [w, h] for single-frame strips (bosses)
var phases: Array = []
var phase_index := 0
var blocks_sight := false
var expires := -1                # props: rounds left (-1 = permanent)

var deck: DeckScript = null
var statuses: Dictionary = {}    # name -> turns left
var shield := 0
var shield_turns := 0
var infusion: Dictionary = {}    # { "vectors": {}, "power": n, "strikes": n }
var auras: Array = []            # [{ "card": {}, "turns": n }]
var move_left := 0
var free_action_used := false
var downed := false
var dead := false
var turns_taken := 0
var perk_used := false
var rally_bonus := 0.0
var guard_active := false
var defense_shred := 0
var resist_shred := 0


func alive() -> bool:
	return not dead and not downed


func is_prop() -> bool:
	return team == "prop"


func hp_ratio() -> float:
	return float(hp) / float(maxi(1, max_hp))


## Build from a character record (player or party member). HP and MP carry
## over from the record so a night's fights share one pool.
static func from_character(db: Dictionary, ch: Dictionary, rng: RandomNumberGenerator) -> CombatUnit:
	var u := CombatUnit.new()
	u.id = str(ch.get("id", "?"))
	u.name = str(ch.get("name", u.id))
	u.team = "party"
	u.source = ch
	u.is_player = bool(ch.get("isPlayer", false))
	var d := Char.derived(db, ch)
	u.mods = Char.collect_mods(db, ch)
	u.stats = Char.effective_stats(db, ch, u.mods)
	u.max_hp = int(d["maxHp"])
	u.max_mp = int(d["maxMp"])
	u.hp = clampi(int(ch.get("hp", u.max_hp)), 0, u.max_hp)
	u.mp = clampi(int(ch.get("mp", u.max_mp)), 0, u.max_mp)
	u.movement = int(d["movement"])
	u.initiative = int(d["initiative"])
	u.phys_defense = int(d["physDefense"])
	u.magic_resist = int(d["magicResist"])
	u.stability = int(d["stability"])
	u.crit_pct = float(d["critChancePct"])
	u.mp_regen = int(d["mpRegen"])
	var res: Dictionary = ch.get("resistances", {})
	u.resist = { "weakTo": res.get("weakTo", []), "strongAgainst": res.get("strongAgainst", []) }
	u.affinity = Char.affinity_odds(db, ch)
	u.known_vectors = ch.get("knownVectors", []).duplicate()
	u.known_forms = ch.get("knownForms", []).duplicate()
	u.knowledge_tier = int(ch.get("knowledgeTier", 1))
	u.perk = str(Char.class_data(db, str(ch.get("class", ""))).get("perk", {}).get("id", ""))
	u.sprite = str(ch.get("sprite", ""))
	u.disposition = ch.get("disposition", {})
	var cfg: Dictionary = db.get("stats", {}).get("combat", {})
	u.deck = DeckScript.new(ch.get("deck", []), rng, cfg)
	u.facing = 1
	return u


## Build from an enemy record. `scale` multiplies HP and power (returning
## Friday enemies come back stronger).
static func from_enemy(rec: Dictionary, scale: float = 1.0) -> CombatUnit:
	var u := CombatUnit.new()
	u.id = str(rec.get("id", "enemy"))
	u.name = str(rec.get("name", u.id))
	u.team = "enemy"
	u.source = rec
	u.ai_controlled = true
	u.boss = str(rec.get("tier", "normal")) == "boss"
	u.max_hp = maxi(1, roundi(float(rec.get("hp", 10)) * scale))
	u.hp = u.max_hp
	u.mp = 0
	u.movement = int(rec.get("movement", 3))
	u.initiative = int(rec.get("initiative", 5))
	u.phys_defense = int(rec.get("physDefense", 0))
	u.magic_resist = int(rec.get("magicResist", 0))
	u.stability = int(rec.get("stability", 5))
	u.crit_pct = float(rec.get("critChancePct", 5))
	u.stats = rec.get("stats", { "str": 5, "dex": 5 })
	u.resist = { "weakTo": rec.get("weakTo", []), "strongAgainst": rec.get("strongAgainst", []) }
	u.disposition = rec.get("disposition", {})
	u.actions = []
	for a in rec.get("actions", []):
		var copy: Dictionary = a.duplicate(true)
		copy["power"] = float(copy.get("power", 5)) * scale
		u.actions.append(copy)
	u.xp = roundi(float(rec.get("xp", 5)) * scale)
	u.money = int(rec.get("money", 2))
	u.signature = rec.get("signature", {})
	u.sprite = str(rec.get("sprite", ""))
	u.sprite_frame = rec.get("spriteFrame", [])
	u.phases = rec.get("phases", [])
	u.facing = -1
	return u


## A prop: crate (pushable, breakable) or a construct.
static func make_prop(kind: String, hp_value: int, rounds: int = -1) -> CombatUnit:
	var u := CombatUnit.new()
	u.id = kind
	u.name = kind.capitalize()
	u.team = "prop"
	u.max_hp = hp_value
	u.hp = hp_value
	u.expires = rounds
	u.blocks_sight = kind == "construct"
	u.initiative = -99
	return u

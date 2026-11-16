## The Combat 2.0 slice in the Lab (docs/COMBAT_2.md Part 5): what's being
## played (a fight or a night), at which level, with which loadouts, and the
## night's progress. Static, so it survives scene changes; loadouts and saved
## loadouts are kept in a user file. Scenes only: the rules are in src/core/combat2/.
extends RefCounted

const C2Setup := preload("res://src/core/combat2/c2_setup.gd")
const Night := preload("res://src/core/combat2/night.gd")
const Kits := preload("res://src/core/combat2/kits.gd")
const C2Rules := preload("res://src/core/combat2/c2_rules.gd")
const UserPaths := preload("res://src/core/user_paths.gd")

const MENU := "res://src/scenes/combat2/c2_menu.tscn"
const COMBAT := "res://src/scenes/combat2/combat2.tscn"
const LOADOUT := "res://src/scenes/combat2/loadout_screen.tscn"
const FILE := "c2_loadouts.json"

static var fight_id := "c2_first_down"
static var level := 1
static var night_id := ""          # "" = a single fight
static var night_step := 0
static var carry: Dictionary = {}  # HP and charges through a night
static var known: Dictionary = {}  # markings found this session (the Journal)
static var rest_swaps: Dictionary = {}  # char id -> swaps used at this rest room
static var at_rest := false
static var loadouts: Dictionary = {}    # level -> char id -> loadout
static var saved: Dictionary = {}       # char id -> [3 saved loadouts]
static var last_result := ""
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var path := UserPaths.of(FILE)
	if FileAccess.file_exists(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(d) == TYPE_DICTIONARY:
			loadouts = d.get("loadouts", {})
			saved = d.get("saved", {})


static func save_file() -> void:
	var f := FileAccess.open(UserPaths.of(FILE), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({ "loadouts": loadouts, "saved": saved }, "  "))
		f.close()


## The loadout a character uses at the current level (stored, or their default).
static func loadout(db: Dictionary, char_id: String) -> Dictionary:
	_load()
	var at: Dictionary = loadouts.get(str(level), {})
	if at.has(char_id):
		return (at[char_id] as Dictionary).duplicate(true)
	return C2Setup.default_loadout(db, char_id, level)


static func set_loadout(char_id: String, lo: Dictionary) -> void:
	_load()
	var at: Dictionary = loadouts.get(str(level), {})
	at[char_id] = lo.duplicate(true)
	loadouts[str(level)] = at
	save_file()


static func party_ids(db: Dictionary) -> Array:
	return db.get("combat2/fights", {}).get("partyOrder", [])


## The setup for the fight being played now.
static func setup(db: Dictionary) -> Dictionary:
	var los := {}
	for cid in party_ids(db):
		los[str(cid)] = loadout(db, str(cid))
	return C2Setup.build(db, current_fight(db), { "level": level, "loadouts": los, "carry": carry if night_id != "" else {}, "known": known })


static func current_fight(db: Dictionary) -> String:
	if night_id == "":
		return fight_id
	var steps: Array = C2Setup.night(db, night_id).get("steps", [])
	return str(steps[night_step]) if night_step < steps.size() else ""


static func start_fight(id: String) -> void:
	fight_id = id
	night_id = ""
	carry = {}
	at_rest = false
	SceneRouter.goto(COMBAT)


static func start_night(db: Dictionary, id: String) -> void:
	night_id = id
	night_step = 0
	at_rest = false
	rest_swaps = {}
	var kits: Array = []
	var rules := C2Rules.build(db) as C2Rules
	for cid in party_ids(db):
		kits.append(Kits.build(db, rules, str(cid), level, loadout(db, str(cid))))
	carry = Night.home(kits)
	SceneRouter.goto(COMBAT)


## After a fight: keep what the night carries, then the next step (or back to the menu).
static func after_fight(db: Dictionary, result: String, out_carry: Dictionary, out_known: Dictionary) -> void:
	last_result = result
	known = out_known.duplicate(true)
	if night_id == "" or result != "win":
		night_id = "" if result != "win" else night_id
		if night_id == "":
			SceneRouter.goto(MENU)
			return
	carry = out_carry.duplicate(true)
	night_step += 1
	var steps: Array = C2Setup.night(db, night_id).get("steps", [])
	if night_step >= steps.size():
		night_id = ""
		SceneRouter.goto(MENU)
		return
	if str(steps[night_step]) == "rest":
		var kits: Array = []
		var rules := C2Rules.build(db) as C2Rules
		for cid in party_ids(db):
			kits.append(Kits.build(db, rules, str(cid), level, loadout(db, str(cid))))
		carry = Night.rest_room(carry, kits, rules)
		at_rest = true
		rest_swaps = {}
		SceneRouter.goto(LOADOUT)
		return
	SceneRouter.goto(COMBAT)


## Leave the rest room for the next fight.
static func leave_rest() -> void:
	at_rest = false
	night_step += 1
	SceneRouter.goto(COMBAT)


static func swap_place() -> String:
	return "rest_room" if at_rest else "home"

## M0 sandbox: a placeholder town on a 16px grid that exercises the day-part and
## AP loop. Walk with WASD/arrows (free), E to interact (costs AP), Space to end
## the day part. F5 saves, F9 loads. Replace with real town scenes in M5.
extends Node2D

const VO := preload("res://src/core/vector_ops.gd")
const TILE := 16
const COLS := 30
const ROWS := 16
const HUD_ROWS := 3

var player_tile := Vector2i(3, 12)
var _pois: Array = []
var _hud: Label


func _ready() -> void:
	_hud = Label.new()
	_hud.position = Vector2(4, 1)
	_hud.size = Vector2(472, 46)
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_theme_font_size_override("font_size", 8)
	add_child(_hud)
	EventBus.day_part_changed.connect(_on_day_part_changed)
	EventBus.ap_changed.connect(func(_ap: int) -> void: _refresh())
	Narrator.line_said.connect(func(_t: String) -> void: _refresh())
	_pois = DataDB.table("locations").get("locations", [])
	GameState.new_run()
	Narrator.say("Welcome to town, new kid. Walking is free. Everything else costs time.")
	_print_vector_demo()


func _unhandled_input(event: InputEvent) -> void:
	var dir := Vector2i.ZERO
	if event.is_action_pressed("move_up", true):
		dir = Vector2i.UP
	elif event.is_action_pressed("move_down", true):
		dir = Vector2i.DOWN
	elif event.is_action_pressed("move_left", true):
		dir = Vector2i.LEFT
	elif event.is_action_pressed("move_right", true):
		dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		player_tile = Vector2i(
			clampi(player_tile.x + dir.x, 0, COLS - 1),
			clampi(player_tile.y + dir.y, HUD_ROWS, ROWS - 1))
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("end_part"):
		var part: Dictionary = Calendar.current_part()
		if part.get("wholePart", false):
			Narrator.say("You skip class. Somewhere, a teacher writes your name down.")
		Calendar.advance_part()
	elif event.is_action_pressed("save_run"):
		Narrator.say("Saved." if SaveSystem.save_run() else "Save failed.")
	elif event.is_action_pressed("load_run"):
		Narrator.say("Loaded." if SaveSystem.load_run() else "No save to load.")


func _interact() -> void:
	var part: Dictionary = Calendar.current_part()
	if part.get("dungeon", false):
		if Calendar.day_name() == "fri":
			Narrator.say("The boss floor waits... once milestone M7 builds it. You survive, for now.")
		else:
			Narrator.say("You slip into the Upside-Down and somehow survive. (Dungeon arrives in M7.)")
		Calendar.advance_part()
		return
	if part.get("wholePart", false):
		_attend_class(int(part.get("period", 1)))
		return
	var poi := _poi_at(player_tile)
	if poi.is_empty():
		Narrator.say("Nothing to do here. Walk onto one of the marked places.")
		return
	var open_parts: Array = poi.get("openParts", [])
	if not open_parts.has(part.get("id", "")):
		Narrator.say("%s is closed right now." % poi.get("name", "That place"))
		return
	var cost := int(poi.get("ap", 1))
	if not Calendar.spend_ap(cost):
		Narrator.say("Not enough time left (needs %d AP). Press Space to move on." % cost)
		return
	var effects: Dictionary = poi.get("effects", {})
	_apply_stat_gains(effects)
	Narrator.say("%s: %s. (-%d AP)%s" % [poi.get("name", "?"), poi.get("action", ""), cost, _gain_text(effects)])


func _attend_class(period: int) -> void:
	var class_id := str(GameState.schedule[period - 1]) if period <= GameState.schedule.size() else ""
	var cls: Dictionary = DataDB.record("school_classes", class_id)
	var gains := {}
	for stat in cls.get("statGains", []):
		gains[stat] = 1
	_apply_stat_gains(gains)
	var affinity: Dictionary = cls.get("affinity", {})
	if not affinity.is_empty():
		GameState.player["vectorAffinity"] = VO.shift(GameState.player.get("vectorAffinity", {}), affinity)
	Narrator.say("You sit through %s.%s" % [cls.get("name", "class"), _gain_text(gains)])
	Calendar.advance_part()


func _apply_stat_gains(gains: Dictionary) -> void:
	if gains.is_empty():
		return
	var caps := {}
	var stat_max := float(DataDB.table("stats").get("statMax", 20))
	for stat in gains:
		caps[stat] = stat_max
	GameState.player["stats"] = VO.shift(GameState.player.get("stats", {}), gains, caps)
	EventBus.stats_changed.emit("player")


func _gain_text(gains: Dictionary) -> String:
	if gains.is_empty():
		return ""
	var parts: Array[String] = []
	for stat in gains:
		parts.append("%s +%d" % [str(stat).to_upper(), int(gains[stat])])
	return " " + ", ".join(PackedStringArray(parts))


func _poi_at(tile: Vector2i) -> Dictionary:
	for poi in _pois:
		var t: Array = poi.get("tile", [0, 0])
		if Vector2i(int(t[0]), int(t[1])) == tile:
			return poi
	return {}


func _on_day_part_changed(week: int, _day: String, _part_id: String) -> void:
	var cfg: Dictionary = DataDB.table("calendar")
	if week > int(cfg.get("totalWeeks", 5)):
		Narrator.say("Five weeks survived. That's the alpha. Roll credits (eventually).")
	_refresh()


func _refresh() -> void:
	if _hud == null:
		return
	var part: Dictionary = Calendar.current_part()
	var stats: Dictionary = GameState.player.get("stats", {})
	var stat_line := ""
	for k in ["str", "dex", "con", "int", "per", "wil", "cha"]:
		stat_line += "%s %d  " % [k.to_upper(), int(stats.get(k, 0))]
	var hint := "[E] interact   [Space] end part early   [F5/F9] save/load"
	if part.get("dungeon", false):
		hint = "[E] enter the Upside-Down"
	elif part.get("wholePart", false):
		hint = "[E] attend class   [Space] skip it"
	var poi := _poi_at(player_tile)
	var here: String = (" | here: " + str(poi.get("name", ""))) if not poi.is_empty() else ""
	_hud.text = "Week %d  %s  %s   AP %d/%d   seed %d%s\n%s\n%s   %s" % [
		Calendar.week(), Calendar.day_name().capitalize(), part.get("name", ""),
		Calendar.ap(), Calendar.max_ap(), GameState.run_seed, here,
		stat_line, Narrator.last_line, hint]
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 480, 270), Color("1b1f2b"))
	draw_rect(Rect2(0, 0, 480, HUD_ROWS * TILE), Color("10131b"))
	for x in range(0, COLS + 1):
		draw_line(Vector2(x * TILE, HUD_ROWS * TILE), Vector2(x * TILE, ROWS * TILE), Color(1, 1, 1, 0.05))
	for y in range(HUD_ROWS, ROWS + 1):
		draw_line(Vector2(0, y * TILE), Vector2(COLS * TILE, y * TILE), Color(1, 1, 1, 0.05))
	var part_id := str(Calendar.current_part().get("id", ""))
	for poi in _pois:
		var t: Array = poi.get("tile", [0, 0])
		var pos := Vector2(int(t[0]) * TILE, int(t[1]) * TILE)
		var color := Color(str(poi.get("color", "#888888")))
		var open_parts: Array = poi.get("openParts", [])
		if not open_parts.has(part_id):
			color = color.darkened(0.6)
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), color)
		draw_string(font, pos + Vector2(-8, -2), str(poi.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.8))
	var p := Vector2(player_tile.x * TILE, player_tile.y * TILE)
	draw_rect(Rect2(p + Vector2(3, 3), Vector2(TILE - 6, TILE - 6)), Color("ffd966"))
	draw_rect(Rect2(p + Vector2(3, 3), Vector2(TILE - 6, TILE - 6)), Color.BLACK, false, 1.0)


## Prints the Vector System worked examples to the Output panel as a smoke test.
func _print_vector_demo() -> void:
	var base := { "heat": 20, "cold": 20, "force": 15, "motion": 15, "binding": 15, "light": 15 }
	var kinetic := VO.normalize_sum(VO.blend([base, { "force": 15, "motion": 15 }]))
	print("Example 1, Kinetic Logician odds: heat %.3f, force %.3f" % [kinetic["heat"], kinetic["force"]])
	var input := { "heat": 12, "force": 4 }
	print("Example 2, complexity %.1f, Searing Edge match %.3f" % [VO.complexity(input), VO.similarity(input, { "heat": 0.7, "force": 0.3 })])
	var wolf := { "weakTo": ["heat"], "strongAgainst": ["cold"] }
	var m: Dictionary = DataDB.table("matchups")
	print("Example 3, Heat vs Frost Wolf %.0f, Cold vs Frost Wolf %.0f" % [VO.contest({ "heat": 20 }, wolf, m), VO.contest({ "cold": 20 }, wolf, m)])
	var rng := Rng.stream("demo")
	print("Seeded level-up roll from Kinetic table: %s" % VO.sample(kinetic, rng, DataDB.table("spaces")["arcane"]["axes"]))

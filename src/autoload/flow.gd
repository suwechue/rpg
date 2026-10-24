## Runs the day: when a part starts, shows the screens it needs (schedule,
## detention, class, the dungeon, night) over whatever scene is open, and owns
## the HUD for free parts. Free-roam scenes (the town) call begin() once and
## set_hud(true). Scenes check is_busy() before taking movement input.
extends CanvasLayer

const ScheduleScreen := preload("res://src/scenes/ui/schedule_screen.gd")
const ClassScreen := preload("res://src/scenes/ui/class_screen.gd")
const NightScreen := preload("res://src/scenes/ui/night_screen.gd")
const EventScreen := preload("res://src/scenes/ui/event_screen.gd")
const Hud := preload("res://src/scenes/ui/hud.gd")

const DUNGEON_SCENE := "res://src/scenes/dungeon/dungeon.tscn"

var _queue: Array = []
var _busy := false
var _hud: Control
var _active := false
var night_hooks: Array = []     # Callables returning [{ "label", "run": Callable }]
var night_line_hooks: Array = []  # Callables returning [String]
var part_hooks: Array = []      # Callables(screens: Array) -> Array, can add screens
var custom_screens: Dictionary = {}  # screen name -> Callable (awaitable)


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud = Hud.new()
	_hud.visible = false
	add_child(_hud)
	EventBus.part_started.connect(_on_part_started)
	EventBus.run_ended.connect(func(_c: String) -> void:
		_active = false
		_queue.clear()
		set_hud(false))


func set_hud(on: bool) -> void:
	_hud.visible = on


func is_busy() -> bool:
	return _busy or DebugMenu.is_open()


## Start running the calendar from the current part (after a new run or a load).
func begin() -> void:
	_active = true
	_on_part_started()


func _on_part_started() -> void:
	if not _active or not GameState.has_run():
		return
	var screens := GameState.part_screens()
	for hook in part_hooks:
		screens = hook.call(screens)
	_queue = screens
	_hud.refresh()
	_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		_hud.refresh()
		return
	_busy = true
	var screen := str(_queue.pop_front())
	match screen:
		"schedule":
			var s := ScheduleScreen.new()
			add_child(s)
			await s.closed
			_next()
		"detention":
			await _detention()
			_next()
		"class":
			var s := ClassScreen.new()
			add_child(s)
			var r: Variant = await s.closed
			if str(r) == "skipped":
				Calendar.set_ap(int(DataDB.table("school_classes").get("rules", {}).get("skipAp", 2)))
				_queue.clear()
				_busy = false
				_hud.refresh()
				EventBus.screen_closed.emit("class")
				return
			_busy = false
			GameState.advance_part()
		"dungeon":
			_busy = false
			enter_dungeon()
		"night":
			var s := NightScreen.new()
			add_child(s)
			await s.closed
			_busy = false
			GameState.advance_part()
		_:
			var custom: Callable = custom_screens.get(screen, Callable())
			if custom.is_valid():
				await custom.call()
			_next()


## Show an event screen and wait for it. Returns the chosen choice.
func show_event(event: Dictionary, extra_ctx: Dictionary = {}) -> Variant:
	var was_busy := _busy
	_busy = true
	var s := EventScreen.new()
	s.event = event
	s.extra_ctx = extra_ctx
	add_child(s)
	var r: Variant = await s.closed
	_busy = was_busy
	_hud.refresh()
	return r


## Show any modal (an instance of src/scenes/ui/modal.gd) and wait for it.
func show_modal(m: Control) -> Variant:
	var was_busy := _busy
	_busy = true
	add_child(m)
	if m.has_method("focus_first"):
		m.call("focus_first")
	var r: Variant = await m.closed
	_busy = was_busy
	_hud.refresh()
	return r


func _detention() -> void:
	GameState.run["detention_pending"] = false
	GameState.run["detentions"] = int(GameState.run.get("detentions", 0)) + 1
	var pick: Dictionary = {}
	for e in DataDB.table("events/detention").get("events", []):
		if GameState.conditions_met(e.get("cond", {})):
			pick = e
	if not pick.is_empty():
		await show_event(pick)
	Calendar.set_ap(0)
	Narrator.say("Detention ate your afternoon. The clock in Mr. B's office runs slow on purpose.")


## The evening Upside-Down. Until the dungeon scene exists, it is skipped.
func enter_dungeon() -> void:
	if ResourceLoader.exists(DUNGEON_SCENE):
		set_hud(false)
		SceneRouter.goto(DUNGEON_SCENE)
		return
	Narrator.say("The spark tugs at you at dusk... and lets go. (The Upside-Down opens in a later build.)")
	GameState.advance_part()


func end_part() -> void:
	if is_busy():
		return
	GameState.advance_part()


func night_lines() -> Array:
	var out: Array = []
	for h in night_line_hooks:
		out.append_array(h.call())
	return out


func night_extras() -> Array:
	var out: Array = []
	for h in night_hooks:
		out.append_array(h.call())
	return out


func run_night_extra(e: Dictionary) -> void:
	var cb: Callable = e["run"]
	await cb.call()

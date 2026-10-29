## The free-roam HUD: time, AP, money, HP/MP on top; the narrator's last line
## at the bottom; End part and Character buttons. Display only.
extends Control

const Char := preload("res://src/core/character.gd")

var _phone: Button
var _top: Label
var _line: Label
var _end: Button
var _strip: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2(0, 0)
	bar.custom_minimum_size = Vector2(Display.base.x, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bar)
	var h := HBoxContainer.new()
	bar.add_child(h)
	_top = UiTheme.label("")
	_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_top)
	_end = UiTheme.button(Strings.t("hud.end_part_space"), func() -> void: Flow.end_part())
	_phone = UiTheme.button(Strings.t("phone.button"), func() -> void:
		if not Flow.is_busy():
			Flow.show_modal(preload("res://src/scenes/ui/phone_screen.gd").new()))
	h.add_child(_phone)
	h.add_child(_end)
	var bottom := PanelContainer.new()
	bottom.position = Vector2(0, Display.base.y - 26)
	bottom.custom_minimum_size = Vector2(Display.base.x, 26)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	_line = UiTheme.label("")
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(Display.base.x - 10, 0)
	bottom.add_child(_line)
	# Effects strip (P2 2.1): what's active today, on the left edge.
	_strip = preload("res://src/scenes/ui/effects_strip.gd").new()
	_strip.position = Vector2(2, 24)
	add_child(_strip)
	EventBus.ap_changed.connect(func(_a: int) -> void: refresh())
	EventBus.money_changed.connect(func(_m: int) -> void: refresh())
	EventBus.stats_changed.connect(func(_id: String) -> void: refresh())
	EventBus.day_part_changed.connect(func(_w: int, _d: String, _p: String) -> void: refresh())
	Narrator.line_said.connect(func(_t: String) -> void: refresh())
	refresh()


func refresh() -> void:
	if _strip != null:
		_strip.refresh()
	if _top == null or not GameState.has_run():
		return
	var p: Dictionary = GameState.player
	var d := Char.derived(DataDB.all(), p)
	_top.text = Strings.t("hud.ap_hp_mp") % [Calendar.label(), Calendar.ap(), Calendar.max_ap(), GameState.money,
		int(p.get("hp", 0)), int(d["maxHp"]), int(p.get("mp", 0)), int(d["maxMp"])]
	_line.text = Narrator.last_line
	_end.disabled = Flow.is_busy()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("end_part") and not Flow.is_busy():
		Flow.end_part()
		get_viewport().set_input_as_handled()

## Base for full-screen modal panels shown by Flow: a dimmed backdrop, a
## centered panel with a title and a body VBox. Emits `closed` with a result.
extends Control

signal closed(result: Variant)

var panel: PanelContainer
var body: VBoxContainer
var title_label: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func build(title: String, width: float = 380.0) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.position = Vector2((Display.base.x - width) / 2.0, 14)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width - 8, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	title_label = UiTheme.label(title, UiTheme.ACCENT)
	body.add_child(title_label)
	resized.connect(_fit)
	_fit.call_deferred()


## Keep the panel inside the screen, leaving room for the HUD bars.
func _fit() -> void:
	if panel == null:
		return
	var scroll: ScrollContainer = panel.get_child(0)
	var want := body.get_combined_minimum_size().y + 8
	scroll.custom_minimum_size.y = minf(want, Display.base.y - 34.0)
	panel.size = Vector2(panel.custom_minimum_size.x, 0)
	panel.position.y = maxf(6.0, (Display.base.y - panel.get_combined_minimum_size().y) / 2.0)


func clear_body() -> void:
	for c in body.get_children():
		if c != title_label:
			c.queue_free()


func text(t: String, color: Variant = null) -> Label:
	var l := UiTheme.label(t, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(panel.custom_minimum_size.x - 2 * UiTheme.FONT_SIZE, 0)
	body.add_child(l)
	_fit.call_deferred()
	return l


func add_button(t: String, cb: Callable, disabled: bool = false, tip: String = "", item_id: String = "") -> Button:
	var b := UiTheme.button(t, cb)
	b.disabled = disabled
	b.tooltip_text = tip
	b.icon = UiTheme.item_icon(item_id)
	# Item icons share one width (skill-frame icons are bigger than item sprites).
	b.add_theme_constant_override("icon_max_width", Display.tile / 2)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.add_child(b)
	_fit.call_deferred()
	return b


func row() -> HBoxContainer:
	var r := HBoxContainer.new()
	body.add_child(r)
	return r


func finish(result: Variant = null) -> void:
	closed.emit(result)
	queue_free()


## Focus the first enabled button so keyboard and controller work.
func focus_first() -> void:
	await get_tree().process_frame
	for c in body.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and not b.disabled and b.is_visible_in_tree():
			b.grab_focus()
			return

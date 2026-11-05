## The Levers panel: every lever with its value for the chosen preset. Used on
## the Lab screen and from F1 mid-fight. `changed(key, value)` fires for each edit.
extends VBoxContainer

signal changed(key: String, value: Variant)

const Rules := preload("res://src/core/combat/rules.gd")

var _values: Dictionary = {}
var _base: Dictionary = {}


func show_levers(values: Dictionary, base: Dictionary) -> void:
	_values = values
	_base = base
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var group := ""
	for s in Rules.lever_specs(DataDB.all()):
		var spec: Dictionary = s
		if str(spec["group"]) != group:
			group = str(spec["group"])
			add_child(UiTheme.label(Strings.t("lab.group_" + group), UiTheme.ACCENT))
		add_child(_row(spec))


func _row(spec: Dictionary) -> Control:
	var key := str(spec["id"])
	var row := HBoxContainer.new()
	row.tooltip_text = str(spec.get("hint", ""))
	var val: Variant = _values.get(key, spec["default"])
	var name_label := UiTheme.label(str(spec.get("name", key)), UiTheme.GOOD if val != _base.get(key) else null)
	name_label.custom_minimum_size = Vector2(UiTheme.FONT_SIZE * 13, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_label)
	match str(spec["type"]):
		"bool":
			row.add_child(UiTheme.button(Strings.t("lab.on") if bool(val) else Strings.t("lab.off"), func() -> void: _edit(key, not bool(val))))
		"enum":
			row.add_child(UiTheme.button(str(val) if str(val) != "" else Strings.t("lab.blank"), func() -> void:
				var opts: Array = spec.get("options", [])
				_edit(key, opts[(opts.find(str(val)) + 1) % opts.size()])))
		_:
			var step: float = float(spec.get("step", 1))
			var whole: bool = str(spec["type"]) == "int"
			var nudge := func(by: float) -> void:
				var next: float = clampf(float(val) + by, float(spec.get("min", -99)), float(spec.get("max", 99)))
				_edit(key, int(next) if whole else snappedf(next, 0.01))
			row.add_child(UiTheme.button("-", func() -> void: nudge.call(-step)))
			row.add_child(UiTheme.label(str(int(val)) if whole else str(snappedf(float(val), 0.01))))
			row.add_child(UiTheme.button("+", func() -> void: nudge.call(step)))
	return row


func _edit(key: String, value: Variant) -> void:
	_values[key] = value
	changed.emit(key, value)
	show_levers(_values, _base)

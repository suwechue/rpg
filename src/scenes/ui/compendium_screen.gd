## The Vector Compendium (docs/VECTORS_DEMO.md Part 2): a grid of the base
## Vector pairs. Discovered combos (this run or any earlier one, from the
## Journal) show their name and effect; the rest show "???" and a vague hint.
extends "res://src/scenes/ui/modal.gd"

const Combos := preload("res://src/core/combos.gd")


func _ready() -> void:
	build(Strings.t("combo.compendium"), 600)
	var db: Dictionary = DataDB.all()
	var axes: Array = Combos.cfg(db).get("axes", [])
	var found := 0
	var found_pairs := 0
	var pairs := 0
	for c in Combos.all(db):
		var seen := Combos.discovered(GameState.run if GameState.has_run() else {}, Journal.data, str(c.get("id", "")))
		if seen:
			found += 1
		if c.get("vectors", []).size() == 2:
			pairs += 1
			if seen:
				found_pairs += 1
	text(Strings.t("combo.count") % [found, Combos.all(db).size(), found_pairs, pairs], UiTheme.ACCENT)
	var grid := GridContainer.new()
	grid.columns = axes.size() + 1
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	body.add_child(grid)
	grid.add_child(UiTheme.label(""))
	for a in axes:
		grid.add_child(_axis_label(str(a)))
	for i in axes.size():
		grid.add_child(_axis_label(str(axes[i])))
		for j in axes.size():
			if j <= i:
				grid.add_child(UiTheme.label("", UiTheme.DIM))
				continue
			grid.add_child(_cell(Combos.for_pair(db, str(axes[i]), str(axes[j]))))
	text(Strings.t("combo.triples"), UiTheme.ACCENT)
	var tr := HFlowContainer.new()
	body.add_child(tr)
	for c in Combos.all(db):
		if c.get("vectors", []).size() == 3:
			tr.add_child(_cell(c))
	add_button(Strings.t("combo.close"), func() -> void: finish(null))
	focus_first()


func _axis_label(axis: String) -> Label:
	var l := UiTheme.label(str(DataDB.table("vectors").get("display", {}).get(axis, axis.capitalize())), UiTheme.vector_color(axis))
	l.custom_minimum_size = Vector2(76, 0)
	return l


## One combo: its name and effect when discovered, "???" and a hint if not.
func _cell(c: Dictionary) -> Label:
	if c.is_empty():
		return UiTheme.label("-", UiTheme.DIM)
	var seen := Combos.discovered(GameState.run if GameState.has_run() else {}, Journal.data, str(c.get("id", "")))
	var l := UiTheme.label(str(c.get("name", "")) if seen else Strings.t("combo.unknown"), UiTheme.vector_color(str(c["vectors"][0])) if seen else UiTheme.DIM)
	l.custom_minimum_size = Vector2(76, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.tooltip_text = (str(c.get("description", "")) if seen else str(c.get("hint", "")))
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l

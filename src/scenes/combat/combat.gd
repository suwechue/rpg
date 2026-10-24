## The combat scene: shows a CombatState in 2.5D and forwards input to it.
## Reads its setup from GameState.pending_combat; when the fight ends it hands
## the summary to GameState.finish_combat() and returns to the previous scene.
## Controls: click (or arrows + E) to move and target, 1-7 pick a card,
## S Strike, G Guard, V Vector Wheel, F Flee, Space end turn, Esc cancel.
extends Node2D

const StateScript := preload("res://src/core/combat/combat_state.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const CardRules := preload("res://src/core/card.gd")
const Proj := preload("res://src/scenes/combat/grid_projection.gd")
const FieldScript := preload("res://src/scenes/combat/combat_field.gd")
const UnitView := preload("res://src/scenes/combat/unit_view.gd")
const Res := preload("res://src/core/combat/resolver.gd")

const CARD_W := 54
const CARD_H := 60

var state: StateScript
var proj: Proj
var field: FieldScript
var views: Dictionary = {}
var walls: Array = []
var mode := "idle"
var selected_hand := -1
var hover_cell := Vector2i(-1, -1)
var cursor_cell := Vector2i(-1, -1)
var wheel_vectors: Array = []
var wheel_form := ""
var wheel_magnitude := "minor"
var wheel_fuel := -1
var _busy := false
var _done := false
var _log: Array = []

var _ui: CanvasLayer
var _timeline: HBoxContainer
var _unit_panel: Label
var _info: Label
var _banner: Label
var _hand: HBoxContainer
var _buttons: Dictionary = {}
var _wheel: PanelContainer
var _result_panel: PanelContainer
var _fx: Node2D
var _float_slots: Dictionary = {}   # unit view -> floating texts currently shown


func _ready() -> void:
	var setup: Dictionary = GameState.take_pending_combat()
	if setup.is_empty():
		setup = GameState.debug_combat_setup()
	state = StateScript.new(DataDB.all(), Rng.stream("combat"), setup)
	var layout: Dictionary = setup.get("layout", {})
	# Cell sizes are in tiles (data/display.json "combat"); wide or deep layouts get smaller cells.
	var cc: Dictionary = Display.combat
	var t := float(Display.tile)
	var cw := float(cc.get("cellWidth", 1.8)) if state.grid.cols <= 9 else float(cc.get("cellWidthWide", 1.6))
	var ch := float(cc.get("cellHeight", 0.9)) if state.grid.rows <= 5 else float(cc.get("cellHeightTall", 0.78))
	proj = Proj.new(state.grid.cols, state.grid.rows, Display.base.x / 2.0, Display.base.y * float(cc.get("frontY", 0.74)),
		cw * t, ch * t, float(cc.get("shrink", 0.9)))
	field = FieldScript.new()
	field.proj = proj
	field.grid = state.grid
	field.theme_rec = DataDB.record("rooms/themes", str(layout.get("theme", "school")))
	add_child(field)
	_make_walls()
	_fx = Node2D.new()
	_fx.z_index = 200
	add_child(_fx)
	_build_ui()
	_sync_views()
	_play_events()
	if setup.has("intro"):
		_say_banner(str(setup["intro"]))
	Audio.play_music("battle_boss" if state.boss_fight else "battle")


# --- Views ----------------------------------------------------------------------------

class WallView extends Node2D:
	var w := 40.0
	var h := 26.0
	var color := Color("2b2440")

	func _draw() -> void:
		draw_rect(Rect2(-w / 2.0, -h, w, h), color)
		draw_rect(Rect2(-w / 2.0, -h, w, 5), color.lightened(0.25))
		draw_rect(Rect2(-w / 2.0, -h, w, h), color.darkened(0.4), false, 1.0)


func _make_walls() -> void:
	for cell in state.grid.all_cells():
		if state.grid.get_terrain(cell) != "wall":
			continue
		var wv := WallView.new()
		var poly := proj.cell_polygon(cell)
		wv.w = poly[2].x - poly[3].x - 4.0
		wv.h = Display.tile * (0.6 + 0.3 * proj.row_scale(cell.y))
		wv.color = Color(str(field.theme_rec.get("horizon", "#2b2440"))).lightened(0.15)
		wv.position = proj.cell_center(cell) + Vector2(0, (poly[2].y - poly[0].y) / 2.0)
		wv.z_index = 10 + cell.y
		add_child(wv)
		walls.append(wv)


func _view_for(u: UnitScript) -> Node2D:
	if views.has(u):
		return views[u]
	var v := UnitView.new()
	var sprite_id := u.sprite
	if sprite_id == "" and u.team == "party":
		sprite_id = Assets.role("player")
	v.setup(u.id, u.team, sprite_id, u.id if u.is_prop() else "")
	add_child(v)
	views[u] = v
	return v


func _sync_views() -> void:
	for u in state.units:
		if u.dead:
			if views.has(u):
				views[u].queue_free()
				views.erase(u)
			continue
		var v := _view_for(u)
		v.position = proj.cell_center(u.cell)
		v.z_index = 10 + u.cell.y
		v.hp_ratio = u.hp_ratio()
		v.shield = u.shield
		v.downed = u.downed
		v.highlight = u == state.current and not _done
		v.face(u.facing)
		var tags: Array = []
		for s in ["root", "slow", "blind", "haste", "rally"]:
			if u.statuses.has(s):
				tags.append(str(s).substr(0, 2).to_upper())
		if not u.infusion.is_empty():
			tags.append("IN")
		if u.guard_active:
			tags.append("GD")
		v.statuses = tags
		v.queue_redraw()
	var gl: Array = []
	for g in state.glyphs:
		if str(g["team"]) == "party":
			gl.append(g["cell"])
	field.glyph_cells = gl
	_refresh_overlays()
	_refresh_hud()


# --- UI -----------------------------------------------------------------------------------

func _build_ui() -> void:
	var view := Display.size_f()
	var hand_y := view.y - CARD_H - 4
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_timeline = HBoxContainer.new()
	_timeline.position = Vector2(118, 2)
	_timeline.add_theme_constant_override("separation", 1)
	_ui.add_child(_timeline)
	var up := PanelContainer.new()
	up.position = Vector2(2, 2)
	up.custom_minimum_size = Vector2(112, 0)
	_ui.add_child(up)
	_unit_panel = UiTheme.label("")
	up.add_child(_unit_panel)
	var ip := PanelContainer.new()
	ip.position = Vector2(view.x - 128, 24)
	ip.custom_minimum_size = Vector2(126, 0)
	_ui.add_child(ip)
	_info = UiTheme.label("")
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(118, 0)
	ip.add_child(_info)
	_banner = UiTheme.label("", UiTheme.ACCENT)
	_banner.position = Vector2(118, 26)
	_banner.size = Vector2(view.x - 248, 12)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui.add_child(_banner)
	_hand = HBoxContainer.new()
	_hand.position = Vector2(4, hand_y)
	_hand.add_theme_constant_override("separation", 2)
	_ui.add_child(_hand)
	var col := GridContainer.new()
	col.columns = 2
	col.position = Vector2(view.x - 82, hand_y)
	col.add_theme_constant_override("h_separation", 1)
	col.add_theme_constant_override("v_separation", 1)
	_ui.add_child(col)
	for spec in [["end", "End", "End turn [Space]"], ["strike", "Strike", "Free basic Strike: adjacent, STR [S]"],
			["guard", "Guard", "Free basic Guard: +Defense until your next turn [G]"],
			["wheel", "Wheel", "Vector Wheel: improvise a spell [V]"], ["flee", "Flee", "Flee when everyone stands on an exit tile [F]"]]:
		var key: String = spec[0]
		var b := UiTheme.button(spec[1], func() -> void: _on_button(key))
		b.custom_minimum_size = Vector2(39, 18)
		b.tooltip_text = spec[2]
		col.add_child(b)
		_buttons[key] = b


func _refresh_hud() -> void:
	for c in _timeline.get_children():
		c.queue_free()
	for u in state.timeline(14):
		var box := Panel.new()
		box.custom_minimum_size = Vector2(UiTheme.FONT_SIZE * 2, 18)
		var sb := UiTheme.box(Color("2a5a3a") if u.team == "party" else Color("5a2a2a"), Color("ffd966") if u == state.current else Color("101010"))
		box.add_theme_stylebox_override("panel", sb)
		var l := UiTheme.label(u.name.substr(0, 2), UiTheme.TEXT)
		l.position = Vector2(2, 3)
		box.add_child(l)
		box.tooltip_text = "%s (init %d)" % [u.name, u.initiative]
		_timeline.add_child(box)
	var u := state.current
	if u != null:
		var lines: Array = ["%s%s" % [u.name, " (AI)" if u.ai_controlled else ""], "HP %d/%d  MP %d/%d" % [u.hp, u.max_hp, u.mp, u.max_mp]]
		if u.team == "party" and not u.ai_controlled:
			lines.append("Move %d  %s" % [u.move_left, "basic used" if u.free_action_used else "basic ready"])
			if u.deck != null:
				lines.append("Deck %d  Discard %d" % [u.deck.draw_pile.size(), u.deck.discard.size()])
		if u.shield > 0:
			lines.append("Shield %d" % u.shield)
		_unit_panel.text = "\n".join(PackedStringArray(lines))
	_refresh_hand()
	var player_turn := _player_turn()
	_buttons["end"].disabled = not player_turn
	_buttons["strike"].disabled = not player_turn or u.free_action_used
	_buttons["guard"].disabled = not player_turn or u.free_action_used
	_buttons["wheel"].disabled = not player_turn or u.known_vectors.is_empty()
	_buttons["flee"].disabled = not player_turn or not state.can_flee()
	if _info.text == "" or mode == "idle":
		_info.text = "\n".join(PackedStringArray(_log.slice(maxi(0, _log.size() - 5))))


func _refresh_hand() -> void:
	for c in _hand.get_children():
		c.queue_free()
	var u := state.current
	if u == null or u.deck == null or u.team != "party" or u.ai_controlled:
		return
	var db: Dictionary = DataDB.all()
	var colors: Dictionary = db.get("vectors", {}).get("colors", {})
	for i in u.deck.hand.size():
		var card := state.card_of(u, i)
		var b := Button.new()
		b.custom_minimum_size = Vector2(CARD_W, CARD_H)
		b.clip_text = true
		var cost := state.card_cost(u, card)
		var name_text := str(card.get("name", "?")).replace(" ", "\n")
		b.text = "%d MP\n%s" % [cost, name_text]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var tint := Color("3a3550")
		if CardRules.is_spell(card):
			var axis := str(CardRules.ordered_vectors(db, card.get("vectors", {}))[0])
			tint = Color(str(colors.get(axis, "#888888"))).darkened(0.55)
		var sel := (mode == "card" and selected_hand == i) or (mode == "wheel_target" and wheel_fuel == i)
		var sb := UiTheme.box(tint, Color("ffd966") if sel else Color("5a6488"))
		sb.content_margin_left = 3
		sb.content_margin_top = 2
		b.add_theme_stylebox_override("normal", sb)
		var hb := UiTheme.box(tint.lightened(0.15), Color("ffd966"))
		hb.content_margin_left = 3
		hb.content_margin_top = 2
		b.add_theme_stylebox_override("hover", hb)
		b.add_theme_stylebox_override("pressed", hb)
		b.disabled = not _player_turn() or (cost > u.mp and mode != "fuel")
		b.tooltip_text = "%s\n%s" % [card.get("name", ""), CardRules.describe(db, card)]
		var idx := i
		b.pressed.connect(func() -> void: _on_card(idx))
		b.mouse_entered.connect(func() -> void: _show_card_info(idx))
		_hand.add_child(b)


func _show_card_info(i: int) -> void:
	var card := state.card_of(state.current, i)
	if not card.is_empty():
		_info.text = "%s (%d MP)\n%s" % [card.get("name", ""), state.card_cost(state.current, card), CardRules.describe(DataDB.all(), card)]


func _player_turn() -> bool:
	return not _busy and not _done and state.result == "" and state.current != null \
		and state.current.team == "party" and not _is_ai(state.current)


## AI-controlled units, plus the whole party when the --autoplay dev flag is on.
func _is_ai(u: UnitScript) -> bool:
	return u.ai_controlled or (GameState.dev_autoplay and u.team == "party")


# --- Overlays and previews --------------------------------------------------------------------

func _refresh_overlays() -> void:
	field.reach_cells = []
	field.target_cells = []
	field.footprint_cells = []
	field.hover_cell = hover_cell
	field.cursor_cell = cursor_cell
	if _player_turn():
		var u := state.current
		match mode:
			"idle":
				field.reach_cells = state.reachable_cells(u).keys()
			"card":
				var card := state.card_of(u, selected_hand)
				field.target_cells = state.card_targets(u, card)
				_preview(card, false)
			"strike":
				field.target_cells = state._adjacent_hostiles(u, 1)
			"wheel_target":
				var card := _wheel_card()
				field.target_cells = state.card_targets(u, card)
				_preview(card, true)
	field.queue_redraw()


func _preview(card: Dictionary, improvised: bool) -> void:
	var target := hover_cell if hover_cell.x >= 0 else cursor_cell
	if not field.target_cells.has(target):
		return
	var p := state.preview(state.current, card, target, improvised)
	field.footprint_cells = p["cells"]
	field.footprint_heal = CardRules.heals(card)
	var lines: Array = ["%s: %d MP" % [card.get("name", ""), int(p["cost"])]]
	for h in p["hits"]:
		var t := state.unit_by_id(str(h["unit"]))
		var nm: String = t.name if t != null else str(h["unit"])
		if h.has("damage"):
			lines.append("%s -%d" % [nm, int(h["damage"])])
		else:
			lines.append("%s +%d" % [nm, int(h["heal"])])
	lines.append("Stable: %d%%" % roundi(float(p["chance"]) * 100.0))
	_info.text = "\n".join(PackedStringArray(lines))


# --- Input ---------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _done or DebugMenu.is_open():
		return
	if event is InputEventMouseMotion:
		var c := proj.to_cell(get_global_mouse_position())
		if c != hover_cell:
			hover_cell = c
			_refresh_overlays()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var c := proj.to_cell(get_global_mouse_position())
			if c.x >= 0:
				cursor_cell = c
				_click_cell(c)
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
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
		if cursor_cell.x < 0 and state.current != null:
			cursor_cell = state.current.cell
		cursor_cell = Vector2i(clampi(cursor_cell.x + dir.x, 0, state.grid.cols - 1), clampi(cursor_cell.y + dir.y, 0, state.grid.rows - 1))
		hover_cell = cursor_cell
		_refresh_overlays()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and cursor_cell.x >= 0:
		_click_cell(cursor_cell)
	elif event.is_action_pressed("end_part"):
		_on_button("end")
	elif event.is_action_pressed("cancel"):
		_cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_7:
			_on_card(k - KEY_1)
		elif k == KEY_S:
			_on_button("strike")
		elif k == KEY_G:
			_on_button("guard")
		elif k == KEY_V:
			_on_button("wheel")
		elif k == KEY_F:
			_on_button("flee")


func _cancel() -> void:
	mode = "idle"
	selected_hand = -1
	wheel_fuel = -1
	if _wheel != null:
		_wheel.queue_free()
		_wheel = null
	_refresh_overlays()
	_refresh_hud()


func _on_card(i: int) -> void:
	if not _player_turn():
		return
	var u := state.current
	if u.deck == null or i < 0 or i >= u.deck.hand.size():
		return
	if mode == "fuel":
		wheel_fuel = i
		mode = "wheel_target"
		_info.text = "Aim the improvised spell. Burning %s as fuel." % state.card_of(u, i).get("name", "")
		_refresh_overlays()
		_refresh_hud()
		return
	var card := state.card_of(u, i)
	if state.card_cost(u, card) > u.mp:
		_note("Not enough MP for %s." % card.get("name", ""))
		return
	mode = "card"
	selected_hand = i
	var targets := state.card_targets(u, card)
	if targets.size() == 1 and targets[0] == u.cell:
		_click_cell(u.cell)
		return
	_refresh_overlays()
	_refresh_hud()


func _on_button(key: String) -> void:
	if not _player_turn():
		return
	var u := state.current
	match key:
		"end":
			_cancel()
			state.end_turn()
			_after_action()
		"strike":
			if not u.free_action_used:
				mode = "strike"
				_refresh_overlays()
		"guard":
			if state.guard(u):
				_after_action()
		"wheel":
			_open_wheel()
		"flee":
			if state.flee():
				_after_action()


func _click_cell(c: Vector2i) -> void:
	if not _player_turn():
		return
	var u := state.current
	match mode:
		"idle":
			if state.reachable_cells(u).has(c):
				state.move(u, c)
				_after_action()
		"card":
			if state.play_card(u, selected_hand, c):
				mode = "idle"
				selected_hand = -1
				_after_action()
		"strike":
			if state.strike(u, c):
				mode = "idle"
				_after_action()
		"wheel_target":
			if state.improvise(u, wheel_vectors, wheel_form, wheel_magnitude, wheel_fuel, c):
				mode = "idle"
				wheel_fuel = -1
				_after_action()


func _after_action() -> void:
	await _play_events()
	_sync_views()


# --- Vector Wheel ------------------------------------------------------------------------------

func _wheel_card() -> Dictionary:
	if wheel_vectors.is_empty() or wheel_form == "":
		return {}
	var v := {}
	for a in wheel_vectors:
		v[a] = 1.0
	return CardRules.make_spell(DataDB.all(), v, wheel_form, wheel_magnitude)


func _open_wheel() -> void:
	if _wheel != null:
		_wheel.queue_free()
	var u := state.current
	if wheel_form == "" or not u.known_forms.has(wheel_form):
		wheel_form = str(u.known_forms[0]) if not u.known_forms.is_empty() else ""
	wheel_vectors = wheel_vectors.filter(func(a: Variant) -> bool: return u.known_vectors.has(a))
	if wheel_vectors.is_empty() and not u.known_vectors.is_empty():
		wheel_vectors = [u.known_vectors[0]]
	_wheel = PanelContainer.new()
	_wheel.position = Vector2((Display.base.x - 260) / 2.0, 60)
	_wheel.custom_minimum_size = Vector2(260, 0)
	_ui.add_child(_wheel)
	var box := VBoxContainer.new()
	_wheel.add_child(box)
	box.add_child(UiTheme.label("Vector Wheel: improvise a spell", UiTheme.ACCENT))
	var db: Dictionary = DataDB.all()
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(UiTheme.label("Vectors:"))
	for axis in u.known_vectors:
		var a := str(axis)
		var b := UiTheme.button(("[%s]" if wheel_vectors.has(a) else "%s") % a.capitalize(), func() -> void:
			if wheel_vectors.has(a):
				if wheel_vectors.size() > 1:
					wheel_vectors.erase(a)
			elif wheel_vectors.size() < 2:
				wheel_vectors.append(a)
			else:
				wheel_vectors = [wheel_vectors[1], a]
			_open_wheel())
		row.add_child(b)
	var frow := HFlowContainer.new()
	frow.custom_minimum_size = Vector2(250, 0)
	box.add_child(frow)
	frow.add_child(UiTheme.label("Form:"))
	for f in u.known_forms:
		var fid := str(f)
		frow.add_child(UiTheme.button(("[%s]" if wheel_form == fid else "%s") % str(DataDB.record("forms", fid).get("name", fid)), func() -> void:
			wheel_form = fid
			_open_wheel()))
	var mrow := HBoxContainer.new()
	box.add_child(mrow)
	mrow.add_child(UiTheme.label("Magnitude:"))
	var cap := CardRules.magnitude_index(db, CardRules.max_magnitude(db, u.knowledge_tier))
	if CardRules.magnitude_index(db, wheel_magnitude) > cap:
		wheel_magnitude = "minor"
	for m in db.get("vectors", {}).get("magnitudeOrder", []):
		var mid := str(m)
		if CardRules.magnitude_index(db, mid) > cap:
			continue
		mrow.add_child(UiTheme.button(("[%s]" if wheel_magnitude == mid else "%s") % mid.capitalize(), func() -> void:
			wheel_magnitude = mid
			_open_wheel()))
	var card := _wheel_card()
	var err := state.improvise_error(u, wheel_vectors, wheel_form, wheel_magnitude)
	if not card.is_empty():
		var cost := state.improvise_cost(u, card)
		box.add_child(UiTheme.label("%s: %d MP + 1 card as fuel. Stable %d%%." % [card["name"], cost,
			roundi(Res.stability_chance(db, u.stability, cost, u.mp, true) * 100.0)]))
	if err != "":
		box.add_child(UiTheme.label(err, UiTheme.BAD))
	var brow := HBoxContainer.new()
	box.add_child(brow)
	var aim := UiTheme.button("Pick fuel card, then aim", func() -> void:
		_wheel.queue_free()
		_wheel = null
		mode = "fuel"
		_info.text = "Click a card in your hand to burn as fuel."
		_refresh_hud())
	aim.disabled = err != ""
	brow.add_child(aim)
	brow.add_child(UiTheme.button("Close", _cancel))


# --- Events ---------------------------------------------------------------------------------------

func _play_events() -> void:
	_busy = true
	var evs := state.take_events()
	for e in evs:
		await _play_event(e)
	_busy = false
	_sync_views()
	if state.result != "" and not _done:
		_finish()
		return
	if state.current != null and _is_ai(state.current) and state.result == "":
		_run_ai.call_deferred()


func _run_ai() -> void:
	if _busy or _done or state.result != "" or state.current == null or not _is_ai(state.current):
		return
	_busy = true
	_sync_views()
	await get_tree().create_timer(0.35).timeout
	AI.take_turn(state, state.current)
	_busy = false
	await _play_events()


func _unit_view(id: String) -> Node2D:
	var u := state.unit_by_id(id)
	if u == null:
		for x in state.units:
			if x.id == id:
				u = x
	return views.get(u, null)


func _play_event(e: Dictionary) -> void:
	match str(e["t"]):
		"turn":
			var u := state.unit_by_id(str(e["unit"]))
			if u != null:
				_note("%s's turn." % u.name)
				if u.team == "party" and not u.ai_controlled:
					cursor_cell = u.cell
			_sync_views()
		"move":
			var v := _view_for_id(str(e["unit"]))
			if v == null:
				return
			for cell in e["path"]:
				var tw := create_tween()
				tw.tween_property(v, "position", proj.cell_center(cell), 0.09)
				v.z_index = 10 + int(cell.y)
				v.walk_tick(0.09)
				await tw.finished
			v.stop_walk()
		"push":
			var v := _view_for_id(str(e["unit"]))
			if v != null:
				var tw := create_tween()
				tw.tween_property(v, "position", proj.cell_center(e["to"]), 0.12)
				v.z_index = 10 + int(e["to"].y)
				await tw.finished
		"cast":
			var u := state.unit_by_id(str(e["unit"]))
			_say_banner("%s: %s" % [u.name if u != null else "?", e["name"]])
			Audio.play_sfx("cast")
			await get_tree().create_timer(0.25).timeout
		"area":
			field.flash_cells = e["cells"]
			var colors: Dictionary = DataDB.table("vectors").get("colors", {})
			var axis := ""
			for k in e["vectors"]:
				axis = str(k)
			var c := Color(str(colors.get(axis, "#ffffff")))
			c.a = 0.5
			field.flash_color = c
			field.queue_redraw()
			await get_tree().create_timer(0.18).timeout
			field.flash_cells = []
			field.queue_redraw()
		"damage":
			var v := _view_for_id(str(e["unit"]))
			var amt := int(e["amount"])
			var txt := "-%d" % amt
			if int(e.get("absorbed", 0)) > 0:
				txt += " (%d)" % int(e["absorbed"])
			if bool(e.get("crit", false)):
				txt += "!"
			_float_text(v, txt, Color("ff7a6a") if not bool(e.get("crit", false)) else Color("ffd966"))
			Audio.play_sfx("hit")
			if v != null:
				var tw := create_tween()
				v.modulate = Color(2, 2, 2)
				tw.tween_property(v, "modulate", Color.WHITE, 0.15)
			if amt >= 10 or bool(e.get("crit", false)):
				await _shake(3.0)
			else:
				await get_tree().create_timer(0.12).timeout
		"heal":
			_float_text(_view_for_id(str(e["unit"])), "+%d%s" % [int(e["amount"]), " up!" if bool(e.get("revived", false)) else ""], Color("8fd694"))
			Audio.play_sfx("heal")
			await get_tree().create_timer(0.12).timeout
		"shield":
			_float_text(_view_for_id(str(e["unit"])), "+%d shield" % int(e["amount"]), Color("7cc7e8"))
		"status":
			_float_text(_view_for_id(str(e["unit"])), str(e["status"]), Color("f5e27a"))
		"guard":
			_float_text(_view_for_id(str(e["unit"])), "guard", Color("c9c9c9"))
		"miss":
			_float_text(_view_for_id(str(e["unit"])), "miss", Color("c9c9c9"))
		"collide":
			await _shake(2.0)
		"down":
			var u := state.unit_by_id(str(e["unit"]))
			_note("%s is down!" % (u.name if u != null else "?"))
		"death", "vanish":
			var u: UnitScript = null
			for x in state.units:
				if x.id == str(e["unit"]) and x.dead and views.has(x):
					u = x
			if u != null:
				var v: Node2D = views[u]
				var tw := create_tween()
				tw.tween_property(v, "modulate", Color(1, 1, 1, 0), 0.25)
				await tw.finished
				v.queue_free()
				views.erase(u)
		"spawn":
			_sync_views()
		"say":
			var u := state.unit_by_id(str(e["unit"]))
			_say_banner("%s: \"%s\"" % [u.name if u != null else "?", e["text"]])
			_note("%s: %s" % [u.name if u != null else "?", e["text"]])
			await get_tree().create_timer(0.9).timeout
		"instability":
			_say_banner(str(e["text"]))
			_note(str(e["text"]))
			Audio.play_sfx("fail")
			await _shake(2.0)
		"phase":
			_say_banner(str(e["text"]))
			_note(str(e["text"]))
			await _shake(4.0)
			await get_tree().create_timer(0.6).timeout
		"log":
			_note(str(e["text"]))
		"glyph":
			_note("A glyph flares!")
		"tiles":
			field.queue_redraw()
		"end":
			pass


func _view_for_id(id: String) -> Node2D:
	for u in views:
		if u.id == id and not u.dead:
			return views[u]
	return null


func _float_text(v: Node2D, text: String, color: Color) -> void:
	if v == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	# Texts on the same unit at the same time stack upward instead of overlapping.
	var slot := int(_float_slots.get(v, 0))
	_float_slots[v] = slot + 1
	l.position = v.position + Vector2(-10, -v.sprite_height() - UiTheme.FONT_SIZE - 7 - 10 * slot)
	_fx.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 12, 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.tween_callback(func() -> void:
		l.queue_free()
		if is_instance_valid(v) and _float_slots.has(v):
			_float_slots[v] = maxi(0, int(_float_slots[v]) - 1))


func _shake(amount: float) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "position", Vector2(randf_range_seeded(amount), randf_range_seeded(amount)), 0.03)
	tw.tween_property(self, "position", Vector2.ZERO, 0.03)
	await tw.finished


## Screen shake offsets are cosmetic, but still come from a seeded stream.
func randf_range_seeded(amount: float) -> float:
	return Rng.stream("fx").randf_range(-amount, amount)


func _say_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


func _note(text: String) -> void:
	_log.append(text)
	if _log.size() > 30:
		_log.remove_at(0)
	if mode == "idle":
		_info.text = "\n".join(PackedStringArray(_log.slice(maxi(0, _log.size() - 5))))


# --- End -------------------------------------------------------------------------------------------

func _finish() -> void:
	_done = true
	_sync_views()
	var summary := state.finish()
	var result := str(summary["result"])
	var outcome: Dictionary = GameState.finish_combat(summary)
	_result_panel = PanelContainer.new()
	_result_panel.position = Vector2((Display.base.x - 240) / 2.0, 70)
	_result_panel.custom_minimum_size = Vector2(240, 0)
	_ui.add_child(_result_panel)
	var box := VBoxContainer.new()
	_result_panel.add_child(box)
	var title := str({ "win": "Victory", "flee": "You got away", "lose": "You fell" }.get(result, result))
	box.add_child(UiTheme.label(title, UiTheme.ACCENT, UiTheme.TITLE_SIZE))
	for line in outcome.get("lines", []):
		var l := UiTheme.label(str(line))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(230, 0)
		box.add_child(l)
	var cont := UiTheme.button("Continue", func() -> void: GameState.leave_combat())
	box.add_child(cont)
	cont.grab_focus()
	if GameState.dev_autoplay:
		print("[autoplay] combat result: %s, xp %d, rounds %d" % [result, int(summary["xp"]), int(summary["rounds"])])
	Audio.play_sfx("win" if result == "win" else "lose")

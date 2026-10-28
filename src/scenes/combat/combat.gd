## The combat scene: shows a CombatState in 2.5D and forwards input to it.
## Reads its setup from GameState.pending_combat; when the fight ends it hands
## the summary to GameState.finish_combat() and returns to the previous scene.
## Controls: click (or arrows + E) to move and target, 1-7 pick a card,
## Q / Tab (pad LB / RB) highlight cards to preview them, S Strike, G Guard,
## V Vector Wheel, F Flee, Space end turn, Esc cancel (or undo the move),
## hold Shift (pad X) to fast-forward enemy turns.
## Each turn is Move + 1 Action (CU, docs/COMBAT_REWORK.md); the player's turn
## is a small state machine: idle -> card selected -> target hovered -> confirm.
extends Node2D

const GridScript := preload("res://src/core/combat/grid.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")
const UnitScript := preload("res://src/core/combat/unit.gd")
const AI := preload("res://src/core/combat/enemy_ai.gd")
const CardRules := preload("res://src/core/card.gd")
const Proj := preload("res://src/scenes/combat/grid_projection.gd")
const FieldScript := preload("res://src/scenes/combat/combat_field.gd")
const UnitView := preload("res://src/scenes/combat/unit_view.gd")
const Res := preload("res://src/core/combat/resolver.gd")

const CardView := preload("res://src/scenes/combat/card_view.gd")

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
var _banner_face: Control
var _hand_owner: Label
var _pips: HBoxContainer
const Tutorial := preload("res://src/core/story/tutorial.gd")
var _lesson: Tutorial.Lesson = null    # CT Part 7: the tutorial room's lesson, or null
var _lesson_box: PanelContainer
var _lesson_label: Label
var _lesson_next: Button
var _lesson_mark: ReferenceRect
var _ui_open: Dictionary = { "hand": true, "wheel": true, "threat": true }
var _mocked := false
var _stayed_in_red := ""
const ShapeDiagram := preload("res://src/scenes/ui/shape_diagram.gd")
const PartyPanel := preload("res://src/scenes/ui/party_panel.gd")
const Modal := preload("res://src/scenes/ui/modal.gd")
var _tele_since: Dictionary = {}      # enemy id + plan -> when its telegraph first showed (for the pulse)
var _hover_shapes: HBoxContainer
var _quick_box: VBoxContainer
var _hand: HBoxContainer
var _buttons: Dictionary = {}
var _wheel: PanelContainer
var _result_panel: PanelContainer
var _fx: Node2D
var _float_slots: Dictionary = {}   # unit view -> floating texts currently shown
var _hover_info: PanelContainer
var _hover_label: Label
var _hover_card := -1                # card in hand under the mouse: preview without selecting
var _focus_card := -1                # card highlighted with the keyboard or pad (card_prev / card_next)
var _log_scroll: ScrollContainer
var _log_box: VBoxContainer
var _last_turn_team := ""


func _process(_delta: float) -> void:
	# Hold the threat view key to shade every tile by the damage waiting there.
	var tv := Input.is_action_pressed("threat_view") and bool(_ui_open.get("threat", true))
	_tick_lesson(_delta_hint())
	if field != null and tv != field.threat_view:
		field.threat_view = tv
		field.queue_redraw()


func _ready() -> void:
	var setup: Dictionary = GameState.take_pending_combat()
	if setup.is_empty():
		setup = GameState.debug_combat_setup()
	if GameState.combat_turn_mode != "" and not setup.has("turnMode"):
		setup["turnMode"] = GameState.combat_turn_mode
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
	_start_lesson(setup)
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
		v.active = v.highlight
		v.spotlight = state.current != null and u != state.current and not _done
		v.acted = state.acted_this_round(u) and not _done
		v.covered = _covered(u)
		v.tag = state.dup_index(u)
		v.max_hp = u.max_hp
		v.bleed = u.bleed
		v.fade = _fade_for(u)
		var hov := state.unit_at(hover_cell)
		var red_here: Array = state.threats().get(hover_cell, []).map(func(h: Dictionary) -> String: return str(h["unit"]))
		v.focus = red_here.has(u.id) and (hov == null or hov != u)
		v.face(u.facing)
		v.statuses = state.status_list(u)
		v.intent_icon = _intent_icon(u)
		v.affixes = u.source.get("affixes", [])
		v.burrowed = u.statuses.has("burrowed")
		v.charge = int(u.intent.get("charge", 0))
		v.friend_link = false
		if u.team == "party" and u.alive():
			for a in state.allies_of(u):
				if a != u and GridScript.manhattan(a.cell, u.cell) == 1 and state._bond_friendly(u, a):
					v.friend_link = true
		v.queue_redraw()
	var gl: Array = []
	for g in state.glyphs:
		# Your glyphs and the arena's traps are visible; enemy glyphs stay hidden.
		if str(g["team"]) == "party" or str(g["team"]) == "trap":
			gl.append(g["cell"])
	field.glyph_cells = gl
	var threats := {}
	var all := state.threats()
	for c in all:
		var total := 0
		var charge := 0
		for h in all[c]:
			total += int(h["damage"])
			charge = maxi(charge, int(h["charge"]))
		threats[c] = { "damage": total, "charge": charge }
	field.threat_cells = threats
	field.support_cells = state.support_cells()
	var marks: Array = []
	for u in state.units:
		if u.team == "enemy" and u.alive() and not u.intent.is_empty() and u.intent.get("move", u.cell) != u.cell:
			marks.append({ "from": u.cell, "to": u.intent["move"] })
	field.move_marks = marks
	var tele: Array = []
	var hue := 0
	for u in state.units:
		if u.team != "enemy" or not u.alive() or u.intent.is_empty():
			continue
		var cells := state.intent_cells(u)
		if cells.is_empty():
			continue
		var key := "%s:%s" % [u.id, str(cells)]
		if not _tele_since.has(key):
			_tele_since[key] = field._time
		var tint := UiTheme.color("bad")
		tint.h = fposmod(tint.h + 0.04 * float(hue % 4) - 0.06, 1.0)
		hue += 1
		var badge := ""
		if u.statuses.has("blind"):
			badge = Strings.t("combat.miss_badge") % roundi(100.0 * float(DataDB.table("stats").get("combat", {}).get("blindMissChance", 0.35)))
		var aimed := state.unit_by_id(str(u.intent.get("unit", "")))
		if str(u.intent.get("mode", "")) == "tracking" and aimed != null and state.decoy_for(aimed) != null:
			badge = Strings.t("combat.to_decoy")
		tele.append({ "unit": u.id, "from": u.intent.get("move", u.cell), "cells": cells, "tag": state.dup_index(u), "tint": tint, "since": _tele_since[key], "badge": badge })
	field.telegraphs = tele
	var ling := {}
	for c in state.grid.burning:
		ling[c] = int(state.grid.burning[c])
	for c in state.grid.toxic:
		ling[c] = int(state.grid.toxic[c])
	for g in state.glyphs:
		if str(g["team"]) == "party":
			ling[g["cell"]] = int(g["turns"])
	for c in ling.keys():
		if int(ling[c]) >= 99:
			ling.erase(c)
	field.lingering = ling
	_refresh_overlays()
	_refresh_hud()


func _intent_icon(u: UnitScript) -> String:
	if u.team != "enemy" or u.intent.is_empty() or not u.alive():
		return ""
	var icons: Dictionary = DataDB.table("ui").get("intentIcons", {})
	var kind := str(u.intent.get("kind", ""))
	if str(u.intent.get("mode", "")) == "tracking" and kind == "attack":
		kind = "tracking"
	return str(icons.get(kind, ""))


# --- UI -----------------------------------------------------------------------------------

func _build_ui() -> void:
	var view := Display.size_f()
	var card_h := Assets.texture(str(UiTheme.skin("cards").get("spell", ""))).get_height()
	var hand_y := view.y - card_h - 4
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_timeline = HBoxContainer.new()
	_timeline.position = Vector2(118, 2)
	_timeline.theme_type_variation = "CompactBox"
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
	_banner_face = Control.new()
	_banner_face.position = Vector2(118, 22)
	_banner_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_banner_face)
	# Two Action pips and one Quick pip for the active unit (PT Part 1).
	_pips = HBoxContainer.new()
	_pips.theme_type_variation = "CompactBox"
	_pips.position = Vector2(view.x - 82, hand_y - 8)
	for i in 3:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(6, 6) if i < 2 else Vector2(4, 6)
		pip.tooltip_text = Strings.t("combat.uses_action") if i < 2 else Strings.t("combat.uses_quick")
		_pips.add_child(pip)
	_ui.add_child(_pips)
	_lesson_box = PanelContainer.new()
	_lesson_box.position = Vector2(118, 40)
	_lesson_box.custom_minimum_size = Vector2(view.x - 248, 0)
	_lesson_box.visible = false
	var lb := VBoxContainer.new()
	_lesson_box.add_child(lb)
	_lesson_label = UiTheme.label("")
	_lesson_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lesson_label.custom_minimum_size = Vector2(view.x - 260, 0)
	lb.add_child(_lesson_label)
	_lesson_next = UiTheme.button(Strings.t("combat.lesson_next"), func() -> void: _lesson_event("next"))
	lb.add_child(_lesson_next)
	_ui.add_child(_lesson_box)
	_lesson_mark = ReferenceRect.new()
	_lesson_mark.editor_only = false
	_lesson_mark.border_color = UiTheme.ACCENT
	_lesson_mark.border_width = 2.0
	_lesson_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lesson_mark.visible = false
	_ui.add_child(_lesson_mark)
	_hand_owner = UiTheme.label("", UiTheme.DIM)
	_hand_owner.position = Vector2(4, hand_y - UiTheme.FONT_SIZE - 3)
	_ui.add_child(_hand_owner)
	_hand = HBoxContainer.new()
	_hand.position = Vector2(4, hand_y)
	_hand.theme_type_variation = "CompactBox"
	_ui.add_child(_hand)
	var col := GridContainer.new()
	col.columns = 2
	col.position = Vector2(view.x - 82, hand_y)
	col.theme_type_variation = "CompactGrid"
	_ui.add_child(col)
	for spec in [["end", "End", Strings.t("combat.end_turn_space")], ["strike", "Strike", Strings.t("combat.basic_strike_adjacent_str_uses")],
			["guard", "Guard", Strings.t("combat.basic_guard_defense_until_your")],
			["wheel", "Wheel", Strings.t("combat.vector_wheel_improvise_a_spell_2")], ["flee", "Flee", Strings.t("combat.flee_when_everyone_stands_on")],
			["undo", "Undo", Strings.t("combat.undo_this_turn_s_move")], ["cantrip", Strings.t("combat.cantrip"), Strings.t("combat.cantrip_tip")],
			["hold", Strings.t("combat.hold"), Strings.t("combat.hold_tip")], ["party", Strings.t("combat.party"), Strings.t("combat.party_tip")]]:
		var key: String = spec[0]
		var b := UiTheme.button(spec[1], func() -> void: _on_button(key))
		b.custom_minimum_size = Vector2(39, 18)
		b.tooltip_text = spec[2]
		col.add_child(b)
		_buttons[key] = b
	# Strike and Guard are Quicks: they sit beside the hand (PT Part 3).
	_quick_box = VBoxContainer.new()
	_quick_box.theme_type_variation = "CompactBox"
	_quick_box.position = Vector2(4 + 3 * (Assets.texture(str(UiTheme.skin("cards").get("spell", ""))).get_width() + 2) + 2, hand_y + 2)
	_ui.add_child(_quick_box)
	for key in ["strike", "guard"]:
		var qb: Button = _buttons[key]
		col.remove_child(qb)
		qb.text = "%s (%s)" % [qb.text, Strings.t("combat.quick_badge")]
		_quick_box.add_child(qb)
	# Keep the button grid on screen however wide the labels are.
	col.position.x = view.x - col.get_combined_minimum_size().x - 2
	# The combat log: everything that happened, scrollable, newest at the bottom.
	var lp := PanelContainer.new()
	lp.position = Vector2(2, 64)
	lp.custom_minimum_size = Vector2(112, 0)
	_ui.add_child(lp)
	_log_scroll = ScrollContainer.new()
	_log_scroll.custom_minimum_size = Vector2(108, Display.base.y * 0.26)
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lp.add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_box)
	# Hover info: what's on the tile under the mouse (unit, HP, statuses).
	_hover_info = PanelContainer.new()
	_hover_info.theme_type_variation = "Tooltip"
	_hover_info.visible = false
	_hover_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hover_info)
	var hv := VBoxContainer.new()
	_hover_info.add_child(hv)
	_hover_label = UiTheme.label("")
	hv.add_child(_hover_label)
	_hover_shapes = HBoxContainer.new()
	hv.add_child(_hover_shapes)


func _refresh_hud() -> void:
	for c in _timeline.get_children():
		_timeline.remove_child(c)
		c.queue_free()
	# This round, a round marker, then the next round.
	var tl: Dictionary = DataDB.table("ui").get("timeline", {})
	var rounds := state.timeline_rounds()
	var left := int(tl.get("count", 12))
	for group in [["now", int(rounds["round"])], ["next", int(rounds["round"]) + 1]]:
		var list: Array = rounds[group[0]]
		if list.is_empty() or left <= 0:
			continue
		_timeline.add_child(UiTheme.label("R%d" % group[1], UiTheme.DIM))
		if group[0] == "now":
			# Turns already taken this round, faded.
			var past: Array = []
			for i in range(0, maxi(0, state.turn_index)):
				var pu: UnitScript = state.order[i]
				if pu.alive():
					past.append(pu)
			for pu in past.slice(maxi(0, past.size() - int(tl.get("pastCount", 4)))):
				var pb := PanelContainer.new()
				pb.theme_type_variation = "TimelineParty" if pu.team == "party" else "TimelineEnemy"
				pb.add_child(_portrait(pu, int(tl.get("portrait", 20))))
				pb.modulate.a = float(tl.get("pastAlpha", 0.35))
				pb.tooltip_text = pu.name
				_timeline.add_child(pb)
		# Identical minions in a row show as one chip ("Gremlin x4").
		var runs: Array = []
		for u in list:
			var key: String = str(u.source.get("id", u.id)) if u.role == "minion" else str(u.id)
			if not runs.is_empty() and runs[-1]["key"] == key and u != state.current:
				runs[-1]["n"] += 1
			else:
				runs.append({ "key": key, "unit": u, "n": 1 })
		for r in runs.slice(0, left):
			var u: UnitScript = r["unit"]
			var box := PanelContainer.new()
			box.theme_type_variation = "TimelineCurrent" if u == state.current and group[0] == "now" else ("TimelineParty" if u.team == "party" else "TimelineEnemy")
			var inner := HBoxContainer.new()
			inner.theme_type_variation = "CompactBox"
			var is_now: bool = u == state.current and group[0] == "now"
			inner.add_child(_portrait(u, int(tl.get("portraitCurrent", 26)) if is_now else int(tl.get("portrait", 20))))
			if int(r["n"]) > 1:
				inner.add_child(UiTheme.label("x%d" % int(r["n"])))
			box.add_child(inner)
			box.tooltip_text = Strings.t("combat.init") % [u.name, " x%d" % int(r["n"]) if int(r["n"]) > 1 else "", u.initiative]
			_timeline.add_child(box)
			left -= 1
			# The red "last chance" link: this party turn is the last one before these enemies act.
			if u.team == "party" and group[0] == "now":
				var next := state.acts_next(u)
				if not next.is_empty():
					var link := ColorRect.new()
					link.color = UiTheme.color("bad")
					link.custom_minimum_size = Vector2(int(tl.get("linkWidth", 4)), int(tl.get("linkHeight", 2)))
					link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					link.tooltip_text = Strings.t("combat.last_chance") % ", ".join(PackedStringArray(next.map(func(o: UnitScript) -> String: return o.name)))
					link.mouse_filter = Control.MOUSE_FILTER_PASS
					_timeline.add_child(link)
	var u := state.current
	if u != null:
		var lines: Array = ["%s%s" % [u.name, Strings.t("combat.ai") if u.ai_controlled else ""], Strings.t("combat.hp_mp") % [u.hp, u.max_hp, u.mp, u.max_mp]]
		if u.team == "party" and not u.ai_controlled:
			if state.uses_actions(u):
				lines.append(Strings.t("combat.actions_left") % [u.actions_left, state.actions_per_turn(), Strings.t("combat.quick_ready") if not u.quick_used else Strings.t("combat.quick_spent")])
			else:
				lines.append(Strings.t("combat.move") % [u.move_left, Strings.t("combat.action_used") if u.action_used else Strings.t("combat.action_ready")])
			if u.deck != null:
				lines.append(Strings.t("combat.deck_discard") % [u.deck.draw_pile.size(), u.deck.discard.size()])
		if u.shield > 0:
			lines.append(Strings.t("combat.shield") % u.shield)
		_unit_panel.text = "\n".join(PackedStringArray(lines))
	_refresh_hand()
	var player_turn := _player_turn()
	_buttons["end"].disabled = not player_turn
	var act_block := state.act_block(u) if u != null else "-"
	var quick_block := state.quick_block(u) if u != null else "-"
	_buttons["strike"].disabled = not player_turn or quick_block != "" or (u != null and state._adjacent_hostiles(u, 1).is_empty())
	_buttons["guard"].disabled = not player_turn or quick_block != ""
	_buttons["wheel"].disabled = not player_turn or act_block != "" or u.known_vectors.is_empty() or not bool(_ui_open.get("wheel", true))
	_buttons["flee"].disabled = not player_turn or not state.can_flee()
	_buttons["undo"].disabled = not player_turn or not state.can_undo_move(u)
	_buttons["undo"].tooltip_text = Strings.t("combat.undo_this_turn_s_move") if u == null or state.can_undo_move(u) else Strings.t("combat.undo_locked") % state.undo_reason(u)
	_buttons["cantrip"].disabled = not player_turn or act_block != "" or state.cantrip_targets(u).is_empty()
	_buttons["hold"].disabled = not player_turn or state.hold_block(u) != ""
	_pips.visible = u != null and state.uses_actions(u)
	if _pips.visible:
		for i in _pips.get_child_count():
			var pip := _pips.get_child(i) as ColorRect
			if i < 2:
				pip.color = UiTheme.ACCENT if u.actions_left > i else Color(UiTheme.DIM, 0.4)
			else:
				pip.color = UiTheme.GOOD if not u.quick_used else Color(UiTheme.DIM, 0.4)
	if mode == "idle" and _hover_card < 0:
		_info.text = _turn_hint()


## What the player can still do this turn.
func _turn_hint() -> String:
	var u := state.current
	if not _player_turn() or u == null:
		return ""
	var can_act := state.act_block(u) == ""
	if not can_act and not state.can_move(u):
		_buttons["end"].grab_focus.call_deferred()
		return Strings.t("combat.turn_done_end_turn_space")
	if state.uses_actions(u):
		return Strings.t("combat.actions_left") % [u.actions_left, state.actions_per_turn(),
			Strings.t("combat.quick_ready") if not u.quick_used else Strings.t("combat.quick_spent")]
	var parts: Array = []
	if state.can_move(u):
		parts.append(Strings.t("combat.move_2") % u.move_left)
	if can_act:
		parts.append(Strings.t("combat.act_once"))
	if not u.quick_used:
		parts.append(Strings.t("combat.1_quick_card"))
	var rule := Strings.t("combat.or") if state.turn_mode == "move_or_act" and u.moved_steps == 0 and not u.action_used else ", "
	return Strings.t("combat.this_turn_red_tiles_enemy") % rule.join(PackedStringArray(parts))


func _refresh_hand() -> void:
	for c in _hand.get_children():
		_hand.remove_child(c)
		c.queue_free()
	var u := state.current
	_hand_owner.text = ""
	if u == null or u.deck == null or u.team != "party" or u.ai_controlled:
		return
	# The hand belongs to someone: their name above it, their color around each card.
	_hand_owner.text = Strings.t("combat.hand_of") % u.name
	var owner_color := _party_color(u)
	_hand_owner.add_theme_color_override("font_color", owner_color)
	for i in u.deck.hand.size():
		var card := state.card_of(u, i)
		var b := CardView.new()
		var cost := state.card_cost(u, card)
		b.setup(card, cost)
		b.owner_color = owner_color
		b.selected = (mode == "card" and selected_hand == i) or (mode == "wheel_target" and wheel_fuel == i)
		var block := state.card_block(u, card)
		b.disabled = not _player_turn() or (block != "" and mode != "fuel" and mode != "hold") or not bool(_ui_open.get("hand", true))
		b.held = str(u.deck.hand[i]) == u.held_id
		if state.uses_actions(u):
			b.tooltip_text += "\n" + (Strings.t("combat.uses_quick") if bool(card.get("quick", false)) and not u.quick_used else Strings.t("combat.uses_action"))
		if _player_turn() and block != "":
			b.tooltip_text += "\n" + block
		elif bool(card.get("quick", false)):
			b.tooltip_text += Strings.t("combat.quick_doesn_t_use_your")
		var idx := i
		b.pressed.connect(func() -> void: _on_card(idx))
		b.mouse_entered.connect(func() -> void: _hover_card_changed(idx))
		b.focus_entered.connect(func() -> void: _hover_card_changed(idx))
		b.mouse_exited.connect(func() -> void: _hover_card_changed(-1))
		b.focus_exited.connect(func() -> void: _hover_card_changed(-1))
		_hand.add_child(b)
	if _focus_card >= 0 and _focus_card < _hand.get_child_count():
		(_hand.get_child(_focus_card) as Control).grab_focus.call_deferred()


## A shield icon on units in cover: enemies against the active party member,
## party members against the hovered enemy's planned spot (CT Part 3).
func _covered(u: UnitScript) -> bool:
	if u.is_prop() or not u.alive() or state.current == null:
		return false
	if u.team == "enemy" and state.current.team == "party":
		return state.cover_piece(state.current.cell, u.cell) != null
	var hov := state.unit_at(hover_cell)
	if u.team == "party" and hov != null and hov.team == "enemy" and hov.alive():
		return state.cover_piece(hov.intent.get("move", hov.cell), u.cell) != null
	return false


## See-through (PT Part 3): units standing in front of the hovered tile fade to
## 30%, and holding the threat view ghosts everyone.
func _fade_for(u: UnitScript) -> float:
	if field != null and field.threat_view:
		return 0.3
	if hover_cell.x < 0 or u.cell == hover_cell:
		return 1.0
	var dy := u.cell.y - hover_cell.y
	return 0.3 if dy >= 1 and dy <= 2 and absi(u.cell.x - hover_cell.x) <= 1 else 1.0


func _open_party_panel() -> void:
	var pp := PartyPanel.new()
	pp.state = state
	await Flow.show_modal(pp)


## The pause menu (P / Start): Resume, Party, Options, and in the arena Save and Quit or Abandon.
func _pause_menu() -> void:
	var m := Modal.new()
	m.build(Strings.t("pause.title"), 260)
	m.add_button(Strings.t("pause.resume"), func() -> void: m.finish("resume"))
	m.add_button(Strings.t("pause.party"), func() -> void: m.finish("party"))
	m.add_button(Strings.t("pause.options"), func() -> void: m.finish("options"))
	if GameState.combat_context == "arena":
		m.add_button(Strings.t("pause.save_quit"), func() -> void: m.finish("save"))
		m.add_button(Strings.t("pause.abandon"), func() -> void: m.finish("abandon"))
	var r: Variant = await Flow.show_modal(m)
	match str(r):
		"party":
			await _open_party_panel()
		"options":
			Narrator.say(Strings.t("pause.options_soon"))
		"save":
			GameState.save_arena_and_quit()
		"abandon":
			_done = true
			GameState.finish_combat({ "result": "lose", "party": [] })
			EventBus.run_ended.emit("arena")


## Each party member's color (data/ui.json "partyColors", by party order).
func _party_color(u: UnitScript) -> Color:
	var colors: Array = DataDB.table("ui").get("partyColors", [])
	var party: Array = state.units.filter(func(o: UnitScript) -> bool: return o.team == "party" and not o.is_prop())
	var i := party.find(u)
	return Color(str(colors[i % colors.size()])) if i >= 0 and not colors.is_empty() else UiTheme.TEXT


## A small picture of a unit for the timeline: their portrait if they have one,
## otherwise the first frame of their sprite.
func _portrait(u: UnitScript, size: int) -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if u.is_prop():
		return r
	var portrait := str(u.source.get("portrait", ""))
	if portrait != "" and Assets.has(portrait):
		r.texture = Assets.texture(portrait)
		return r
	var sprite_id := u.sprite if u.sprite != "" else Assets.role("player")
	var at := AtlasTexture.new()
	at.atlas = Assets.texture(sprite_id)
	at.region = Rect2(Vector2.ZERO, Assets.frame(sprite_id))
	r.texture = at
	return r


## Hovering (or focusing) a card previews it on the grid without selecting it.
func _hover_card_changed(i: int) -> void:
	_hover_card = i
	if i >= 0:
		_lesson_event("hovered_card")
	if i >= 0:
		_show_card_info(i)
	_refresh_overlays()


func _likely_target(cells: Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in cells:
		var cell: Vector2i = c
		var t := state.unit_at(cell)
		if t != null and t.team != state.current.team and not t.dead:
			var d := Vector2(cell - state.current.cell).length()
			if d < best_d:
				best_d = d
				best = cell
	if best.x < 0 and not cells.is_empty():
		best = cells[0]
	return best


func _show_card_info(i: int) -> void:
	var card := state.card_of(state.current, i)
	if not card.is_empty():
		_info.text = Strings.t("combat.mp") % [card.get("name", ""), state.card_cost(state.current, card), CardRules.describe(DataDB.all(), card)]


func _player_turn() -> bool:
	return not _busy and not _done and state.result == "" and state.current != null \
		and state.current.team == "party" and not _is_ai(state.current)


## AI-controlled units, plus the whole party when the --autoplay dev flag is on.
func _is_ai(u: UnitScript) -> bool:
	return u.ai_controlled or (GameState.dev_autoplay and u.team == "party")


# --- Overlays and previews --------------------------------------------------------------------

func _refresh_overlays() -> void:
	field.cover_cells = []
	field.reach_cells = []
	field.target_cells = []
	field.footprint_cells = []
	field.push_marks = []
	field.preview_labels = {}
	field.hover_cell = hover_cell
	field.cursor_cell = cursor_cell
	if _player_turn():
		var u := state.current
		match mode:
			"idle":
				field.reach_cells = state.reachable_cells(u).keys() if state.can_move(u) else []
				field.reach_cells.append_array(state.climb_targets(u))
				# Tiles next to cover get an outline while choosing where to move.
				var cov: Array = []
				for c in field.reach_cells:
					for d in GridScript.DIRS:
						if state.is_cover(state.unit_at(c + d)):
							cov.append(c)
							break
				field.cover_cells = cov
				if _hover_card >= 0 and _hover_card < u.deck.hand.size():
					var card := state.card_of(u, _hover_card)
					field.target_cells = state.card_targets(u, card)
					_preview(card, false, true)
			"card":
				var card := state.card_of(u, selected_hand)
				field.target_cells = state.card_targets(u, card)
				_preview(card, false)
			"strike":
				field.target_cells = state._adjacent_hostiles(u, 1) + state.adjacent_walls(u)
			"cantrip":
				field.target_cells = state.cantrip_targets(u)
			"wheel_target":
				var card := _wheel_card()
				field.target_cells = state.card_targets(u, card)
				_preview(card, true)
	field.queue_redraw()


## Footprint and predicted damage at the hovered tile; for a card that's only
## hovered in hand (`guess`), at the nearest target tile with an enemy on it.
func _preview(card: Dictionary, improvised: bool, guess: bool = false) -> void:
	var target := hover_cell if hover_cell.x >= 0 else cursor_cell
	if guess:
		# Only a tile the mouse is actually on counts; otherwise aim at the likely target.
		target = hover_cell if field.target_cells.has(hover_cell) else _likely_target(field.target_cells)
	if not field.target_cells.has(target):
		return
	var p := state.preview(state.current, card, target, improvised)
	field.footprint_cells = p["cells"]
	field.footprint_heal = CardRules.heals(card)
	var axes := CardRules.ordered_vectors(DataDB.all(), card.get("vectors", {}))
	var fc := UiTheme.vector_color(str(axes[0])) if not axes.is_empty() else UiTheme.color("bad")
	fc.a = 0.5
	field.footprint_color = fc
	field.push_marks = p.get("pushes", [])
	var hostile := 0
	var lines: Array = [Strings.t("combat.mp_2") % [card.get("name", ""), int(p["cost"])]]
	for h in p["hits"]:
		var t := state.unit_by_id(str(h["unit"]))
		var nm: String = t.name if t != null else str(h["unit"])
		var tag := ""
		if h.has("damage"):
			hostile += 1
			tag = "-%d" % int(h["damage"])
			if float(h.get("cover", 1.0)) < 1.0:
				tag += " " + Strings.t("combat.in_cover") % str(snappedf(float(h["cover"]), 0.01))
			for s in h.get("status", []):
				tag += " " + str(UiTheme.status_info(str(s)).get("name", s))
		else:
			tag = "+%d" % int(h["heal"])
		lines.append("%s %s" % [nm, tag])
		if t != null:
			field.preview_labels[t.cell] = tag
	if hostile > 1:
		lines.append(Strings.t("combat.hits_enemies") % hostile)
	for m in p.get("pushes", []):
		var t := state.unit_by_id(str(m["unit"]))
		var what := Strings.t("combat.lands_in_a_hazard") if bool(m["hazard"]) else (Strings.t("combat.slides_on_ice") if bool(m["slide"]) else "")
		if bool(m["collide"]):
			what = Strings.t("combat.slams_into_something_2") % int(m["damage"])
		if what != "" and t != null:
			lines.append("%s %s" % [t.name, what])
	for i in p.get("interrupts", []):
		var t := state.unit_by_id(str(i["unit"]))
		if t != null:
			lines.append("%s: %s!" % [t.name, i["effect"]])
	lines.append(Strings.t("combat.stable") % roundi(float(p["chance"]) * 100.0))
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
		_update_hover_info(event.position)
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
	if event.is_action_pressed("card_next") or event.is_action_pressed("card_prev"):
		_cycle_card(1 if event.is_action_pressed("card_next") else -1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and cursor_cell.x >= 0:
		_click_cell(cursor_cell)
	elif event.is_action_pressed("end_part"):
		_on_button("end")
	elif event.is_action_pressed("pause"):
		_pause_menu()
	elif event.is_action_pressed("cancel"):
		# Esc / B: deselect first; from idle it undoes the move.
		if mode == "idle" and _player_turn() and state.can_undo_move(state.current):
			_on_button("undo")
		else:
			_cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_7:
			_on_card(k - KEY_1)
		elif k == KEY_S:
			_on_button("strike")
		elif k == KEY_G:
			_on_button("guard")
		elif k == KEY_C:
			_on_button("cantrip")
		elif k == KEY_H:
			_on_button("hold")
		elif k == KEY_V:
			_on_button("wheel")
		elif k == KEY_F:
			_on_button("flee")


## Highlight the next or previous card with the keyboard or pad; it previews like a hover.
func _cycle_card(step: int) -> void:
	if not _player_turn() or _hand.get_child_count() == 0:
		return
	var n := _hand.get_child_count()
	_focus_card = (maxi(_focus_card, 0 if step > 0 else 1) + step + n) % n if _focus_card >= 0 else (0 if step > 0 else n - 1)
	(_hand.get_child(_focus_card) as Control).grab_focus()


## The tooltip for the hovered tile: who's there (HP, statuses, intent), the
## terrain and tile effects, and which enemies threaten it.
func _update_hover_info(at: Vector2) -> void:
	if hover_cell.x < 0:
		_hover_info.visible = false
		return
	var lines: Array = []
	var t := state.unit_at(hover_cell)
	for c in _hover_shapes.get_children():
		_hover_shapes.remove_child(c)
		c.queue_free()
	field.focus_cells = []
	if t != null and t.team == "enemy" and not t.dead:
		field.focus_cells = state.intent_cells(t)
	elif not state.threats().get(hover_cell, []).is_empty():
		field.focus_cells = [hover_cell]
	if t != null and t.is_prop() and state.is_cover(t):
		lines.append(Strings.t("combat.cover_piece") % t.hp)
		t = null
	if t != null and not t.dead:
		lines.append(Strings.t("combat.hp") % [state.display_name(t), t.hp, t.max_hp, Strings.t("combat.mp_3") % [t.mp, t.max_mp] if t.max_mp > 0 else ""])
		if t.shield > 0:
			lines.append(Strings.t("combat.shield_turns") % [t.shield, t.shield_turns])
		if t.downed:
			lines.append(Strings.t("combat.downed_info") % t.bleed)
		if t.team == "enemy":
			# Everything about the enemy (PT Part 3): actions with shape, range, damage and riders; passives, affixes, matchups.
			for act in t.actions:
				var sm := state.action_summary(t, act)
				var riders := ", ".join(PackedStringArray(sm["riders"]))
				lines.append(Strings.t("combat.action_line") % [sm["name"], sm["shape"], int(sm["range"]), int(sm["damage"]), (" (" + riders + ")") if riders != "" else ""])
				if not (sm["form"] as Dictionary).is_empty():
					var dg := ShapeDiagram.new()
					dg.setup(sm["form"], str(sm["magnitude"]), UiTheme.color("bad"), 3)
					_hover_shapes.add_child(dg)
			var beh := str(t.source.get("behavior", ""))
			if beh != "":
				lines.append(Strings.t("combat.passive") % Strings.t("behavior." + beh))
			for a in t.source.get("affixes", []):
				lines.append(Strings.t("combat.affix_line") % str(DataDB.table("ui").get("affixes", {}).get(str(a), {}).get("name", str(a).capitalize())))
			lines.append(Strings.t("combat.weak_strong") % [", ".join(PackedStringArray(t.source.get("weakTo", []))) if not t.source.get("weakTo", []).is_empty() else "-",
				", ".join(PackedStringArray(t.source.get("strongAgainst", []))) if not t.source.get("strongAgainst", []).is_empty() else "-"])
			if not t.intent.is_empty():
				lines.append(Strings.t("combat.next_plan") % state.intent_words(t))
		for s in state.status_list(t):
			var info := UiTheme.status_info(str(s))
			lines.append("%s: %s" % [info.get("name", s), info.get("text", "")])
		if not t.intent.is_empty():
			var act: Dictionary = t.intent.get("action", {})
			var plan := str(t.intent.get("kind", ""))
			if act.has("name"):
				plan = str(act["name"])
			if int(t.intent.get("charge", 0)) > 0:
				plan += Strings.t("combat.charging_turn") % int(t.intent["charge"])
			if str(t.intent.get("mode", "")) == "tracking":
				plan += Strings.t("combat.follows_its_target")
			lines.append(Strings.t("combat.next") + plan)
	var ter := state.grid.get_terrain(hover_cell)
	if state.grid.wall_hp.has(hover_cell):
		lines.append("%s (%d HP)" % [ter.capitalize(), int(state.grid.wall_hp[hover_cell])])
	elif ter != GridScript.FLOOR:
		lines.append(ter.capitalize())
	if state.climb_targets(state.current).has(hover_cell) if state.current != null else false:
		lines.append(Strings.t("combat.climb_tip"))
	for d in GridScript.DIRS:
		if state.is_cover(state.unit_at(hover_cell + d)):
			lines.append(Strings.t("combat.next_to_cover"))
			break
	if state.grid.toxic.has(hover_cell):
		lines.append(Strings.t("combat.lingering") % ["Toxic", int(state.grid.toxic[hover_cell])])
	if state.grid.burning.has(hover_cell):
		lines.append(Strings.t("combat.burning"))
	if state.grid.steam.has(hover_cell):
		lines.append(Strings.t("combat.steam_blocks_sight"))
	for h in state.threats().get(hover_cell, []):
		var src := state.unit_by_id(str(h["unit"]))
		if src != null:
			lines.append(Strings.t("combat.threatened_by") % [src.name, int(h["damage"])])
	var here := state.unit_at(hover_cell)
	if here != null and here.team == "party":
		for e in state.blocking(here):
			lines.append(Strings.t("combat.blocks_path") % e.name)
	if lines.is_empty():
		_hover_info.visible = false
		return
	_hover_label.text = "\n".join(PackedStringArray(lines))
	_hover_shapes.visible = _hover_shapes.get_child_count() > 0
	_hover_info.reset_size()
	var pos := at + Vector2(10, 10)
	var view := Display.size_f()
	pos.x = minf(pos.x, view.x - _hover_info.size.x - 2)
	pos.y = minf(pos.y, view.y - _hover_info.size.y - 2)
	_hover_info.position = pos
	_hover_info.visible = true


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
	if mode == "hold":
		mode = "idle"
		if state.hold_card(u, i):
			_lesson_event("held")
			_after_action()
		return
	if mode == "fuel":
		wheel_fuel = i
		mode = "wheel_target"
		_info.text = Strings.t("combat.aim_the_improvised_spell_burning") % state.card_of(u, i).get("name", "")
		_refresh_overlays()
		_refresh_hud()
		return
	if mode == "card" and selected_hand == i:
		_cancel()
		return
	var card := state.card_of(u, i)
	var block := state.card_block(u, card)
	if block != "":
		_info.text = "%s: %s" % [card.get("name", ""), block]
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
	if key == "party":
		await _open_party_panel()
		return
	if not _player_turn():
		return
	var u := state.current
	match key:
		"end":
			_cancel()
			state.end_turn()
			_after_action()
		"strike":
			if not u.action_used:
				mode = "strike"
				_refresh_overlays()
		"guard":
			if state.guard(u):
				_lesson_event("guarded")
				_after_action()
		"wheel":
			_open_wheel()
		"flee":
			if state.flee():
				_after_action()
		"undo":
			_cancel()
			if state.undo_move(u):
				_after_action()
		"party":
			await _open_party_panel()
		"hold":
			if state.hold_block(u) == "":
				mode = "hold"
				_info.text = Strings.t("combat.pick_card_to_hold")
				_refresh_hud()
		"cantrip":
			if state.act_block(u) == "" and not state.cantrip_targets(u).is_empty():
				mode = "cantrip"
				_refresh_overlays()


## Idle: a reachable tile moves you. With a card (or Strike, or an aimed
## improvised spell) selected: a valid target confirms it, and any other tile
## just deselects, so a misclick never does something unexpected.
func _click_cell(c: Vector2i) -> void:
	if not _player_turn():
		return
	var u := state.current
	match mode:
		"idle":
			if state.climb_targets(u).has(c):
				if state.climb(u, c):
					_lesson_event("moved")
				_after_action()
			elif state.can_move(u) and state.reachable_cells(u).has(c):
				var was_red := state.threat_at(u.cell, u.team) > 0
				if state.move(u, c):
					_lesson_event("dodged" if was_red and state.threat_at(u.cell, u.team) == 0 else "moved")
				_after_action()
		"card":
			if state.play_card(u, selected_hand, c):
				_lesson_event("played_card")
				mode = "idle"
				selected_hand = -1
				_after_action()
			else:
				_cancel()
		"strike":
			if state.strike(u, c):
				_lesson_event("struck")
				mode = "idle"
				_after_action()
			else:
				_cancel()
		"cantrip":
			if state.cast_cantrip(u, c):
				_lesson_event("cantrip")
				mode = "idle"
				_after_action()
			else:
				_cancel()
		"wheel_target":
			if state.improvise(u, wheel_vectors, wheel_form, wheel_magnitude, wheel_fuel, c):
				_lesson_event("improvised")
				mode = "idle"
				wheel_fuel = -1
				_after_action()
			else:
				_cancel()


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
	box.add_child(UiTheme.label(Strings.t("combat.vector_wheel_improvise_a_spell"), UiTheme.ACCENT))
	var db: Dictionary = DataDB.all()
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(UiTheme.label(Strings.t("combat.vectors")))
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
	frow.add_child(UiTheme.label(Strings.t("combat.form")))
	for f in u.known_forms:
		var fid := str(f)
		frow.add_child(UiTheme.button(("[%s]" if wheel_form == fid else "%s") % str(DataDB.record("forms", fid).get("name", fid)), func() -> void:
			wheel_form = fid
			_open_wheel()))
	var mrow := HBoxContainer.new()
	box.add_child(mrow)
	mrow.add_child(UiTheme.label(Strings.t("combat.magnitude")))
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
		box.add_child(UiTheme.label(Strings.t("combat.mp_1_card_as_fuel") % [card["name"], cost,
			roundi(Res.stability_chance(db, u.stability, cost, u.mp, true) * 100.0)]))
	if err != "":
		box.add_child(UiTheme.label(err, UiTheme.BAD))
	var brow := HBoxContainer.new()
	box.add_child(brow)
	var aim := UiTheme.button(Strings.t("combat.pick_fuel_card_then_aim"), func() -> void:
		_wheel.queue_free()
		_wheel = null
		mode = "fuel"
		_info.text = Strings.t("combat.click_a_card_in_your")
		_refresh_hud())
	aim.disabled = err != ""
	brow.add_child(aim)
	brow.add_child(UiTheme.button(Strings.t("combat.close"), _cancel))


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
	await _wait(0.1 if state.current.role == "minion" else 0.3)
	AI.take_turn(state, state.current)
	_busy = false
	await _play_events()


## Combat speed (data/ui.json "combatSpeed"), times the fast-forward key while held.
func _speed() -> float:
	var cs: Dictionary = DataDB.table("ui").get("combatSpeed", {})
	var s := float(cs.get(str(cs.get("setting", "normal")), 1.0))
	if Input.is_action_pressed("fast_forward"):
		s *= float(cs.get("holdMul", 0.2))
	return s


## Pause between beats of an animation, scaled by combat speed.
func _wait(seconds: float) -> void:
	var t := seconds * _speed()
	if t <= 0.01:
		await get_tree().process_frame
		return
	await get_tree().create_timer(t).timeout


## Tween durations scaled by combat speed (never zero, so tweens still finish).
func _dur(seconds: float) -> float:
	return maxf(0.01, seconds * _speed())


func _unit_view(id: String) -> Node2D:
	var u := state.unit_by_id(id)
	if u == null:
		for x in state.units:
			if x.id == id:
				u = x
	return views.get(u, null)


func _uname(id: String) -> String:
	var u := state.unit_by_id(id)
	return u.name if u != null else id


## Nudge the battlefield a little toward the acting unit, then back.
func _nudge_to(v: Node2D) -> void:
	var center := Display.size_f() / 2.0
	var offset := (center - v.position) * 0.06
	var tw := create_tween()
	tw.tween_property(self, "position", offset, _dur(0.2))
	await tw.finished


func _nudge_back() -> void:
	if position == Vector2.ZERO:
		return
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2.ZERO, _dur(0.15))
	await tw.finished


func _play_event(e: Dictionary) -> void:
	match str(e["t"]):
		"round":
			_say_banner(Strings.t("combat.round") % int(e["n"]))
			_note(Strings.t("combat.round_2") % int(e["n"]))
			await _wait(0.4)
		"turn":
			await _nudge_back()
			var u := state.unit_by_id(str(e["unit"]))
			if u != null:
				if u.team == "party":
					Audio.event("turn_start_party")
					var next := state.acts_next(u)
					if next.size() == 1:
						_say_banner(Strings.t("combat.enemy_acts_next") % u.name, u)
					elif next.size() > 1:
						_say_banner(Strings.t("combat.enemies_act_next") % [u.name, next.size()], u)
					else:
						_say_banner(Strings.t("combat.unit_turn") % u.name, u)
				else:
					Audio.event("turn_start_enemy")
				if u.team == "party" and not _is_ai(u):
					cursor_cell = u.cell
					_focus_card = -1
				elif u.team == "enemy":
					# Minions in a row act as one quick group: one banner, short pauses.
					var group := u.role == "minion" and _last_turn_team == "minion"
					if _last_turn_team != "enemy" and not group:
						_say_banner(Strings.t("combat.minions") if u.role == "minion" else Strings.t("combat.enemy_turn"))
						await _wait(0.4)
					_sync_views()
					var v := _view_for_id(u.id)
					if v != null and not group:
						await _nudge_to(v)
					await _wait(0.08 if group else 0.25)
				_last_turn_team = "minion" if u.role == "minion" else u.team
			_sync_views()
		"intent":
			pass
		"move":
			var v := _view_for_id(str(e["unit"]))
			if v == null:
				return
			for cell in e["path"]:
				var tw := create_tween()
				tw.tween_property(v, "position", proj.cell_center(cell), _dur(0.1))
				v.z_index = 10 + int(cell.y)
				v.walk_tick(0.1)
				await tw.finished
			v.stop_walk()
		"push", "slide":
			var v := _view_for_id(str(e["unit"]))
			if v != null:
				var tw := create_tween()
				tw.tween_property(v, "position", proj.cell_center(e["to"]), _dur(0.14 if str(e["t"]) == "push" else 0.25))
				v.z_index = 10 + int(e["to"].y)
				await tw.finished
			if str(e["t"]) == "slide":
				_note(Strings.t("combat.slides_across_the_ice") % _uname(str(e["unit"])))
		"undo":
			if bool(e.get("full", false)):
				# A full undo can remove units that were spawned after the snapshot.
				for x in views.keys():
					if not state.units.has(x):
						views[x].queue_free()
						views.erase(x)
			_sync_views()
		"cast":
			var u := state.unit_by_id(str(e["unit"]))
			_say_banner("%s: %s" % [u.name if u != null else "?", e["name"]])
			var v := _view_for_id(str(e["unit"]))
			if u != null and u.team == "enemy" and v != null:
				# Wind-up: a flash before the hit lands.
				var tw := create_tween()
				v.modulate = Color(2.2, 2.2, 2.2)
				tw.tween_property(v, "modulate", Color.WHITE, _dur(0.3))
				Audio.play_sfx("cast")
				await _wait(0.45)
			else:
				Audio.play_sfx("cast")
				await _wait(0.25)
		"charge":
			var u := state.unit_by_id(str(e["unit"]))
			var line := Strings.t("combat.is_charging") % [u.name if u != null else "?", e.get("name", Strings.t("combat.something_big"))]
			_say_banner(line)
			_note(line)
			Audio.play_sfx("fail")
			var v := _view_for_id(str(e["unit"]))
			if v != null:
				var tw := create_tween()
				tw.tween_property(v, "scale", Vector2(1.15, 1.15), _dur(0.2))
				tw.tween_property(v, "scale", Vector2.ONE, _dur(0.2))
			await _wait(0.6)
		"interrupt":
			_say_banner(str(e["text"]))
			_note(str(e["text"]))
			await _wait(0.4)
		"area":
			field.flash_cells = e["cells"]
			var axis := ""
			for k in e["vectors"]:
				axis = str(k)
			var c := UiTheme.vector_color(axis) if axis != "" else UiTheme.color("bad")
			c.a = 0.5
			field.flash_color = c
			field.queue_redraw()
			await _wait(float(DataDB.table("ui").get("areaFlashSeconds", 0.6)))
			field.flash_cells = []
			field.queue_redraw()
		"damage":
			var v := _view_for_id(str(e["unit"]))
			var amt := int(e["amount"])
			var hurt := state.unit_by_id(str(e["unit"]))
			if not _mocked and _stayed_in_red != "" and hurt != null and hurt.is_player and str(e.get("cause", "")) == "hit":
				# Tutorial room 2: you stood in the red; the training floor catches you.
				_mocked = true
				Narrator.say(Strings.t(_stayed_in_red))
			var txt := "-%d" % amt
			if int(e.get("absorbed", 0)) > 0:
				txt += " (%d)" % int(e["absorbed"])
			if bool(e.get("high", false)):
				txt = Strings.t("combat_state.high_crit") + " " + txt
				Audio.event("high_crit")
			elif bool(e.get("crit", false)):
				txt += "!"
			_float_text(v, txt, UiTheme.color("damage") if not bool(e.get("crit", false)) else UiTheme.color("crit"))
			_note(_damage_line(e))
			Audio.play_sfx("hit")
			if v != null:
				var tw := create_tween()
				v.modulate = Color(2, 2, 2)
				tw.tween_property(v, "modulate", Color.WHITE, _dur(0.15))
			if amt >= 10 or bool(e.get("crit", false)):
				await _shake(3.0)
			else:
				await _wait(0.15)
		"heal":
			_float_text(_view_for_id(str(e["unit"])), "+%d%s" % [int(e["amount"]), Strings.t("combat.up") if bool(e.get("revived", false)) else ""], UiTheme.color("heal"))
			_note(Strings.t("combat.recovers_hp") % [_uname(str(e["unit"])), int(e["amount"]), Strings.t("combat.and_gets_back_up") if bool(e.get("revived", false)) else ""])
			Audio.play_sfx("heal")
			await _wait(0.15)
		"shield":
			_float_text(_view_for_id(str(e["unit"])), Strings.t("combat.shield_2") % int(e["amount"]), UiTheme.color("shield"))
		"status":
			var sname := str(UiTheme.status_info(str(e["status"])).get("name", e["status"]))
			_float_text(_view_for_id(str(e["unit"])), sname, UiTheme.ACCENT)
			_note("%s: %s." % [_uname(str(e["unit"])), sname])
		"guard":
			_float_text(_view_for_id(str(e["unit"])), "guard", UiTheme.DIM)
			_note(Strings.t("combat.guards") % _uname(str(e["unit"])))
		"miss":
			_float_text(_view_for_id(str(e["unit"])), "miss", UiTheme.DIM)
			_note(Strings.t("combat.the_attack_on_misses") % _uname(str(e["unit"])))
		"collide":
			_note(Strings.t("combat.slams_into_something") % _uname(str(e["unit"])))
			await _shake(2.0)
		"down":
			_note(Strings.t("combat.is_down") % _uname(str(e["unit"])))
		"out":
			_say_banner(Strings.t("combat_state.is_out") % _uname(str(e["unit"])))
		"death", "vanish":
			var u: UnitScript = null
			for x in state.units:
				if x.id == str(e["unit"]) and x.dead and views.has(x):
					u = x
			if u != null:
				if str(e["t"]) == "death":
					_note(Strings.t("combat.is_defeated") % u.name)
				var v: Node2D = views[u]
				var tw := create_tween()
				tw.tween_property(v, "modulate", Color(1, 1, 1, 0), _dur(0.25))
				await tw.finished
				v.queue_free()
				views.erase(u)
		"spawn":
			_sync_views()
		"say":
			var u := state.unit_by_id(str(e["unit"]))
			_say_banner("%s: \"%s\"" % [u.name if u != null else "?", e["text"]])
			_note("%s: %s" % [u.name if u != null else "?", e["text"]])
			await _wait(0.9)
		"instability":
			_say_banner(str(e["text"]))
			_note(str(e["text"]))
			Audio.play_sfx("fail")
			await _shake(2.0)
		"phase":
			_say_banner(str(e["text"]))
			_note(str(e["text"]))
			await _shake(4.0)
			await _wait(0.6)
		"log":
			_note(str(e["text"]))
		"glyph":
			_note(Strings.t("combat.a_glyph_flares"))
		"blink":
			var v := _view_for_id(str(e["unit"]))
			if v != null:
				v.modulate = Color(1, 1, 1, 0.2)
				v.position = proj.cell_center(e["to"])
				v.z_index = 10 + int(e["to"].y)
				var tw := create_tween()
				tw.tween_property(v, "modulate", Color.WHITE, _dur(0.2))
				await tw.finished
		"telegraph":
			_say_banner(Strings.t("combat.is_coming") % str(e.get("name", "Something")))
			_note(Strings.t("combat.will_land_on_the_marked") % str(e.get("name", "Something")))
			_sync_views()
			await _wait(0.3)
		"tiles":
			if str(e.get("kind", "")) == "hazard":
				_note(Strings.t("combat.the_floor_breaks_open_new"))
			field.queue_redraw()
		"end":
			await _nudge_back()


## "Frost Wolf hit New Kid for 6 (Cold, resisted)."
func _damage_line(e: Dictionary) -> String:
	var why: Array = []
	var vec := str(e.get("vector", ""))
	if vec != "":
		why.append(vec.capitalize())
	if str(e.get("note", "")) != "":
		why.append(str(e["note"]))
	if bool(e.get("crit", false)):
		why.append("critical")
	if int(e.get("absorbed", 0)) > 0:
		why.append(Strings.t("combat.absorbed") % int(e["absorbed"]))
	var cause := str(e.get("cause", "hit"))
	var target := _uname(str(e["unit"]))
	var line := ""
	match cause:
		"burn":
			line = Strings.t("combat.burns_for") % [target, int(e["amount"])]
		"hazard":
			line = Strings.t("combat.takes_from_the_hazard") % [target, int(e["amount"])]
		"collision":
			line = Strings.t("combat.takes_from_the_collision") % [target, int(e["amount"])]
		"fatigue":
			line = Strings.t("combat.takes_fatigue") % [target, int(e["amount"])]
		"backlash":
			line = Strings.t("combat.the_spell_backlashes_on_for") % [target, int(e["amount"])]
		_:
			var src := str(e.get("source", ""))
			line = Strings.t("combat.hit_for") % [_uname(src) if src != "" else "Something", target, int(e["amount"])]
	if not why.is_empty():
		line += " (%s)" % ", ".join(PackedStringArray(why))
	return line + "."


func _view_for_id(id: String) -> Node2D:
	for u in views:
		if u.id == id and not u.dead:
			return views[u]
	return null


func _float_text(v: Node2D, text: String, color: Color) -> void:
	if v == null:
		return
	var l := UiTheme.world_label(text, color, "damage")
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


# --- Tutorial lessons (CT Part 7) ------------------------------------------------

func _start_lesson(setup: Dictionary) -> void:
	_ui_open = setup.get("ui", { "hand": true, "wheel": true, "threat": true })
	_stayed_in_red = str(setup.get("stayedInRed", ""))
	if not bool(_ui_open.get("hand", true)):
		_hand.modulate = Color(1, 1, 1, 0.35)
	var steps: Array = setup.get("lesson", [])
	if steps.is_empty():
		return
	_lesson = Tutorial.Lesson.new(steps)
	_show_lesson_step()


func _lesson_event(ev: String) -> void:
	if _lesson != null and _lesson.notify(ev):
		_show_lesson_step()


var _last_tick := 0


func _delta_hint() -> float:
	var now := Time.get_ticks_msec()
	var d := 0.0 if _last_tick == 0 else float(now - _last_tick) / 1000.0
	_last_tick = now
	return d


func _tick_lesson(delta: float) -> void:
	if _lesson == null or _lesson.done():
		return
	var hint_after := float(DataDB.table("story/tutorial_floor").get("hintSeconds", 20))
	if _lesson.tick(delta, hint_after) and not _lesson_label.text.ends_with(")"):
		_lesson_label.text += "\n(" + Strings.t(str(_lesson.current().get("hint", ""))) + ")"


func _show_lesson_step() -> void:
	if _lesson == null or _lesson.done():
		_lesson_box.visible = false
		_lesson_mark.visible = false
		return
	var st := _lesson.current()
	_lesson_box.visible = true
	_lesson_label.text = Strings.t(str(st.get("say", "")))
	_lesson_next.visible = str(st.get("wait", "next")) == "next"
	if str(st.get("speaker", "narrator")) == "kelly":
		Audio.voice("kelly")
	var target := _highlight_control(str(st.get("highlight", "")))
	_lesson_mark.visible = target != null
	if target != null:
		var r := target.get_global_rect()
		_lesson_mark.position = r.position - Vector2(2, 2)
		_lesson_mark.size = r.size + Vector2(4, 4)


func _highlight_control(key: String) -> Control:
	match key:
		"timeline":
			return _timeline
		"pips":
			return _pips
		"hand":
			return _hand
		"mp":
			return _unit_panel
		"strike", "guard", "hold", "wheel", "cantrip":
			return _buttons.get(key, null)
	return null


func _say_banner(text: String, who: UnitScript = null) -> void:
	_banner.text = text
	_banner.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
	# The active unit's portrait next to "Quill's turn" (CT Part 2b).
	for c in _banner_face.get_children():
		_banner_face.remove_child(c)
		c.queue_free()
	if who != null:
		_banner_face.add_child(_portrait(who, int(DataDB.table("ui").get("spotlight", {}).get("bannerPortrait", 24))))
		_banner_face.modulate = Color.WHITE
		var tf := create_tween()
		tf.tween_interval(1.4)
		tf.tween_property(_banner_face, "modulate:a", 0.0, 0.4)


func _note(text: String) -> void:
	_log.append(text)
	if _log.size() > 200:
		_log.remove_at(0)
		if _log_box.get_child_count() > 0:
			_log_box.get_child(0).queue_free()
	var l := UiTheme.label(text, UiTheme.DIM if text.begins_with("--") else UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(100, 0)
	_log_box.add_child(l)
	_scroll_log.call_deferred()


func _scroll_log() -> void:
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


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
	var title := str({ "win": "Victory", "flee": Strings.t("combat.you_got_away"), "lose": Strings.t("combat.you_fell") }.get(result, result))
	box.add_child(UiTheme.role_label(title, "title", UiTheme.ACCENT))
	for line in outcome.get("lines", []):
		var l := UiTheme.label(str(line))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(230, 0)
		box.add_child(l)
	var cont := UiTheme.button(Strings.t("combat.continue"), func() -> void: GameState.leave_combat())
	box.add_child(cont)
	cont.grab_focus()
	if GameState.dev_autoplay:
		print("[autoplay] combat result: %s, xp %d, rounds %d" % [result, int(summary["xp"]), int(summary["rounds"])])
		if GameState.combat_context == "arena":
			# Arena autoplay keeps going on its own (--arena --autoplay, tests/smoke_arena.gd).
			get_tree().create_timer(0.5).timeout.connect(func() -> void:
				if is_inside_tree():
					GameState.leave_combat())
	Audio.play_sfx("win" if result == "win" else "lose")

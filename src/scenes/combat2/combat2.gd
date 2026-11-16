## The Combat 2.0 slice fight (docs/COMBAT_2.md Parts 1 to 5): shows a C2State
## on the Lab's 2.5D field and forwards input to it. A turn is: click a blue tile
## to move, pick an Ability (1-9) and click a target; Space ends the turn (Brace),
## T shows every enemy's threat, Esc cancels. Hovering an enemy shows the tiles it
## can reach and hit, and its known markings. Enemy turns play by themselves.
extends Node2D

const C2Setup := preload("res://src/core/combat2/c2_setup.gd")
const C2AI := preload("res://src/core/combat2/c2_ai.gd")
const Shapes := preload("res://src/core/combat2/shapes.gd")
const Kits := preload("res://src/core/combat2/kits.gd")
const Flow := preload("res://src/scenes/combat2/c2_flow.gd")
const Proj := preload("res://src/scenes/combat/grid_projection.gd")
const FieldScript := preload("res://src/scenes/combat/combat_field.gd")
const UnitView := preload("res://src/scenes/combat/unit_view.gd")

var state: Object
var proj: Proj
var field: FieldScript
var views: Dictionary = {}
var selected := ""                  # ability uid being aimed
var hover_cell := Vector2i(-1, -1)
var threat_all := false
var _busy := false
var _done := false
var _log: Array = []
var _ui: CanvasLayer
var _timeline: HBoxContainer
var _info: Label
var _bar: HFlowContainer
var _extra: HBoxContainer
var _log_label: Label
var _hover: Label
var _cutin: Label
var _teach: Label
var _result: PanelContainer


func _ready() -> void:
	var db: Dictionary = DataDB.all()
	var setup: Dictionary = Flow.setup(db)
	state = C2Setup.state(db, setup)
	var cc: Dictionary = Display.combat
	var t := float(Display.tile)
	var cw := float(cc.get("cellWidth", 1.8)) if state.grid.cols <= 9 else float(cc.get("cellWidthWide", 1.6))
	var ch := float(cc.get("cellHeight", 0.9)) if state.grid.rows <= 5 else float(cc.get("cellHeightTall", 0.78))
	proj = Proj.new(state.grid.cols, state.grid.rows, Display.base.x / 2.0, Display.base.y * float(cc.get("frontY", 0.74)), cw * t, ch * t, float(cc.get("shrink", 0.9)))
	field = FieldScript.new()
	field.proj = proj
	field.grid = state.grid
	field.theme_rec = DataDB.record("rooms/themes", str(setup.get("layout", {}).get("theme", "school")))
	add_child(field)
	_build_ui()
	var f := C2Setup.fight(db, Flow.current_fight(db))
	_teach.text = "%s  %s" % [str(f.get("name", "")), str(f.get("teaches", ""))]
	_take_events()
	_sync()
	Audio.play_music_first(["battle_boss" if bool(f.get("boss", false)) else "battle", "battle"])
	_run_others()


# --- UI ---------------------------------------------------------------------------

func _build_ui() -> void:
	var view := Display.size_f()
	_ui = CanvasLayer.new()
	add_child(_ui)
	_timeline = HBoxContainer.new()
	_timeline.position = Vector2(4, 2)
	_ui.add_child(_timeline)
	_teach = UiTheme.label("", UiTheme.DIM)
	_teach.position = Vector2(4, 15)
	_teach.size = Vector2(view.x - 8, 12)
	_teach.clip_text = true
	_ui.add_child(_teach)
	_info = UiTheme.label("")
	_info.position = Vector2(4, 30)
	_info.size = Vector2(150, 60)
	_ui.add_child(_info)
	_hover = UiTheme.label("", UiTheme.ACCENT)
	_hover.position = Vector2(view.x - 170, 30)
	_hover.size = Vector2(166, 70)
	_hover.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui.add_child(_hover)
	_log_label = UiTheme.label("", UiTheme.DIM)
	_log_label.position = Vector2(view.x - 170, 104)
	_log_label.size = Vector2(166, 90)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.clip_text = true
	_ui.add_child(_log_label)
	_bar = HFlowContainer.new()
	_bar.position = Vector2(4, view.y - 46)
	_bar.size = Vector2(view.x - 8, 24)
	_ui.add_child(_bar)
	_extra = HBoxContainer.new()
	_extra.position = Vector2(4, view.y - 20)
	_ui.add_child(_extra)
	_cutin = UiTheme.role_label("", "title", UiTheme.ACCENT)
	_cutin.position = Vector2(0, view.y * 0.32)
	_cutin.size = Vector2(view.x, 24)
	_cutin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cutin.modulate.a = 0.0
	_ui.add_child(_cutin)


func _refresh_ui() -> void:
	for c in _timeline.get_children():
		c.queue_free()
	var last_round: int = state.round_num
	for e in state.c2_timeline():
		if int(e["round"]) != last_round:
			_timeline.add_child(UiTheme.label("|", UiTheme.DIM))
			last_round = int(e["round"])
		var u: Object = e["unit"]
		var l := UiTheme.label(u.name.substr(0, 5), UiTheme.GOOD if u.team == "party" else UiTheme.BAD)
		if u == state.current and int(e["round"]) == state.round_num and _timeline.get_child_count() <= 1:
			l.text = "[" + l.text + "]"
		_timeline.add_child(l)
	var u: Object = state.current
	for c in _bar.get_children():
		c.queue_free()
	for c in _extra.get_children():
		c.queue_free()
	if u == null or _done:
		_info.text = ""
		return
	var lines: Array = ["%s  HP %d/%d%s" % [u.name, maxi(0, u.hp), u.max_hp, ("  shield %d" % u.shield) if u.shield > 0 else ""]]
	if u.team == "party":
		lines.append(Strings.t("c2.move_left") % u.move_left)
		lines.append(Strings.t("c2.meter") % [int(state.meter.get(u.id, 0)), state.c2.count("ultMax", 100)])
		if not state.one_more.is_empty():
			lines.append(Strings.t("c2.one_more_hint"))
	var sts: Array = u.statuses.keys()
	if not sts.is_empty():
		lines.append(", ".join(PackedStringArray(sts)))
	_info.text = "\n".join(PackedStringArray(lines))
	if u.team != "party" or _busy:
		return
	var i := 0
	for ab in state.abilities(u):
		i += 1
		var uid := str(ab["uid"])
		var label := "%d %s" % [i, str(ab.get("name", uid))]
		if str(ab.get("kind", "")) == "spell":
			label += " (%d)" % int(state.charges_left.get(u.id, {}).get(uid, 0))
		var cd := int(state.cooldowns.get(u.id, {}).get(uid, 0))
		if cd > 0:
			label += " cd%d" % cd
		var b := UiTheme.button(label, func() -> void: _select(uid))
		b.name = "Ability_" + uid.replace(":", "_")
		var why: String = state.ability_block(u, ab)
		b.disabled = why != ""
		b.tooltip_text = _ability_text(ab) + ("\n" + why if why != "" else "")
		if uid == selected:
			b.modulate = UiTheme.ACCENT
		_bar.add_child(b)
	var end := UiTheme.button(Strings.t("c2.end_turn"), func() -> void: _act(func() -> void: state.end_turn()))
	end.name = "EndTurn"
	end.tooltip_text = Strings.t("c2.brace_hint")
	_extra.add_child(end)
	if not state.one_more.is_empty():
		for a in state.allies_of(u):
			if a != u and state.baton_block(u, a) == "":
				var who: Object = a
				var bb := UiTheme.button(Strings.t("c2.baton") % a.name, func() -> void: _act(func() -> void: state.baton_pass(u, who)))
				bb.name = "Baton_" + a.id
				_extra.add_child(bb)
	if state.all_out_ready:
		var ao := UiTheme.button(Strings.t("c2.all_out"), func() -> void: _act(func() -> void: state.all_out(u)))
		ao.name = "AllOut"
		_extra.add_child(ao)
	for k in state.backpack_c2.size():
		var it: Dictionary = Kits.item(DataDB.all(), str(state.backpack_c2[k]))
		var idx: int = k
		var ib := UiTheme.button(str(it.get("name", "item")), func() -> void: _act(func() -> void: state.use_item(u, idx)))
		ib.tooltip_text = str(it.get("text", ""))
		ib.disabled = state.item_block(u, k) != ""
		_extra.add_child(ib)
	var tb := UiTheme.button(Strings.t("c2.threat"), func() -> void:
		threat_all = not threat_all
		_sync())
	_extra.add_child(tb)


## A move's quick reference: shape, range, damage, push, status, cooldown, charges.
func _ability_text(ab: Dictionary) -> String:
	var bits: Array = [str(ab.get("shape", "")) + (" %d" % int(ab["range"]) if ab.has("range") else "")]
	if float(ab.get("power", 0)) > 0.0:
		bits.append("%s %d" % [str(ab.get("type", "")), roundi(float(ab["power"]))])
	for k in ["push", "pull", "heal", "shield"]:
		if ab.has(k):
			bits.append("%s %d" % [k, int(ab[k])])
	if ab.has("status"):
		bits.append(str(ab["status"].get("id", "")))
	if bool(ab.get("scan", false)):
		bits.append("scan")
	if int(ab.get("cooldown", 0)) > 0:
		bits.append("cooldown %d" % int(ab["cooldown"]))
	if ab.has("maxCharges"):
		bits.append("%d charges a night" % int(ab["maxCharges"]))
	return ", ".join(PackedStringArray(bits))


# --- The field ------------------------------------------------------------------------

func _view_for(u: Object) -> Node2D:
	if views.has(u):
		return views[u]
	var v := UnitView.new()
	v.setup(u.id, u.team, u.sprite, u.id if u.is_prop() else "")
	add_child(v)
	views[u] = v
	return v


func _sync() -> void:
	for u in state.units:
		if u.dead or (u.cell.x < 0):
			if views.has(u):
				views[u].queue_free()
				views.erase(u)
			continue
		var v := _view_for(u)
		v.position = proj.cell_center(u.cell)
		v.z_index = 10 + u.cell.y
		v.hp_ratio = u.hp_ratio()
		v.max_hp = u.max_hp
		v.shield = u.shield
		v.downed = u.downed
		v.active = u == state.current and not _done
		v.highlight = v.active
		v.facing_arrow = u.facing_dir if not u.is_prop() else Vector2i.ZERO
		v.face(1 if u.facing_dir.x >= 0 else -1)
		var sts: Array = u.statuses.keys()
		v.statuses = sts
		if v.sprite != null:
			v.sprite.rotation = PI / 2.0 if u.statuses.has("knocked") else 0.0
		v.queue_redraw()
	var u: Object = state.current
	field.reach_cells = []
	field.target_cells = []
	field.footprint_cells = []
	field.preview_labels = {}
	if u != null and u.team == "party" and not _done and not _busy:
		if selected == "" and u.move_left > 0 and state.can_move(u):
			field.reach_cells = state.reachable_cells(u).keys()
		elif selected != "":
			var ab: Dictionary = state.ability_of(u, selected)
			field.target_cells = state.ability_targets(u, ab)
			if field.target_cells.has(hover_cell):
				field.footprint_cells = Shapes.cells(state, u, ab, hover_cell)
				var pv: Dictionary = state.ability_preview(u, selected, hover_cell)
				for id in pv.get("units", {}):
					var r: Dictionary = pv["units"][id]
					var t: Object = state.unit_by_id(str(id))
					if t == null:
						continue
					var txt := "%d>%d" % [int(r["hp"]), int(r["hpAfter"])]
					if bool(r["knocked"]):
						txt += " DOWN"
					if bool(r["dies"]):
						txt = "KO"
					field.preview_labels[r["cellAfter"]] = txt
	var threat := {}
	var src: Dictionary = state.all_threat() if threat_all else {}
	var hov: Object = state.unit_at(hover_cell)
	if hov != null and hov.team == "enemy" and hov.alive():
		for c in state.threat_cells(hov):
			src[c] = [hov.id]
	for c in src:
		threat[c] = { "damage": 0, "charge": 0 }
	field.threat_cells = threat
	var tele: Array = []
	for bid in state.boss_plans:
		var p: Dictionary = state.boss_plans[bid]
		tele.append({ "unit": bid, "from": p.get("from", Vector2i.ZERO), "cells": p["cells"], "tag": 0, "tint": UiTheme.color("bad"), "since": 0.0, "badge": str(p["name"]) })
	field.telegraphs = tele
	field.hover_cell = hover_cell
	field.queue_redraw()
	_refresh_hover()
	_refresh_ui()


func _refresh_hover() -> void:
	var t: Object = state.unit_at(hover_cell)
	if t == null or t.is_prop():
		_hover.text = ""
		return
	var lines: Array = ["%s  HP %d/%d" % [t.name, maxi(0, t.hp), t.max_hp]]
	if t.team == "enemy":
		var known: Dictionary = state.known_of(t)
		var parts: Array = []
		for k in known:
			parts.append("%s %s" % [k, known[k]])
		lines.append(Strings.t("c2.marks") % (", ".join(PackedStringArray(parts)) if not parts.is_empty() else "?"))
		if t.statuses.has("knocked"):
			lines.append(Strings.t("c2.knocked"))
	else:
		var k: Dictionary = state.kit_of(t)
		lines.append(Strings.t("c2.party_marks") % [", ".join(PackedStringArray(k.get("weak", []))), ", ".join(PackedStringArray(k.get("resist", [])))])
	_hover.text = "\n".join(PackedStringArray(lines))


# --- Input -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _done or _busy or state.current == null or state.current.team != "party":
		return
	if event is InputEventMouseMotion:
		var c := proj.to_cell(get_global_mouse_position())
		if c != hover_cell:
			hover_cell = c
			_sync()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(proj.to_cell(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		selected = ""
		_sync()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_SPACE:
			_act(func() -> void: state.end_turn())
		elif k == KEY_ESCAPE:
			selected = ""
			_sync()
		elif k == KEY_T:
			threat_all = not threat_all
			_sync()
		elif k >= KEY_1 and k <= KEY_9:
			var list: Array = state.abilities(state.current)
			var i := k - KEY_1
			if i < list.size():
				_select(str(list[i]["uid"]))


func _select(uid: String) -> void:
	selected = "" if selected == uid else uid
	_sync()


func _click(c: Vector2i) -> void:
	var u: Object = state.current
	if selected != "":
		var ab: Dictionary = state.ability_of(u, selected)
		if state.ability_targets(u, ab).has(c):
			var uid := selected
			selected = ""
			_act(func() -> void: state.use_ability(u, uid, c))
		return
	if state.reachable_cells(u).has(c):
		_act(func() -> void: state.move(u, c))


## Do one thing, show what happened, then let enemies (and skipped turns) play.
func _act(f: Callable) -> void:
	if _busy or _done:
		return
	f.call()
	await _take_events()
	_sync()
	_run_others()


func _run_others() -> void:
	if _busy:
		return
	_busy = true
	var steps_done := 0
	while state.result == "" and state.current != null and steps_done < 200:
		steps_done += 1
		var u: Object = state.current
		if u.team == "party" and not state.must_skip(u) and not bool(GameState.dev_autoplay):
			break
		await get_tree().create_timer(0.35 if u.team == "enemy" else 0.2).timeout
		C2AI.take_turn(state, u)
		await _take_events()
		_sync()
	_busy = false
	_sync()
	if state.result != "":
		_finish()


func _take_events() -> void:
	for e in state.take_events():
		match str(e.get("t", "")):
			"log":
				_add_log(str(e.get("text", "")))
			"damage":
				var t: Object = state.unit_by_id(str(e.get("unit", "")))
				if t != null and views.has(t):
					_float(views[t], "-%d" % int(e.get("amount", 0)), UiTheme.BAD)
				if t != null:
					_add_log("%s takes %d." % [t.name, int(e.get("amount", 0))])
			"heal":
				var t: Object = state.unit_by_id(str(e.get("unit", "")))
				if t != null and views.has(t):
					_float(views[t], "+%d" % int(e.get("amount", 0)), UiTheme.GOOD)
			"cast":
				var who: Object = state.unit_by_id(str(e.get("unit", "")))
				if who != null:
					_add_log("%s: %s" % [who.name, str(e.get("name", ""))])
			"cutin":
				await _show_cutin(str(e.get("text", "")))
	_sync()


func _show_cutin(text: String) -> void:
	_cutin.text = text
	_cutin.modulate.a = 1.0
	Audio.play_sfx("ui_confirm")
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_cutin, "modulate:a", 0.0, 0.3)
	await tw.finished


func _float(v: Node2D, text: String, color: Color) -> void:
	var l := UiTheme.world_label(text, color)
	l.position = v.position + Vector2(-8, -float(Display.tile))
	l.z_index = 300
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 10.0, 0.6)
	tw.tween_callback(l.queue_free)


func _add_log(line: String) -> void:
	if line == "":
		return
	_log.append(line)
	_log_label.text = "\n".join(PackedStringArray(_log.slice(maxi(0, _log.size() - 8))))


func _finish() -> void:
	if _done:
		return
	_done = true
	_sync()
	var view := Display.size_f()
	_result = PanelContainer.new()
	_result.position = Vector2(view.x / 2.0 - 110, view.y / 2.0 - 40)
	_result.custom_minimum_size = Vector2(220, 80)
	_ui.add_child(_result)
	var box := VBoxContainer.new()
	_result.add_child(box)
	box.add_child(UiTheme.role_label(Strings.t("c2.won") if state.result == "win" else Strings.t("c2.lost"), "title", UiTheme.GOOD if state.result == "win" else UiTheme.BAD))
	var db: Dictionary = DataDB.all()
	var label := Strings.t("c2.continue") if Flow.night_id != "" and state.result == "win" else Strings.t("c2.menu")
	var go := UiTheme.button(label, func() -> void: Flow.after_fight(db, state.result, state.carry_out(), state.known_marks))
	go.name = "ContinueButton"
	box.add_child(go)
	box.add_child(UiTheme.button(Strings.t("c2.again"), func() -> void: SceneRouter.goto(Flow.COMBAT)))
	go.grab_focus.call_deferred()

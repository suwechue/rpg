## Plays cutscenes (ROADMAP M14) as an overlay on whatever scene is open:
## dialogue with portraits, title cards, fades, full-screen images, choices,
## camera moves and actor moves when the host scene offers them, flags and
## effects. Hold Esc (cancel) or press Skip to skip; hold E (interact) to
## fast-forward the typing. `await Cutscenes.play("id")`.
## A host scene may implement cutscene_actor(id) -> Node2D, cutscene_pos(marker
## or [x, y]) -> Vector2 and cutscene_camera() -> Camera2D.
extends CanvasLayer

signal finished(id: String)

const CS := preload("res://src/core/story/cutscenes.gd")
const Fx := preload("res://src/core/run/effects.gd")

var playing := ""
var _skip := false
var _fast := false
var _advance := false
var _box: PanelContainer
var _text: Label
var _name: Label
var _left: TextureRect
var _right: TextureRect
var _title: Label
var _fade: ColorRect
var _image: TextureRect
## Stands in for a full-screen illustration that has no art yet.
var _veil: ColorRect
var _skip_btn: Button
var _choices: VBoxContainer
var _picked := -1
## Covers the scene below while playing, so clicks advance the cutscene instead
## of pressing that scene's buttons.
var _blocker: Control


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var view := Display.size_f()
	_veil = ColorRect.new()
	_veil.color = UiTheme.color("bg").darkened(0.5)
	_veil.size = view
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	add_child(_veil)
	_image = TextureRect.new()
	_image.size = view
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.visible = false
	add_child(_image)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.size = view
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_blocker = Control.new()
	_blocker.size = view
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)
	_title = UiTheme.label("", UiTheme.ACCENT)
	_title.size = Vector2(view.x, 40)
	_title.position = Vector2(0, view.y * 0.4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", UiTheme.TITLE_SIZE)
	_title.visible = false
	add_child(_title)
	_left = TextureRect.new()
	_right = TextureRect.new()
	for p in [_left, _right]:
		var tr: TextureRect = p
		tr.custom_minimum_size = Vector2(Display.tile * 2, Display.tile * 2)
		tr.size = tr.custom_minimum_size
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.visible = false
		add_child(tr)
	_left.position = Vector2(8, view.y - Display.tile * 2 - 70)
	_right.position = Vector2(view.x - Display.tile * 2 - 8, view.y - Display.tile * 2 - 70)
	_box = PanelContainer.new()
	_box.position = Vector2(8, view.y - 66)
	_box.custom_minimum_size = Vector2(view.x - _box.position.x * 2, 58)
	_box.visible = false
	add_child(_box)
	var v := VBoxContainer.new()
	_box.add_child(v)
	_name = UiTheme.label("", UiTheme.ACCENT)
	v.add_child(_name)
	_text = UiTheme.label("")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(view.x - 30, 0)
	v.add_child(_text)
	_choices = VBoxContainer.new()
	v.add_child(_choices)
	_skip_btn = UiTheme.button(Strings.t("cutscene.skip"), func() -> void: _skip = true)
	_skip_btn.position = Vector2(view.x - 52, 4)
	_skip_btn.visible = false
	add_child(_skip_btn)


func _input(event: InputEvent) -> void:
	if playing == "":
		return
	# Choice buttons take keys themselves; otherwise keys never reach the scene below.
	if event.is_action_pressed("interact") and _choices.get_child_count() == 0:
		_advance = true
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("cancel"):
		_skip = true
		get_viewport().set_input_as_handled()


func _on_blocker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and _choices.get_child_count() == 0:
		_advance = true
		_blocker.accept_event()


func _process(_delta: float) -> void:
	_fast = playing != "" and Input.is_action_pressed("interact")


## Play a cutscene by id. Returns when it ends (or is skipped). Unknown ids return at once.
func play(id: String, host: Node = null) -> void:
	var c := CS.find(DataDB.all(), id)
	if c.is_empty():
		push_warning("Cutscenes: no cutscene '%s'" % id)
		return
	# One at a time: a cutscene asked for while another plays waits its turn.
	while playing != "":
		await finished
	playing = id
	_skip = false
	_skip_btn.visible = true
	_blocker.visible = true
	get_viewport().gui_release_focus()
	var flags: Dictionary = GameState.run.get("flags", {}) if GameState.has_run() else {}
	await _steps(CS.expand(c.get("steps", []), flags), host, c.get("markers", {}))
	_clear()
	_skip_btn.visible = false
	_blocker.visible = false
	playing = ""
	if GameState.has_run():
		GameState.set_flag("cutscene_seen_" + id)
	finished.emit(id)


func _steps(steps: Array, host: Node, markers: Dictionary) -> void:
	for s in steps:
		var st: Dictionary = s
		match str(st.get("type", "")):
			"say", "narrator", "portrait_talk":
				if not _skip:
					await _say(st)
			"title_card":
				if not _skip:
					_title.text = _line(st)
					_title.visible = true
					await _wait(float(st.get("seconds", 1.6)))
					_title.visible = false
			"choice":
				# Skipping takes the first option; its effects still apply.
				var pick := 0 if _skip else await _choice(st)
				var opt: Dictionary = st.get("options", [])[pick] if not st.get("options", []).is_empty() else {}
				_apply(opt.get("effects", {}))
				var flags: Dictionary = GameState.run.get("flags", {}) if GameState.has_run() else {}
				await _steps(CS.expand(opt.get("steps", []), flags), host, markers)
			"wait":
				if not _skip:
					await _wait(float(st.get("seconds", 0.5)))
			"wait_input":
				if not _skip:
					await _until_advance()
			"fade":
				var target := 1.0 if str(st.get("to", "black")) == "black" else 0.0
				if _skip:
					_fade.color.a = target
				else:
					var tw := create_tween()
					tw.tween_property(_fade, "color:a", target, float(st.get("seconds", 0.4)))
					await tw.finished
			"music":
				Audio.play_music(str(st.get("situation", "")))
			"sfx":
				if not _skip:
					Audio.event(str(st.get("event", "")))
			"image":
				var id := str(st.get("id", ""))
				_image.visible = id != ""
				_image.texture = Assets.texture(id) if id != "" and (Assets.has(id) or Assets.custom_file(id) != "") else null
				# Missing art falls back to a dark backdrop over the current scene.
				_veil.visible = id != "" and _image.texture == null
			"camera_shake":
				var cam := _camera(host)
				if cam != null and not _skip:
					var tw := create_tween()
					var rng := Rng.stream("fx")
					for i in 6:
						tw.tween_property(cam, "offset", Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * float(st.get("amount", 4)), 0.04)
					tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)
					await tw.finished
			"camera_pan":
				var cam := _camera(host)
				var to: Variant = _pos(host, st.get("to", null), markers)
				if cam != null and to != null and not _skip:
					var tw := create_tween()
					tw.tween_property(cam, "global_position", to, float(st.get("seconds", 0.6)))
					await tw.finished
			"move":
				var actor := _actor(host, str(st.get("actor", "")))
				var to: Variant = _pos(host, st.get("to", null), markers)
				if actor != null and to != null:
					if _skip:
						actor.global_position = to
					else:
						var tw := create_tween()
						tw.tween_property(actor, "global_position", to, float(st.get("seconds", 0.6)))
						await tw.finished
			"face":
				var actor := _actor(host, str(st.get("actor", "")))
				if actor != null and actor.has_method("face"):
					actor.call("face", int(st.get("dir", 1)))
			"emote":
				var actor := _actor(host, str(st.get("actor", "")))
				if actor != null and not _skip:
					var l := UiTheme.label(str(st.get("emote", "!")), UiTheme.ACCENT)
					l.theme_type_variation = "OutlinedLabel"
					l.position = Vector2(-4, -Display.tile * 1.5)
					actor.add_child(l)
					await _wait(float(st.get("seconds", 0.8)))
					l.queue_free()
			"set_flag":
				if GameState.has_run():
					GameState.set_flag(str(st.get("flag", "")), st.get("value", true))
			"give":
				_apply(st.get("effects", {}))
			"start_combat":
				# Ends the cutscene and starts the fight (the scene that called comes back after).
				var setup := GameState.combat_setup(st.get("enemies", []), str(st.get("layout", "open_field")), { "intro": _line(st) if st.has("text") or st.has("textKey") else "" })
				_clear()
				GameState.start_combat(setup)
				return


func _apply(fx: Dictionary) -> void:
	if fx.is_empty() or not GameState.has_run():
		return
	for l in Fx.apply(DataDB.all(), GameState.run, fx, Rng.stream("story"), GameState.ctx()):
		Narrator.say(str(l))


func _line(st: Dictionary) -> String:
	return Strings.t(str(st["textKey"])) if st.has("textKey") else str(st.get("text", ""))


func _say(st: Dictionary) -> void:
	var speaker := str(st.get("speaker", "narrator" if str(st.get("type", "")) == "narrator" else ""))
	_box.visible = true
	_name.text = str(DataDB.table("npcs/" + speaker).get("name", speaker.capitalize())) if speaker != "" and speaker != "narrator" else (Strings.t("story.the_narrator") if speaker == "narrator" else "")
	var side := str(st.get("side", "left"))
	_left.visible = false
	_right.visible = false
	var portrait := str(st.get("portrait", "portrait_" + speaker if speaker != "" and speaker != "narrator" else ""))
	if portrait != "" and (Assets.has(portrait) or Assets.custom_file(portrait) != ""):
		var tr := _right if side == "right" else _left
		tr.texture = Assets.texture(portrait)
		tr.visible = true
	if str(st.get("type", "")) == "portrait_talk":
		for pair in [[_left, str(st.get("left", ""))], [_right, str(st.get("right", ""))]]:
			var id := "portrait_" + str(pair[1])
			if str(pair[1]) != "" and (Assets.has(id) or Assets.custom_file(id) != ""):
				(pair[0] as TextureRect).texture = Assets.texture(id)
				(pair[0] as TextureRect).visible = true
	var line := _line(st)
	_text.text = ""
	_advance = false
	var cps := maxf(1.0, float(_settings_speed())) * (20.0 if GameState.dev_autoplay else 1.0)
	var i := 0
	while i < line.length():
		if _skip:
			break
		if _advance:
			_text.text = line
			break
		_text.text = line.substr(0, i + 1)
		if i % 2 == 0 and speaker != "" and line[i] != " ":
			Audio.voice(speaker)
		i += 1
		await get_tree().create_timer(1.0 / (cps * (4.0 if _fast else 1.0))).timeout
	_text.text = line
	_advance = false
	if not _skip:
		await _until_advance()
	_box.visible = false


func _choice(st: Dictionary) -> int:
	_box.visible = true
	_name.text = ""
	_text.text = _line(st) if st.has("text") or st.has("textKey") else ""
	_picked = -1
	var opts: Array = st.get("options", [])
	for i in opts.size():
		var idx := i
		_choices.add_child(UiTheme.button(Strings.t(str(opts[i]["labelKey"])) if opts[i].has("labelKey") else str(opts[i].get("label", "?")), func() -> void: _picked = idx))
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Control).grab_focus()
	while _picked < 0 and not _skip:
		await get_tree().process_frame
	for c in _choices.get_children():
		c.queue_free()
	_box.visible = false
	return maxi(0, _picked)


func _until_advance() -> void:
	_advance = false
	var t := 0.0
	while not _advance and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
		if GameState.dev_autoplay and t > 0.2:
			break


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time() * (4.0 if _fast else 1.0)


func _settings_speed() -> int:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		return int(cfg.get_value("text", "speed", 45))
	return 45


func _clear() -> void:
	_box.visible = false
	_title.visible = false
	_image.visible = false
	_veil.visible = false
	_left.visible = false
	_right.visible = false
	_fade.color.a = 0.0


func _actor(host: Node, id: String) -> Node2D:
	if host != null and host.has_method("cutscene_actor"):
		return host.call("cutscene_actor", id)
	return null


func _camera(host: Node) -> Camera2D:
	if host != null and host.has_method("cutscene_camera"):
		return host.call("cutscene_camera")
	return get_viewport().get_camera_2d()


func _pos(host: Node, to: Variant, markers: Dictionary) -> Variant:
	var where: Variant = markers.get(str(to), to) if to is String else to
	if host != null and host.has_method("cutscene_pos"):
		return host.call("cutscene_pos", where)
	if where is Array and (where as Array).size() == 2:
		return Vector2(float(where[0]) * Display.tile, float(where[1]) * Display.tile)
	return null

## F1 debug menu, available everywhere. Sections are buttons on the left; each
## fills the content area on the right. Debug actions go through GameState and
## the other autoloads like normal play would.
extends CanvasLayer

const CharSheet := preload("res://src/scenes/ui/character_sheet.gd")
const Lv := preload("res://src/core/progression/leveling.gd")

var _root: PanelContainer
var _content: VBoxContainer
var _sections: Array = []


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = PanelContainer.new()
	_root.position = Vector2(4, 4)
	_root.size = Vector2(472, 262)
	_root.visible = false
	add_child(_root)
	var h := HBoxContainer.new()
	_root.add_child(h)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(70, 0)
	h.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	left.add_child(UiTheme.label("DEBUG (F1)", UiTheme.ACCENT))
	add_section("Character", _show_character, left)
	add_section("Leveling", _show_leveling, left)
	add_section("Fights", _show_fights, left)
	add_section("Time", _show_time, left)
	add_section("Stats/Flags", _show_stats, left)
	add_section("Town", _show_town, left)
	add_section("Social", _show_social, left)
	_dev_args.call_deferred()


## Dev hook for screenshots from the command line (after `--`):
##   --scene=res://path.tscn  --debug  --shot=C:/out.png  --frames=30
##   --autoplay (AI plays the party)  --seed=N --class=mage (fresh run first)
##   --jump=week,day_index,part_index  --town=zone:x,y (start position in the town)
## --debug opens this menu; --shot saves the viewport after N frames and quits.
func _dev_args() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := str(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if args.has("autoplay"):
		GameState.dev_autoplay = true
	if args.has("seed"):
		GameState.new_run(int(args["seed"]), str(args.get("class", "mage")))
	if args.has("jump"):
		var j := str(args["jump"]).split(",")
		Calendar.reset({ "week": int(j[0]), "day_index": int(j[1]), "part_index": int(j[2]), "ap": -1 })
		GameState.run["schedule_week"] = int(j[0])
	if args.has("town"):
		var t := str(args["town"]).split(":")
		var xy := t[1].split(",")
		GameState.run["town_pos"] = { "map": t[0], "interior": false, "loc": "", "cell": [int(xy[0]), int(xy[1])] }
	if args.has("fight"):
		GameState.pending_combat = GameState.combat_setup(str(args["fight"]).split(","), str(args.get("layout", "boss_stage")), { "boss": true })
	if args.has("scene"):
		SceneRouter.goto(str(args["scene"]))
	if args.has("talk"):
		for i in 10:
			await get_tree().process_frame
		Social.talk(str(args["talk"]))
	if args.has("debug"):
		toggle.call_deferred()
	if args.has("shot"):
		for i in int(args.get("frames", "30")):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(str(args["shot"]))
		get_tree().quit()


func add_section(title: String, fill: Callable, parent: Control = null) -> void:
	_sections.append({ "title": title, "fill": fill })
	if parent == null:
		parent = _root.get_child(0).get_child(0)
	parent.add_child(UiTheme.button(title, func() -> void: _open(fill)))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.is_action_pressed("cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		if GameState.player.is_empty():
			GameState.new_run()
		_open(_sections[0]["fill"])


func is_open() -> bool:
	return _root.visible


func _open(fill: Callable) -> void:
	for c in _content.get_children():
		c.queue_free()
	fill.call(_content)


func _show_character(box: VBoxContainer) -> void:
	var sheet := CharSheet.new()
	box.add_child(sheet)
	sheet.show_character(GameState.player, GameState.cards)


func _show_leveling(box: VBoxContainer) -> void:
	var p: Dictionary = GameState.player
	box.add_child(UiTheme.label("Level %d, XP %d / %d" % [int(p.get("level", 1)), int(p.get("xp", 0)), Lv.xp_to_next(DataDB.all(), int(p.get("level", 1)))]))
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(UiTheme.button("+1 level", func() -> void:
		var reports := GameState.give_xp("player", Lv.xp_to_next(DataDB.all(), int(GameState.player["level"])) - int(GameState.player["xp"]))
		Narrator.say(_level_text(reports))
		_open(_show_leveling)))
	row.add_child(UiTheme.button("+50 XP", func() -> void:
		Narrator.say(_level_text(GameState.give_xp("player", 50)))
		_open(_show_leveling)))
	for cls in DataDB.table("classes").get("classes", []):
		var cid := str(cls["id"])
		if int(cls.get("tier", 1)) != 1:
			continue
		box.add_child(UiTheme.button("New run as %s (seed 1234)" % cls["name"], func() -> void:
			GameState.new_run(1234, cid)
			_open(_show_character)))
	var pending: Array = p.get("pendingPerks", [])
	if not pending.is_empty():
		box.add_child(UiTheme.label("Choose a perk (level %d):" % int(pending[0]), UiTheme.ACCENT))
		for perk_id in Lv.perk_options(DataDB.all(), p, int(pending[0])):
			var perk: Dictionary = DataDB.record("perks", str(perk_id))
			var pid := str(perk_id)
			box.add_child(UiTheme.button("%s: %s" % [perk.get("name", pid), perk.get("text", "")], func() -> void:
				Lv.choose_perk(DataDB.all(), GameState.player, pid)
				_open(_show_leveling)))


func _level_text(reports: Array) -> String:
	if reports.is_empty():
		return "XP gained."
	var parts: Array = []
	for r in reports:
		var gains: Array = []
		for s in r["stats"]:
			gains.append("%s+%d" % [str(s).to_upper(), int(r["stats"][s])])
		var text := "Level %d: %s" % [int(r["level"]), " ".join(PackedStringArray(gains))]
		if not r["learned"].is_empty():
			text += ", learned " + ", ".join(PackedStringArray(r["learned"]))
		parts.append(text)
	return ". ".join(PackedStringArray(parts))


func _show_fights(box: VBoxContainer) -> void:
	box.add_child(UiTheme.label("Spawn a fight (party: you + roster picks for tonight)", UiTheme.ACCENT))
	var ally_row := HBoxContainer.new()
	box.add_child(ally_row)
	ally_row.add_child(UiTheme.button("Add a debug Fighter ally", func() -> void:
		GameState.add_debug_ally("fighter")
		_open(_show_fights)))
	ally_row.add_child(UiTheme.button("Clear allies", func() -> void:
		GameState.party_ids = []
		_open(_show_fights)))
	box.add_child(UiTheme.label("Party: you%s" % ("" if GameState.party_ids.is_empty() else " + " + ", ".join(PackedStringArray(GameState.party_ids)))))
	var layouts: Array = []
	for l in DataDB.table("rooms/combat_layouts").get("layouts", []):
		layouts.append(str(l["id"]))
	var enemies: Array = []
	for e in DataDB.records_under("enemies/", "enemies"):
		enemies.append(e)
	var groups := [
		["Week 1 trio", ["pom_pom_wisp", "megaphone_mimic", "bleacher_creeper"], "open_field"],
		["Locker hall brawl", ["locker_lurker", "detention_slip", "spirit_stick", "pom_pom_wisp"], "locker_hall"],
		["Elite: Varsity Shade", ["varsity_shade", "pom_pom_wisp"], "bleachers"],
		["Flooded gym", ["megaphone_mimic", "spirit_stick"], "flooded_gym"],
	]
	for g in groups:
		var ids: Array = g[1]
		var lay: String = g[2]
		box.add_child(UiTheme.button("%s (%s)" % [g[0], lay], func() -> void:
			toggle()
			GameState.start_combat(GameState.combat_setup(ids, lay))))
	var bosses: Array = []
	for e in enemies:
		if str(e.get("tier", "")) == "boss":
			bosses.append(e)
	for b in bosses:
		var bid := str(b["id"])
		box.add_child(UiTheme.button("Boss: %s" % b["name"], func() -> void:
			toggle()
			GameState.start_combat(GameState.combat_setup([bid], "boss_stage", { "boss": true }))))
	box.add_child(UiTheme.label("Single enemy:", UiTheme.DIM))
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(380, 0)
	box.add_child(flow)
	for e in enemies:
		var eid := str(e["id"])
		flow.add_child(UiTheme.button(str(e["name"]), func() -> void:
			toggle()
			GameState.start_combat(GameState.combat_setup([eid], "open_field"))))


func _show_time(box: VBoxContainer) -> void:
	box.add_child(UiTheme.label("%s  (AP %d)  seed %d" % [Calendar.label(), Calendar.ap(), GameState.run_seed], UiTheme.ACCENT))
	var r := HBoxContainer.new()
	box.add_child(r)
	r.add_child(UiTheme.button("Advance part", func() -> void:
		toggle()
		GameState.advance_part()))
	r.add_child(UiTheme.button("+5 AP", func() -> void:
		Calendar.set_ap(Calendar.ap() + 5)
		_open(_show_time)))
	box.add_child(UiTheme.label("Jump to (screens for the new part run as usual):", UiTheme.DIM))
	for w in range(1, 6):
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(UiTheme.label("Week %d" % w))
		var days: Array = DataDB.table("calendar").get("days", [])
		for di in days.size():
			var week := w
			var day := di
			row.add_child(UiTheme.button(str(days[di]).capitalize(), func() -> void:
				_jump(week, day, 0)))
	box.add_child(UiTheme.label("Parts of the current day:", UiTheme.DIM))
	var prow := HFlowContainer.new()
	prow.custom_minimum_size = Vector2(380, 0)
	box.add_child(prow)
	var parts: Array = Calendar.logic.parts()
	for pi in parts.size():
		var p := pi
		prow.add_child(UiTheme.button(str(parts[pi].get("name", "")), func() -> void:
			_jump(Calendar.week(), Calendar.logic.day_index, p)))


func _jump(week: int, day: int, part: int) -> void:
	toggle()
	if week != Calendar.week():
		GameState.run["schedule_week"] = 0
	Calendar.reset({ "week": week, "day_index": day, "part_index": part, "ap": -1 })
	Calendar.set_ap(Calendar.max_ap())
	EventBus.part_started.emit()


func _show_stats(box: VBoxContainer) -> void:
	var p: Dictionary = GameState.player
	box.add_child(UiTheme.label("Stats (click +1 / -1)", UiTheme.ACCENT))
	for s in DataDB.table("stats").get("order", []):
		var stat := str(s)
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(UiTheme.label("%s %d" % [stat.to_upper(), int(p["stats"].get(stat, 0))]))
		row.add_child(UiTheme.button("+1", func() -> void:
			GameState.apply_effects({ "stats": { stat: 1 } })
			_open(_show_stats)))
		row.add_child(UiTheme.button("-1", func() -> void:
			GameState.apply_effects({ "stats": { stat: -1 } })
			_open(_show_stats)))
	var mrow := HBoxContainer.new()
	box.add_child(mrow)
	mrow.add_child(UiTheme.button("+$50", func() -> void:
		GameState.apply_effects({ "money": 50 })
		_open(_show_stats)))
	mrow.add_child(UiTheme.button("Full HP/MP", func() -> void:
		preload("res://src/core/character.gd").full_restore(DataDB.all(), GameState.player)
		EventBus.stats_changed.emit("player")
		_open(_show_stats)))
	mrow.add_child(UiTheme.button("Knowledge Tier +1", func() -> void:
		GameState.player["knowledgeTier"] = mini(3, int(GameState.player.get("knowledgeTier", 1)) + 1)
		_open(_show_stats)))
	box.add_child(UiTheme.label("Kelly Risk: %d" % int(GameState.run.get("kelly_risk", 0))))
	var flag_edit := LineEdit.new()
	flag_edit.placeholder_text = "flag name"
	flag_edit.custom_minimum_size = Vector2(160, 0)
	var frow := HBoxContainer.new()
	box.add_child(frow)
	frow.add_child(flag_edit)
	frow.add_child(UiTheme.button("Set flag", func() -> void:
		if flag_edit.text.strip_edges() != "":
			GameState.set_flag(flag_edit.text.strip_edges())
		_open(_show_stats)))
	var flags_l := UiTheme.label("Flags: " + ", ".join(PackedStringArray(GameState.flags.keys())), UiTheme.DIM)
	flags_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flags_l.custom_minimum_size = Vector2(380, 0)
	box.add_child(flags_l)


func _show_town(box: VBoxContainer) -> void:
	box.add_child(UiTheme.label("Go to the town scene at:", UiTheme.ACCENT))
	var places := { "Home (Maple St)": ["residential", 4, 37], "Downtown square": ["downtown", 38, 25], "Gary's Deli door": ["downtown", 21, 14],
		"School front steps": ["school", 29, 14], "Forge": ["outskirts", 41, 13], "Park and woods edge": ["outskirts", 34, 24], "Hillside": ["residential", 28, 7] }
	for name in places:
		var p: Array = places[name]
		box.add_child(UiTheme.button(str(name), func() -> void:
			toggle()
			GameState.run["town_pos"] = { "map": p[0], "interior": false, "loc": "", "cell": [p[1], p[2]] }
			SceneRouter.goto("res://src/scenes/town/town.tscn")))
	box.add_child(UiTheme.button("Unlock all STORY places", func() -> void:
		for l in DataDB.table("town/locations").get("locations", []):
			if l.has("storyFlag"):
				GameState.set_flag(str(l["storyFlag"]))
		_open(_show_town)))


func _show_social(box: VBoxContainer) -> void:
	box.add_child(UiTheme.label("Bonds (click to +20) and recruitment. Kelly Risk: %d" % int(GameState.run.get("kelly_risk", 0)), UiTheme.ACCENT))
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(UiTheme.button("Kelly Risk +1", func() -> void:
		GameState.run["kelly_risk"] = int(GameState.run.get("kelly_risk", 0)) + 1
		_open(_show_social)))
	row.add_child(UiTheme.button("Kelly Risk -1", func() -> void:
		GameState.run["kelly_risk"] = int(GameState.run.get("kelly_risk", 0)) - 1
		_open(_show_social)))
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(380, 0)
	box.add_child(flow)
	for key in DataDB.all():
		if not str(key).begins_with("npcs/"):
			continue
		var rec: Dictionary = DataDB.table(str(key))
		if bool(rec.get("hidden", false)):
			continue
		var id := str(rec["id"])
		flow.add_child(UiTheme.button("%s %d" % [str(rec.get("name", id)).split(" ")[0], roundi(float(GameState.bonds.get(id, 0)))], func() -> void:
			GameState.apply_effects({ "bond": { id: 20 } })
			_open(_show_social)))
	box.add_child(UiTheme.label("Recruit now (ignores Gates):", UiTheme.DIM))
	var rflow := HFlowContainer.new()
	rflow.custom_minimum_size = Vector2(380, 0)
	box.add_child(rflow)
	for key in DataDB.all():
		if str(key).begins_with("npcs/") and bool(DataDB.table(str(key)).get("recruitable", false)):
			var rid := str(DataDB.table(str(key))["id"])
			if GameState.character(rid).is_empty():
				rflow.add_child(UiTheme.button(rid.capitalize(), func() -> void:
					preload("res://src/core/social/bonds.gd").recruit(DataDB.all(), GameState.run, rid, Rng.stream("npc"))
					_open(_show_social)))

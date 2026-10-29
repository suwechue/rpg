## The blacksmith's services (docs/TOWN_LIFE.md Part 4): forge from a recipe
## (a hammer-timing minigame decides the quality), upgrade +0 to +3, infuse a
## Vector, repair broken gear, and commission unique pieces.
extends "res://src/scenes/ui/modal.gd"

const Gear := preload("res://src/core/items/gear.gd")

var tab := "forge"


func _ready() -> void:
	build(Strings.t("smith.title"), Display.base.x * 0.72)
	_refresh()


func _owned_gear() -> Array:
	var out: Array = []
	for id in GameState.run.get("inventory", {}):
		if str(Gear.item(DataDB.all(), str(id)).get("kind", "")) == "equipment":
			out.append(str(id))
	for ch in [GameState.player] + GameState.roster:
		for slot in ch.get("equipment", {}):
			var e: Variant = ch["equipment"][slot]
			if e != null and str(e) != "" and not out.has(str(e)):
				out.append(str(e))
	return out


func _ores(ores: Dictionary) -> String:
	var parts: Array = []
	for o in ores:
		parts.append("%d %s" % [int(ores[o]), str(Gear.item(DataDB.all(), str(o)).get("name", o))])
	return ", ".join(PackedStringArray(parts))


func _refresh() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var run: Dictionary = GameState.run
	var tabs := row()
	for t in ["forge", "upgrade", "infuse", "repair", "commission"]:
		var key: String = t
		var b := UiTheme.button(Strings.t("smith." + key), func() -> void:
			tab = key
			_refresh())
		b.theme_type_variation = "SelectedButton" if key == tab else ""
		tabs.add_child(b)
	match tab:
		"forge":
			for r in Gear.recipes(db, run, Calendar.week()):
				var rec: Dictionary = r
				add_button(Strings.t("smith.recipe") % [str(Gear.item(db, str(rec["item"])).get("name", rec["item"])), int(rec.get("money", 0)), _ores(rec.get("ores", {}))], func() -> void: await _forge(rec))
		"upgrade":
			for id in _owned_gear():
				var iid: String = id
				var lvl := int(Gear.state(run, iid).get("level", 0))
				if lvl < int(Gear.cfg(db).get("upgrade", {}).get("max", 3)):
					add_button(Strings.t("smith.upgrade_row") % [str(Gear.item(db, iid).get("name", iid)), lvl, lvl + 1, Gear.upgrade_cost(db, run, iid)], func() -> void:
						Narrator.say(Strings.t("smith.upgraded") % [str(Gear.item(db, iid).get("name", iid)), lvl + 1] if Gear.upgrade(db, run, iid) == "" else Strings.t("smith.no"))
						_after())
		"infuse":
			var inf: Dictionary = Gear.cfg(db).get("infuse", {})
			for id in _owned_gear():
				var iid: String = id
				for ore in inf.get("ores", {}):
					if int(run.get("inventory", {}).get(str(ore), 0)) <= 0:
						continue
					for v in inf["ores"][ore]:
						var vec := str(v)
						var o := str(ore)
						add_button(Strings.t("smith.infuse_row") % [str(Gear.item(db, iid).get("name", iid)), vec.capitalize(), str(Gear.item(db, o).get("name", o))], func() -> void:
							Narrator.say(Strings.t("smith.infused") % [str(Gear.item(db, iid).get("name", iid)), vec.capitalize()] if Gear.infuse(db, run, iid, vec, o) == "" else Strings.t("smith.no"))
							_after())
		"repair":
			for id in _owned_gear():
				var iid: String = id
				var d := int(Gear.state(run, iid).get("durability", -1))
				if d >= 0 and d < Gear.max_durability(db):
					add_button(Strings.t("smith.repair_row") % [str(Gear.item(db, iid).get("name", iid)), Gear.repair_cost(db, run)], func() -> void:
						Narrator.say(Strings.t("smith.repaired") % str(Gear.item(db, iid).get("name", iid)) if Gear.repair(db, run, iid) == "" else Strings.t("smith.no"))
						_after())
		"commission":
			for c in Gear.commissions(db, run):
				var com: Dictionary = c
				add_button(Strings.t("smith.commission_row") % [str(Gear.item(db, str(com["item"])).get("name", com["item"])), int(com.get("money", 0)), _ores(com.get("ores", {})), int(Gear.cfg(db).get("commissionDays", 2))], func() -> void:
					Narrator.say(Strings.t("smith.ordered") % int(Gear.cfg(db).get("commissionDays", 2)) if Gear.commission(db, run, com, int(run.get("day_count", 0))) == "" else Strings.t("smith.no"))
					_after())
	add_button(Strings.t("smith.close"), func() -> void: finish(null))
	focus_first()


func _after() -> void:
	for ch in [GameState.player] + GameState.roster:
		Gear.refresh(DataDB.all(), GameState.run, ch)
	EventBus.money_changed.emit(GameState.money)
	_refresh()


func _forge(rec: Dictionary) -> void:
	var db: Dictionary = DataDB.all()
	var perf := 1.0
	if not GameState.dev_autoplay:
		var mrec := DataDB.record("minigames", "precision")
		var mg: Control = (load(str(mrec.get("script", "res://src/scenes/minigames/precision_minigame.gd"))) as GDScript).new()
		mg.set("archetype", "precision")
		mg.set("title", Strings.t("smith.forge"))
		mg.set("hint", "")
		visible = false
		get_parent().add_child(mg)
		perf = await mg.finished
		visible = true
	var err := Gear.forge(db, GameState.run, rec, perf)
	var lvl := int(Gear.state(GameState.run, str(rec["item"])).get("level", 0))
	Narrator.say(Strings.t("smith.made") % [str(Gear.item(db, str(rec["item"])).get("name", rec["item"])), Strings.t("gear.level") % lvl if lvl > 0 else ""] if err == "" else Strings.t("smith.no"))
	_after()

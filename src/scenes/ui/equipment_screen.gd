## The Equipment screen (docs/TOWN_LIFE.md Part 4): each member's slots, what
## is equipped (with upgrade level and broken marks), and every owned piece
## that fits, with how it would change their numbers.
extends "res://src/scenes/ui/modal.gd"

const Gear := preload("res://src/core/items/gear.gd")

var who := 0


func _ready() -> void:
	build(Strings.t("gear.title"), Display.base.x * 0.7)
	_refresh()


func _members() -> Array:
	return [GameState.player] + GameState.roster


func _refresh() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var run: Dictionary = GameState.run
	var tabs := row()
	var ms := _members()
	for i in ms.size():
		var idx := i
		var b := UiTheme.button(str(ms[i].get("name", "?")).split(" ")[0], func() -> void:
			who = idx
			_refresh())
		b.theme_type_variation = "SelectedButton" if i == who else ""
		tabs.add_child(b)
	var ch: Dictionary = ms[clampi(who, 0, ms.size() - 1)]
	Gear.refresh(db, run, ch)
	for slot in Gear.slots(db, ch):
		var sl := str(slot)
		var cur: Variant = ch.get("equipment", {}).get(sl)
		var name := Strings.t("gear.empty")
		if cur != null and str(cur) != "":
			var lvl := int(Gear.state(run, str(cur)).get("level", 0))
			name = str(Gear.item(db, str(cur)).get("name", cur)) + (Strings.t("gear.level") % lvl if lvl > 0 else "") + (Strings.t("gear.broken") if Gear.broken(db, run, str(cur)) else "")
		text(Strings.t("gear.row") % [Strings.t("gear.slot_" + sl), name], UiTheme.ACCENT)
		if cur != null and str(cur) != "":
			add_button(Strings.t("gear.unequip") % name, func() -> void:
				Gear.unequip(db, run, ch, sl)
				_refresh(), false, "", str(cur))
		for id in run.get("inventory", {}):
			var it := Gear.item(db, str(id))
			var fits := str(it.get("slot", "")) == sl or (sl == "trinket2" and str(it.get("slot", "")) == "trinket")
			if str(it.get("kind", "")) != "equipment" or not fits or int(run["inventory"][id]) <= 0:
				continue
			var iid := str(id)
			add_button(Strings.t("gear.equip") % [str(it.get("name", iid)), _delta_text(Gear.compare(db, run, ch, iid, sl))], func() -> void:
				Gear.equip(db, run, ch, iid, sl)
				EventBus.stats_changed.emit(str(ch.get("id", "player")))
				_refresh(), false, "", iid)
	add_button(Strings.t("gear.close"), func() -> void: finish(null))
	focus_first()


func _delta_text(d: Dictionary) -> String:
	var parts: Array = []
	for k in [["defense", "gear.def"], ["magicResist", "gear.mr"], ["movement", "gear.mov"], ["strikePower", "gear.pow"]]:
		if int(d.get(k[0], 0)) != 0:
			parts.append(Strings.t(k[1]) % int(d[k[0]]))
	if int(d.get("reach", 0)) > 1:
		parts.append(Strings.t("gear.reach") % int(d["reach"]))
	return ", ".join(PackedStringArray(parts)) if not parts.is_empty() else Strings.t("gear.same")

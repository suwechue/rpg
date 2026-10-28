## Character sheet panel: stats, derived values, Vector affinity bars, known
## Vectors and Forms, perks and deck. Display only; call show_character().
extends PanelContainer

const Char := preload("res://src/core/character.gd")
const CardRules := preload("res://src/core/card.gd")
const VO := preload("res://src/core/vector_ops.gd")
const Lv := preload("res://src/core/progression/leveling.gd")

var _body: HBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(380, 220)
	_body = HBoxContainer.new()
	add_child(_body)


func show_character(ch: Dictionary, library: Dictionary = {}) -> void:
	if _body == null:
		_ready()
	for c in _body.get_children():
		c.queue_free()
	var db: Dictionary = DataDB.all()
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(96, 0)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(124, 0)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(150, 0)
	right.clip_contents = true
	_body.add_child(left)
	_body.add_child(mid)
	_body.add_child(right)

	var cls := Char.class_data(db, str(ch.get("class", "")))
	var d := Char.derived(db, ch)
	var st := Char.effective_stats(db, ch)
	left.add_child(UiTheme.label(str(ch.get("name", "?")), UiTheme.ACCENT))
	left.add_child(UiTheme.label(Strings.t("character_sheet.lv_tier") % [cls.get("name", "?"), int(ch.get("level", 1)), int(ch.get("knowledgeTier", 1))]))
	left.add_child(UiTheme.label(Strings.t("character_sheet.xp") % [int(ch.get("xp", 0)), Lv.xp_to_next(db, int(ch.get("level", 1)))], UiTheme.DIM))
	left.add_child(UiTheme.label(Strings.t("character_sheet.hp_mp") % [int(ch.get("hp", 0)), d["maxHp"], int(ch.get("mp", 0)), d["maxMp"]]))
	for s in Char.stat_order(db):
		var base := int(ch.get("stats", {}).get(s, 0))
		var eff := int(st[s])
		var extra := "" if eff == base else " (%+d)" % (eff - base)
		var sl := UiTheme.label("%s %2d%s" % [str(s).to_upper(), eff, extra])
		sl.tooltip_text = Strings.t("stat_tip." + str(s))
		sl.mouse_filter = Control.MOUSE_FILTER_PASS
		left.add_child(sl)

	mid.add_child(UiTheme.label(Strings.t("character_sheet.derived"), UiTheme.ACCENT))
	for pair in [[Strings.t("character_sheet.move_init") % [d["movement"], d["initiative"]], "stat_tip.movement"],
			[Strings.t("character_sheet.def_mres") % [d["physDefense"], d["magicResist"]], "stat_tip.defense"],
			[Strings.t("character_sheet.stab_crit") % [d["stability"], int(d["critChancePct"])], "stat_tip.crit"],
			[Strings.t("character_sheet.high_crit") % float(d.get("highCritChancePct", 1.0)), "stat_tip.crit"],
			[Strings.t("character_sheet.mp_regen_turn") % d["mpRegen"], "stat_tip.regen"]]:
		var dl := UiTheme.label(str(pair[0]))
		dl.tooltip_text = Strings.t(str(pair[1]))
		dl.mouse_filter = Control.MOUSE_FILTER_PASS
		mid.add_child(dl)
	mid.add_child(UiTheme.label(Strings.t("character_sheet.vector_affinity"), UiTheme.ACCENT))
	var odds := Char.affinity_odds(db, ch)
	for axis in VO.ordered_axes(odds, Char.arcane_axes(db)):
		if not odds.has(axis):
			continue
		var row := HBoxContainer.new()
		var known: bool = ch.get("knownVectors", []).has(axis)
		var name_l := UiTheme.label(("*" if known else " ") + str(axis).capitalize(), UiTheme.TEXT if known else UiTheme.DIM)
		name_l.custom_minimum_size = Vector2(46, 0)
		row.add_child(name_l)
		var bar := ColorRect.new()
		bar.color = UiTheme.vector_color(str(axis))
		bar.custom_minimum_size = Vector2(maxf(1.0, float(odds[axis]) * 120.0), 5)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row.add_child(UiTheme.label("%d%%" % roundi(float(odds[axis]) * 100.0), UiTheme.DIM))
		mid.add_child(row)
	mid.add_child(UiTheme.label(Strings.t("character_sheet.forms") + ", ".join(PackedStringArray(ch.get("knownForms", []))), UiTheme.DIM))

	right.add_child(UiTheme.label(Strings.t("character_sheet.perks"), UiTheme.ACCENT))
	var perk_names: Array = [str(cls.get("perk", {}).get("id", "")).capitalize()]
	for p in ch.get("perks", []):
		perk_names.append(str(DataDB.record("perks", str(p)).get("name", p)))
	var perks_l := UiTheme.label(", ".join(PackedStringArray(perk_names)))
	perks_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perks_l.custom_minimum_size = Vector2(150, 0)
	right.add_child(perks_l)
	right.add_child(UiTheme.label(Strings.t("character_sheet.deck_mp") % ch.get("deck", []).size(), UiTheme.ACCENT))
	var counts := {}
	var order: Array = []
	for id in ch.get("deck", []):
		if not counts.has(id):
			order.append(id)
		counts[id] = int(counts.get(id, 0)) + 1
	for id in order:
		var card := CardRules.resolve(db, str(id), library)
		right.add_child(UiTheme.label("%dx %s %d" % [counts[id], card.get("name", id), CardRules.cost(db, card)]))

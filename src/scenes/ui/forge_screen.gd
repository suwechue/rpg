## The Card Forge (PT Part 5): Fuse, Salvage, Upgrade and Riders, at the
## workbench and arena checkpoints. Shows the Scraps you have and a live
## preview card before anything is confirmed. Each confirmed action costs
## data/forge.json forgeAp (story AP, or Arena AP at checkpoints).
extends "res://src/scenes/ui/modal.gd"

const Forge := preload("res://src/core/progression/forge.gd")
const CardRules := preload("res://src/core/card.gd")
const CardView := preload("res://src/scenes/combat/card_view.gd")

var spend_ap: Callable = func(n: int, kind: String) -> bool: return Calendar.spend_ap(n, kind)
var ap_left: Callable = func() -> int: return Calendar.ap()
var _tab := "fuse"
var _pick: Array = []        # chosen card ids for the current tab
var _rider := ""


func _ready() -> void:
	build(Strings.t("forge.title"), 440)
	_refresh()


func _db() -> Dictionary:
	return DataDB.all()


func _ids() -> Array:
	var out: Array = []
	for id in GameState.run.get("collection", {}):
		if int(GameState.run["collection"][id]) > 0:
			out.append(str(id))
	return out


func _name(id: String) -> String:
	return str(Forge.card(_db(), GameState.run, id).get("name", id))


func _refresh() -> void:
	clear_body()
	var db := _db()
	var tabs := row()
	for t in ["fuse", "salvage", "upgrade", "riders"]:
		var key: String = t
		var b := UiTheme.button(Strings.t("forge.tab_" + key), func() -> void:
			_tab = key
			_pick = []
			_rider = ""
			_refresh())
		b.disabled = key == _tab
		tabs.add_child(b)
	var sc: Array = []
	for k in GameState.run.get("scraps", {}):
		if int(GameState.run["scraps"][k]) > 0:
			sc.append("%s %d" % [str(k).capitalize(), int(GameState.run["scraps"][k])])
	text(Strings.t("forge.scraps") % (", ".join(PackedStringArray(sc)) if not sc.is_empty() else "-"), UiTheme.ACCENT)
	var ap := int(db.get("forge", {}).get("forgeAp", 1))
	match _tab:
		"fuse":
			text(Strings.t("forge.fuse_help"), UiTheme.DIM)
			_card_list(2)
			if _pick.size() == 2:
				var prev := Forge.fuse_preview(db, GameState.run, str(_pick[0]), str(_pick[1]))
				if prev.is_empty():
					text(Forge.fuse_block(db, GameState.run, str(_pick[0]), str(_pick[1])), UiTheme.BAD)
				else:
					_preview(prev)
					add_button(Strings.t("forge.do_fuse") % ap, func() -> void:
						if bool(spend_ap.call(ap, "forge")):
							var made := Forge.fuse(db, GameState.run, str(_pick[0]), str(_pick[1]))
							Audio.event("levelup")
							Narrator.say(Strings.t("forge.made") % str(made.get("name", "")))
							_pick = []
							_refresh(), int(ap_left.call()) < ap)
		"salvage":
			text(Strings.t("forge.salvage_help"), UiTheme.DIM)
			_card_list(1)
			if _pick.size() == 1:
				var gain := Forge.salvage_value(db, Forge.card(db, GameState.run, str(_pick[0])))
				text(Strings.t("forge.salvage_gives") % _cost_text(gain), UiTheme.GOOD)
				add_button(Strings.t("forge.do_salvage"), func() -> void:
					Forge.salvage(db, GameState.run, str(_pick[0]))
					Audio.event("coin")
					_pick = []
					_refresh())
		"upgrade":
			text(Strings.t("forge.upgrade_help"), UiTheme.DIM)
			_card_list(1)
			if _pick.size() == 1:
				var c := Forge.card(db, GameState.run, str(_pick[0]))
				var cost := Forge.upgrade_cost(db, c)
				var up := CardRules.upgraded(c) if c.has("upgrade") else {}
				if not up.is_empty():
					_preview(up)
				text(Strings.t("forge.costs") % _cost_text(cost), UiTheme.TEXT if Forge.can_pay(GameState.run, cost) else UiTheme.BAD)
				add_button(Strings.t("forge.do_upgrade") % ap, func() -> void:
					if bool(spend_ap.call(ap, "forge")):
						var r := Forge.upgrade(db, GameState.run, str(_pick[0]))
						if r.has("error"):
							Narrator.say(str(r["error"]))
						_pick = []
						_refresh(), not Forge.can_pay(GameState.run, cost) or int(ap_left.call()) < ap)
		"riders":
			text(Strings.t("forge.riders_help"), UiTheme.DIM)
			_card_list(1)
			if _pick.size() == 1:
				var c := Forge.card(db, GameState.run, str(_pick[0]))
				text(Strings.t("forge.slots") % [c.get("riders", []).size(), Forge.rider_slots(db, c)], UiTheme.DIM)
				var rr := row()
				for r in db.get("riders", {}).get("riders", []):
					var rid := str(r["id"])
					var b := UiTheme.button(str(r["name"]), func() -> void:
						_rider = rid
						_refresh())
					b.tooltip_text = "%s (+%d MP)" % [str(r["text"]), int(r.get("mp", 1))]
					b.disabled = rid == _rider or Forge.rider_block(db, GameState.run, str(_pick[0]), rid) != ""
					rr.add_child(b)
				if _rider != "":
					var cost := Forge.rider_cost(db, c, _rider)
					var prev := c.duplicate(true)
					prev["riders"] = c.get("riders", []) + [_rider]
					prev["costOverride"] = CardRules.cost(db, c) + int(Forge.riders(db)[_rider].get("mp", 1))
					_preview(prev)
					text(Strings.t("forge.costs") % _cost_text(cost))
					add_button(Strings.t("forge.do_rider") % ap, func() -> void:
						if bool(spend_ap.call(ap, "forge")):
							Forge.add_rider(db, GameState.run, str(_pick[0]), _rider)
							_pick = []
							_rider = ""
							_refresh(), Forge.rider_block(db, GameState.run, str(_pick[0]), _rider) != "" or int(ap_left.call()) < ap)
	add_button(Strings.t("forge.back"), func() -> void: finish(null))
	focus_first()


func _card_list(n: int) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	body.add_child(grid)
	for id in _ids():
		var cid: String = id
		var b := UiTheme.button("%s x%d" % [_name(cid), int(GameState.run["collection"][cid])], func() -> void:
			if _pick.has(cid) and not (n == 2 and _pick.count(cid) < 2 and int(GameState.run["collection"][cid]) >= 2):
				_pick.erase(cid)
			elif _pick.size() < n:
				_pick.append(cid)
			else:
				_pick = [cid]
			_refresh())
		b.tooltip_text = CardRules.describe(_db(), Forge.card(_db(), GameState.run, cid))
		if _pick.has(cid):
			b.text = "> " + b.text
		grid.add_child(b)


func _preview(c: Dictionary) -> void:
	var cv := CardView.new()
	cv.setup(c, CardRules.cost(_db(), c))
	var r := row()
	r.add_child(cv)
	var l := UiTheme.label(CardRules.describe(_db(), c) + ("\n" + Strings.t("forge.riders_list") % ", ".join(PackedStringArray(c.get("riders", []))) if not c.get("riders", []).is_empty() else ""))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	r.add_child(l)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), str(k).capitalize()])
	return ", ".join(PackedStringArray(parts))

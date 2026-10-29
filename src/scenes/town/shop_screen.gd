## A shop visit: buy services, cards and items; sell items; equip gear.
## The 1 AP visit cost is paid before this opens.
extends "res://src/scenes/ui/modal.gd"

const Shop := preload("res://src/core/town/shop.gd")
const Fx := preload("res://src/core/run/effects.gd")

var shop_id := ""
var _note := ""


func _ready() -> void:
	build(str(Shop.shop(DataDB.all(), shop_id).get("name", "Shop")), 400)
	Audio.play_sfx("coin")
	_refresh()


func _refresh() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var s := Shop.shop(db, shop_id)
	text(str(s.get("greeting", "")), UiTheme.DIM)
	text("$%d" % GameState.money, UiTheme.ACCENT)
	if _note != "":
		text(_note, UiTheme.GOOD)
	for e in Shop.stock(db, GameState.run, shop_id, Calendar.week()):
		var entry: Dictionary = e
		var price := Shop.price(db, GameState.run, shop_id, entry)
		var ok := Fx.conditions_met(db, GameState.run, entry.get("cond", {}), {})
		var tip := ""
		if str(entry.get("type", "")) == "item":
			tip = str(Shop.item(db, str(entry["item"])).get("text", ""))
		var label := "$%d  %s" % [price, Shop.entry_name(db, entry)]
		if not ok:
			label += "  (%s)" % entry.get("lockedHint", "locked")
		add_button(label, func() -> void:
			var r := Shop.buy(DataDB.all(), GameState.run, shop_id, entry, Rng.stream("events"))
			_note = " ".join(PackedStringArray(r["lines"]))
			if r["ok"]:
				Audio.play_sfx("coin")
			EventBus.money_changed.emit(GameState.money)
			EventBus.stats_changed.emit("player")
			_refresh(), not ok or price > GameState.money, tip, str(entry.get("item", "")))
	var inv: Dictionary = GameState.run.get("inventory", {})
	if not inv.is_empty():
		text(Strings.t("shop.your_things_click_to_sell"), UiTheme.DIM)
		for id in inv:
			var iid := str(id)
			var it := Shop.item(db, iid)
			if str(it.get("kind", "")) == "equipment":
				add_button(Strings.t("shop.equip") % [it.get("name", iid), it.get("slot", "")], func() -> void:
					# TL Part 4: equip on whom?
					var q := preload("res://src/scenes/ui/modal.gd").new()
					q.build(Strings.t("gear.whom") % str(it.get("name", iid)), Display.base.x * 0.5)
					for who in [GameState.player] + GameState.roster:
						var w: Dictionary = who
						q.add_button(str(w.get("name", "?")), func() -> void: q.finish(w))
					q.add_button(Strings.t("gear.keep"), func() -> void: q.finish(null))
					var target: Variant = await Flow.show_modal(q)
					if target == null:
						return
					_note = Shop.equip(DataDB.all(), GameState.run, target, iid)
					if _note == "":
						_note = Strings.t("shop.equipped_2") % it.get("name", iid)
					EventBus.stats_changed.emit("player")
					_refresh(), false, "", iid)
			add_button(Strings.t("shop.sell_x_for") % [it.get("name", iid), int(inv[id]), Shop.sell_price(db, iid)], func() -> void:
				var got := Shop.sell(DataDB.all(), GameState.run, iid)
				_note = "+$%d" % got
				EventBus.money_changed.emit(GameState.money)
				_refresh())
	add_button(Strings.t("shop.done"), func() -> void: finish(null))
	focus_first()

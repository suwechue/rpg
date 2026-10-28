## Point buy at run start (PT Part 9): +/- per stat, points left, the class
## bonus, derived values that update live (HP, MP, Movement, crit and high crit,
## Stability...), a one-line explanation per stat, Recommended and Random.
## finish() returns the allocation (before the class bonus), or null.
extends "res://src/scenes/ui/modal.gd"

const PB := preload("res://src/core/progression/point_buy.gd")
const Char := preload("res://src/core/character.gd")

var class_id := "mage"
var who := ""                 # a name for the title ("Ash"), or the player
var stats: Dictionary = {}


func _ready() -> void:
	if stats.is_empty():
		stats = PB.recommended(DataDB.all(), class_id)
	build(Strings.t("point_buy.title") % (who if who != "" else Strings.t("point_buy.you")), 420)
	_refresh()


func _refresh() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var bonus: Dictionary = PB.cfg(db).get("classBonus", {}).get(class_id, {})
	text(Strings.t("point_buy.points_left") % [PB.left(db, stats), int(PB.cfg(db).get("points", 20))], UiTheme.ACCENT)
	for s in PB.stat_order(db):
		var stat := str(s)
		var r := row()
		var l := UiTheme.label("%s %2d%s" % [stat.to_upper(), int(stats[stat]), (" +%d" % int(bonus[stat])) if bonus.has(stat) else ""])
		l.custom_minimum_size = Vector2(70, 0)
		r.add_child(l)
		var minus := UiTheme.button("-", func() -> void:
			stats = PB.step(db, stats, stat, -1)
			_refresh())
		minus.disabled = PB.step(db, stats, stat, -1) == stats
		r.add_child(minus)
		var plus := UiTheme.button("+", func() -> void:
			stats = PB.step(db, stats, stat, 1)
			_refresh())
		plus.disabled = PB.step(db, stats, stat, 1) == stats
		r.add_child(plus)
		var tip := UiTheme.label(Strings.t("stat_tip." + stat), UiTheme.DIM)
		r.add_child(tip)
	# Derived values for the final stats, live.
	var ch := Char.create(db, class_id, RandomNumberGenerator.new(), { "stats": PB.final_stats(db, class_id, stats), "knownVectors": [] })
	var d := Char.derived(db, ch)
	text(Strings.t("point_buy.derived") % [int(d["maxHp"]), int(d["maxMp"]), int(d["movement"]), int(d["initiative"]),
		int(d["physDefense"]), int(d["magicResist"]), int(d["stability"]), float(d["critChancePct"]), float(d.get("highCritChancePct", 1.0))], UiTheme.GOOD)
	var br := row()
	br.add_child(UiTheme.button(Strings.t("point_buy.recommended"), func() -> void:
		stats = PB.recommended(db, class_id)
		_refresh()))
	br.add_child(UiTheme.button(Strings.t("point_buy.random"), func() -> void:
		stats = PB.random(db, Rng.stream("ui"))
		_refresh()))
	add_button(Strings.t("point_buy.confirm"), func() -> void: finish(stats), PB.error(db, stats) != "")
	focus_first()

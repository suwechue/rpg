## Local gameplay log (never uploaded): one JSON line per finished in-game day
## in user://gameplay_log.jsonl. See docs/PLAYTEST.md for where to find it.
## Off in headless runs so tests and smoke runs don't fill it.
extends Node

const Log := preload("res://src/core/run/play_log.gd")
var path := "user://gameplay_log.jsonl"

var enabled := true
var _day: Dictionary = {}
var _started_ms := 0


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	EventBus.ap_spent.connect(_on_ap_spent)
	EventBus.combat_finished.connect(_on_combat)
	EventBus.day_part_changed.connect(_on_part)
	EventBus.run_started.connect(func(_s: int) -> void: _flush(); _day = {})
	EventBus.run_ended.connect(func(_c: String) -> void: _flush())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_flush()


func _on_part(week: int, day: String, _part: String) -> void:
	if not _day.is_empty() and int(_day["week"]) == week and str(_day["day"]) == day:
		return
	_flush()
	_day = Log.new_day(week, day)
	_started_ms = Time.get_ticks_msec()


func _on_ap_spent(amount: int, kind: String) -> void:
	if not _day.is_empty():
		Log.add_ap(_day, kind, amount)


func _on_combat(summary: Dictionary) -> void:
	if not _day.is_empty():
		Log.add_fight(_day, str(summary.get("result", "")))


func _flush() -> void:
	if _day.is_empty():
		return
	_day["seconds"] = snappedf((Time.get_ticks_msec() - _started_ms) / 1000.0, 0.1)
	_day["seed"] = int(GameState.run.get("seed", 0)) if not GameState.run.is_empty() else 0
	var rec := _day
	_day = {}
	if not enabled:
		return
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(rec))

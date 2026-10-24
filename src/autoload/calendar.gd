## Calendar autoload: wraps CalendarLogic and announces changes on EventBus.
extends Node

const CalLogic := preload("res://src/core/calendar_logic.gd")

var logic = CalLogic.new({})


func reset(state: Dictionary = {}) -> void:
	logic = CalLogic.new(DataDB.table("calendar"))
	if not state.is_empty():
		logic.load_state(state)
	_announce()


func current_part() -> Dictionary:
	return logic.current_part()


func week() -> int:
	return logic.week


func day_name() -> String:
	return logic.day_name()


func ap() -> int:
	return logic.ap


func max_ap() -> int:
	return logic.max_ap()


func spend_ap(amount: int) -> bool:
	var ok: bool = logic.spend_ap(amount)
	if ok:
		EventBus.ap_changed.emit(logic.ap)
	return ok


func advance_part() -> void:
	logic.advance_part()
	_announce()


func get_state() -> Dictionary:
	return logic.get_state()


func _announce() -> void:
	EventBus.day_part_changed.emit(logic.week, logic.day_name(), logic.part_id())
	EventBus.ap_changed.emit(logic.ap)

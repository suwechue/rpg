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


func part_id() -> String:
	return logic.part_id()


func is_weekend() -> bool:
	return logic.is_weekend()


## Set AP directly (skipping a class turns the period into a free part).
func set_ap(amount: int) -> void:
	logic.ap = maxi(0, amount)
	EventBus.ap_changed.emit(logic.ap)


func label() -> String:
	return Strings.t("calendar.week") % [logic.week, logic.day_name().capitalize(), str(current_part().get("name", ""))]


func max_ap() -> int:
	return logic.max_ap()


## Spend AP. `kind` says what for ("talk", "shop:deli", ...), for the gameplay log.
func spend_ap(amount: int, kind: String = "other") -> bool:
	var ok: bool = logic.spend_ap(amount)
	if ok:
		EventBus.ap_changed.emit(logic.ap)
		EventBus.ap_spent.emit(amount, kind)
	return ok


func advance_part() -> void:
	logic.advance_part()
	_announce()


func get_state() -> Dictionary:
	return logic.get_state()


func _announce() -> void:
	EventBus.day_part_changed.emit(logic.week, logic.day_name(), logic.part_id())
	EventBus.ap_changed.emit(logic.ap)

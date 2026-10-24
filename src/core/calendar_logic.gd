## Pure calendar rules: weeks, days, day parts and Action Points (AP).
## Config comes from data/calendar.json. No nodes, so it runs in tests.
class_name CalendarLogic
extends RefCounted

var config: Dictionary = {}
var week: int = 1
var day_index: int = 0
var part_index: int = 0
var ap: int = 0


func _init(cfg: Dictionary = {}) -> void:
	config = cfg
	_enter_part()


func days() -> Array:
	return config.get("days", ["mon", "tue", "wed", "thu", "fri", "sat", "sun"])


func day_name() -> String:
	return str(days()[day_index])


func is_weekend() -> bool:
	var weekend: Array = config.get("weekendDays", ["sat", "sun"])
	return weekend.has(day_name())


func parts() -> Array:
	if is_weekend():
		return config.get("weekendParts", [])
	return config.get("weekdayParts", [])


func current_part() -> Dictionary:
	var p := parts()
	if p.is_empty():
		return {}
	return p[part_index]


func part_id() -> String:
	return str(current_part().get("id", ""))


func max_ap() -> int:
	return int(current_part().get("ap", 0))


func is_boss_night() -> bool:
	return day_name() == "fri" and bool(current_part().get("dungeon", false))


func is_run_complete() -> bool:
	return week > int(config.get("totalWeeks", 5))


## Spend AP. Returns false (and spends nothing) if there is not enough.
func spend_ap(amount: int) -> bool:
	if amount < 0 or amount > ap:
		return false
	ap -= amount
	return true


## Move to the next day part; leftover AP is lost.
func advance_part() -> void:
	part_index += 1
	if part_index >= parts().size():
		part_index = 0
		day_index += 1
		if day_index >= days().size():
			day_index = 0
			week += 1
	_enter_part()


func get_state() -> Dictionary:
	return { "week": week, "day_index": day_index, "part_index": part_index, "ap": ap }


func load_state(state: Dictionary) -> void:
	week = int(state.get("week", 1))
	day_index = int(state.get("day_index", 0))
	part_index = int(state.get("part_index", 0))
	ap = int(state.get("ap", max_ap()))
	if ap < 0:
		ap = max_ap()


func _enter_part() -> void:
	ap = max_ap()

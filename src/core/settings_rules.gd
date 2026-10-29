## Player settings (ROADMAP M22): the choices the Options screen offers and
## their defaults, from data/ui.json "options". Values live in
## user://settings.cfg; this pure part only knows the choices.
extends RefCounted


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("ui", {}).get("options", {})


## The next value in a list of choices (wraps around).
static func cycle(choices: Array, current: Variant) -> Variant:
	if choices.is_empty():
		return current
	var i := -1
	for k in choices.size():
		if str(choices[k]) == str(current):
			i = k
	return choices[(i + 1) % choices.size()]


## A volume step in dB (clamped to the data's range).
static func step_volume(db: Dictionary, current: float, up: bool) -> float:
	var c := cfg(db)
	var step := float(c.get("volumeStep", 3.0))
	return clampf(current + (step if up else -step), float(c.get("volumeMin", -30.0)), float(c.get("volumeMax", 6.0)))

## Scene transitions between town zones, the dungeon, combat and menus.
extends Node


var _veil: ColorRect


func _ready() -> void:
	# TL Part 7: a black veil over everything that fades out after a scene change
	# or a new day part. Logic never waits on it.
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color.BLACK
	_veil.modulate.a = 0.0
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)
	EventBus.day_part_changed.connect(func(_w: int, _d: String, _p: String) -> void: fade_in(0.35))


func goto(scene_path: String) -> void:
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: cannot open %s (error %d)" % [scene_path, err])
		return
	fade_in(0.3)


## Start black and fade to clear over `seconds` (skipped under autoplay).
func fade_in(seconds: float) -> void:
	if _veil == null or GameState.dev_autoplay:
		return
	_veil.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_veil, "modulate:a", 0.0, seconds)

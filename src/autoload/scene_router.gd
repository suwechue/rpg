## Scene transitions between town zones, the dungeon, combat and menus.
extends Node


func goto(scene_path: String) -> void:
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: cannot open %s (error %d)" % [scene_path, err])

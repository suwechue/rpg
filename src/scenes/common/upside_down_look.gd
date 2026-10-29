## M20: the Upside-Down look on a scene: a full-screen shader layer under the
## UI, tinted toward the week's dominant signature Vector. Numbers in
## data/display.json "upsideDown".
extends RefCounted

const Sig := preload("res://src/core/dungeon/signature.gd")


static func add_to(scene: Node, week: int) -> void:
	var cfg: Dictionary = DataDB.table("display").get("upsideDown", {})
	if not bool(cfg.get("enabled", true)):
		return
	var layer := CanvasLayer.new()
	layer.layer = int(cfg.get("layer", 1))
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/shaders/upside_down.gdshader")
	var axis := Sig.dominant(DataDB.all(), GameState.run, week) if GameState.has_run() else "heat"
	mat.set_shader_parameter("tint", UiTheme.vector_color(axis))
	mat.set_shader_parameter("tint_strength", float(cfg.get("tintStrength", 0.25)))
	mat.set_shader_parameter("wobble", float(cfg.get("wobble", 0.002)))
	mat.set_shader_parameter("vignette", float(cfg.get("vignette", 0.45)))
	rect.material = mat
	layer.add_child(rect)
	scene.add_child(layer)

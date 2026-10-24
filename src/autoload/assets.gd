## Images, sounds and fonts by asset id (data/assets/manifest.json). A file
## dropped in assets/custom/ with the same id replaces the pack version; pack
## art is scaled to its target size; missing art is a labeled magenta
## placeholder, never a crash. `reload()` re-reads assets/custom/ while the
## game runs (F1 > Art).
extends Node

const Spec := preload("res://src/core/assets/asset_specs.gd")

signal reloaded

var custom_root := ""
var override_root := ""         # tests and --custom= use another folder
var _tex: Dictionary = {}       # id -> Texture2D
var _audio: Dictionary = {}     # id -> AudioStream
var _fonts: Dictionary = {}     # id -> Font
var _by_source: Dictionary = {} # pack path -> id (old saves stored paths)


func _ready() -> void:
	_index()


func _index() -> void:
	custom_root = override_root if override_root != "" else str(Spec.manifest(DataDB.all()).get("customRoot", ""))
	_by_source.clear()
	var all: Dictionary = Spec.manifest(DataDB.all()).get("assets", {})
	for id in all:
		var src := str(all[id].get("source", ""))
		if src != "" and not _by_source.has(src):
			_by_source[src] = str(id)


## Forget everything loaded so the next request picks up new custom files.
func reload() -> void:
	_tex.clear()
	_audio.clear()
	_fonts.clear()
	_index()
	reloaded.emit()


## The id for a value that may still be an old pack path (saves from the alpha).
func resolve(id: String) -> String:
	if id.begins_with("res://"):
		return str(_by_source.get(id, id))
	return id


func spec(id: String) -> Dictionary:
	return Spec.spec(DataDB.all(), resolve(id))


func has(id: String) -> bool:
	return not spec(id).is_empty()


func role(name: String) -> String:
	return str(DataDB.table("assets/roles").get(name, ""))


## "custom", "pack" or "missing".
func source(id: String) -> String:
	if custom_file(id) != "":
		return "custom"
	var sp := spec(id)
	if str(sp.get("kind", "")) == "tile":
		return "pack" if source(str(sp.get("tileset", ""))) != "missing" else "missing"
	return "pack" if ResourceLoader.exists(str(sp.get("source", ""))) else "missing"


func custom_file(id: String) -> String:
	var rid := resolve(id)
	var sp := Spec.spec(DataDB.all(), rid)
	if sp.is_empty():
		# Per-card art needs no manifest entry: assets/custom/cards/card_art_<card id>.png.
		if not rid.begins_with("card_art_"):
			return ""
		sp = { "type": "cards", "kind": "image" }
	for p in Spec.custom_candidates(custom_root, sp, rid):
		if FileAccess.file_exists(str(p)):
			return str(p)
	return ""


## The image at its target size (custom, scaled pack, or placeholder).
func image(id: String) -> Image:
	var rid := resolve(id)
	var sp := Spec.spec(DataDB.all(), rid)
	var custom := custom_file(rid)
	if custom != "":
		var img := Image.load_from_file(ProjectSettings.globalize_path(custom))
		if img != null and not img.is_empty():
			return img
	if str(sp.get("kind", "")) == "tile":
		var ts := image(str(sp.get("tileset", "")))
		var t := Display.tile_v()
		var cols := maxi(1, ts.get_width() / t.x)
		var i := int(sp.get("index", 0))
		return ts.get_region(Rect2i(Vector2i((i % cols) * t.x, (i / cols) * t.y), t))
	var src := str(sp.get("source", ""))
	if ResourceLoader.exists(src):
		var tex: Texture2D = load(src)
		if tex != null:
			return Spec.to_target(tex.get_image(), sp)
	var fallback := Display.character if not sp.is_empty() else Display.tile_v()
	return Spec.placeholder(rid, Spec.target_size(sp, fallback))


func texture(id: String) -> Texture2D:
	var rid := resolve(id)
	if _tex.has(rid):
		return _tex[rid]
	var img: Image
	if str(spec(rid).get("kind", "")) == "tileset":
		img = _tileset_image(rid)
	else:
		img = image(rid)
	var tex := ImageTexture.create_from_image(img)
	_tex[rid] = tex
	return tex


## A tileset with every single-tile override blitted into its cell.
func _tileset_image(id: String) -> Image:
	var img := image(id)
	if img.is_compressed():
		img.decompress()
	var tiles := Spec.tiles_of(DataDB.all(), id)
	for index in tiles:
		var tid: String = tiles[index]
		if custom_file(tid) != "":
			var t := Image.load_from_file(ProjectSettings.globalize_path(custom_file(tid)))
			if t != null and not t.is_empty():
				Spec.blit_tile(img, Display.tile_v(), int(index), t)
	return img


## Frame size of a sheet at its target size.
func frame(id: String) -> Vector2i:
	var sp := spec(id)
	if sp.has("frame"):
		var f: Array = sp["frame"]
		return Vector2i(int(f[0]), int(f[1]))
	return Spec.target_size(sp, Display.character)


func stream(id: String) -> AudioStream:
	var rid := resolve(id)
	if _audio.has(rid):
		return _audio[rid]
	var s: AudioStream = null
	var custom := custom_file(rid)
	if custom != "":
		var path := ProjectSettings.globalize_path(custom)
		match custom.get_extension():
			"ogg":
				s = AudioStreamOggVorbis.load_from_file(path)
			"wav":
				s = AudioStreamWAV.load_from_file(path)
			"mp3":
				s = AudioStreamMP3.load_from_file(path)
	if s == null:
		var src := str(spec(rid).get("source", ""))
		if ResourceLoader.exists(src):
			s = load(src)
	_audio[rid] = s
	return s


func font(id: String) -> Font:
	var rid := resolve(id)
	if _fonts.has(rid):
		return _fonts[rid]
	var f: Font = null
	var custom := custom_file(rid)
	if custom != "":
		var ff := FontFile.new()
		if ff.load_dynamic_font(ProjectSettings.globalize_path(custom)) == OK:
			f = ff
	if f == null:
		var src := str(spec(rid).get("source", ""))
		if ResourceLoader.exists(src):
			f = load(src)
	_fonts[rid] = f
	return f


## Every id, grouped by type in manifest order.
func ids_by_type() -> Dictionary:
	var out := {}
	var all: Dictionary = Spec.manifest(DataDB.all()).get("assets", {})
	for g in Spec.manifest(DataDB.all()).get("groups", {}):
		out[str(g)] = []
	for id in all:
		var g := str(all[id].get("type", ""))
		if not out.has(g):
			out[g] = []
		out[g].append(str(id))
	return out

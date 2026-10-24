## M10: display sizes from data, asset ids, overrides and placeholders.
extends "res://tests/suite.gd"

const Spec := preload("res://src/core/assets/asset_specs.gd")

## Literal screen or tile sizes are not allowed in scripts (ROADMAP M10).
const SIZE_LITERALS := "(?<![\\w.])(16|32|480|270|640|360)(\\.0)?(?![\\w.])"


func test_display_matches_project() -> void:
	var d: Dictionary = db()["display"]
	check(int(d["tileSize"]) == 32, "tiles are 32x32")
	check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == int(d["baseWidth"]), "viewport width matches display.json")
	check(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == int(d["baseHeight"]), "viewport height matches display.json")
	check(str(ProjectSettings.get_setting("display/window/stretch/scale_mode")) == "integer", "integer scaling")
	check(int(d["portraitSize"][0]) == 64 and int(d["characterSize"][1]) == 32, "portrait and character sizes")


func test_no_literal_sizes_in_src() -> void:
	var re := RegEx.create_from_string(SIZE_LITERALS)
	var strings := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	var hits: Array = []
	for path in _scripts("res://src"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := strings.sub(lines[i], "\"\"", true).get_slice("#", 0)
			if re.search(code) != null:
				hits.append("%s:%d" % [path, i + 1])
	check(hits.is_empty(), "no literal tile or screen sizes in src/: %s" % str(hits))


func _scripts(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	for d in dir.get_directories():
		out.append_array(_scripts(dir_path.path_join(d)))
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	return out


func test_manifest_is_valid() -> void:
	var errors := Spec.validate(db())
	check(errors.is_empty(), "manifest validates: %s" % str(errors.slice(0, 5)))
	var refs := Spec.referenced_ids(db())
	check(refs.size() > 100, "data names many asset ids (%d)" % refs.size())
	for id in refs:
		check(not str(id).begins_with("res://"), "data uses ids, not pack paths: %s" % id)


func test_data_has_no_pack_paths() -> void:
	var bad: Array = []
	for key in db():
		if str(key) == "assets/manifest":
			continue
		if JSON.stringify(db()[key]).contains("res://assets/"):
			bad.append(key)
	check(bad.is_empty(), "only the manifest points at pack files: %s" % str(bad))


func test_every_npc_and_enemy_has_art() -> void:
	for key in db():
		if str(key).begins_with("npcs/"):
			check(not Spec.spec(db(), str(db()[key].get("sprite", ""))).is_empty(), "%s sprite id listed" % key)
			check(not Spec.spec(db(), str(db()[key].get("portrait", ""))).is_empty(), "%s portrait id listed" % key)


func test_custom_candidates() -> void:
	var sp := Spec.spec(db(), "portrait_kelly")
	var c := Spec.custom_candidates("res://assets/custom", sp, "portrait_kelly")
	check(c[0] == "res://assets/custom/portraits/portrait_kelly.png", "type folder first: %s" % c[0])
	check(c.has("res://assets/custom/portrait_kelly.png"), "the root folder works too")
	var music := Spec.custom_candidates("res://assets/custom", Spec.spec(db(), "music_town"), "music_town")
	check(str(music[0]).ends_with("music/music_town.ogg"), "music looks for .ogg")


func test_pack_art_scales_to_target() -> void:
	var img := Image.create(64, 112, false, Image.FORMAT_RGBA8)
	var out := Spec.to_target(img, { "scale": 2 })
	check(out.get_size() == Vector2i(128, 224), "scale 2 doubles a walk sheet")
	var face := Spec.to_target(Image.create(38, 38, false, Image.FORMAT_RGBA8), { "fit": [64, 64] })
	check(face.get_size() == Vector2i(64, 64), "portraits fit 64x64")
	var walker := Spec.spec(db(), "npc_kelly_walk")
	check(int(walker["frame"][0]) == int(db()["display"]["characterSize"][0]), "walk frames are character-sized")


func test_placeholder_is_labeled_magenta() -> void:
	var img := Spec.placeholder("portrait_kelly", Vector2i(64, 64))
	check(img.get_size() == Vector2i(64, 64), "placeholder at target size")
	check(img.get_pixel(32, 60).is_equal_approx(Spec.PLACEHOLDER), "magenta fill")
	var dark := 0
	for y in range(2, 14):
		for x in range(2, 60):
			if img.get_pixel(x, y) != Spec.PLACEHOLDER:
				dark += 1
	check(dark > 30, "the id is written on it (%d label pixels)" % dark)
	check(Spec.placeholder("x", Vector2i(1, 1)).get_width() >= 4, "tiny sizes still make an image")
	var missing := Spec.target_size({}, Vector2i(32, 32))
	check(missing == Vector2i(32, 32), "unknown ids fall back to the given size")


func test_tile_override_blits_one_cell() -> void:
	var atlas := Image.create(96, 64, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.BLACK)
	var tile := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	tile.fill(Color.RED)
	Spec.blit_tile(atlas, Vector2i(32, 32), 4, tile)
	check(atlas.get_pixel(40, 40) == Color.RED, "index 4 is row 1, column 1")
	check(atlas.get_pixel(5, 5) == Color.BLACK and atlas.get_pixel(70, 40) == Color.BLACK, "other cells untouched")
	var small := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	small.fill(Color.BLUE)
	Spec.blit_tile(atlas, Vector2i(32, 32), 0, small)
	check(atlas.get_pixel(31, 31) == Color.BLUE, "a wrong-sized tile is scaled to fit")


func test_tiles_of_tileset() -> void:
	var t := Spec.tiles_of(db(), "tileset_city")
	check(t.size() > 10, "city tiles have ids (%d)" % t.size())
	check(str(t.get(int(db()["town/styles"]["road"]["h"][0]), "")) == "tile_road_h_top", "the road tile is tile_road_h_top")


func test_assets_doc_lists_every_id() -> void:
	var doc := FileAccess.get_file_as_string("res://docs/ASSETS.md")
	var missing: Array = []
	for id in Spec.manifest(db())["assets"]:
		if not doc.contains("`%s`" % id):
			missing.append(id)
	check(missing.is_empty(), "docs/ASSETS.md lists every asset id (run tools/gen_assets_doc.gd): %s" % str(missing.slice(0, 5)))
	var fresh := preload("res://src/core/assets/asset_doc.gd").render(db(), {})
	check(fresh.contains("| [ ] | `portrait_kelly` | 64x64 |"), "portraits are listed at 64x64")
	check(fresh.contains("| [x] |") == false, "nothing is ticked without a custom file")

## Asset ids (ROADMAP M10): every image, sound and font is named by an id in
## data/assets/manifest.json. This file is the pure part: where a custom
## override would live, how pack art is scaled to its target size, the
## labeled magenta placeholder for missing art, tile overrides blitted into a
## tileset, and which ids the data refers to. The Assets autoload does the
## loading and caching.
extends RefCounted

const IMAGE_EXTS := ["png", "webp", "jpg"]
const AUDIO_EXTS := ["ogg", "wav", "mp3"]
const FONT_EXTS := ["ttf", "otf"]
const PLACEHOLDER := Color(1.0, 0.0, 1.0)

## 3x5 pixel glyphs for placeholder labels: 15 bits, rows top to bottom.
const GLYPHS := {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
	"E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
	"I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
	"Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
	"U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
	"2": "110001010100111", "3": "110001010001110", "4": "101101111001001", "5": "111100110001110",
	"6": "011100111101111", "7": "111001010010010", "8": "111101111101111", "9": "111101111001110",
	"_": "000000000000111", "-": "000000111000000",
}


static func manifest(db: Dictionary) -> Dictionary:
	return db.get("assets/manifest", {})


static func spec(db: Dictionary, id: String) -> Dictionary:
	return manifest(db).get("assets", {}).get(id, {})


static func exts_for(sp: Dictionary) -> Array:
	match str(sp.get("kind", "")):
		"music", "sfx", "ambience":
			return AUDIO_EXTS
		"font":
			return FONT_EXTS
	return IMAGE_EXTS


## Where a replacement for `id` may be dropped, in the order they are tried:
## <root>/<type>/<id>.<ext>, then <root>/<id>.<ext>.
static func custom_candidates(root: String, sp: Dictionary, id: String) -> Array:
	var out: Array = []
	for folder in [str(sp.get("type", "")), ""]:
		for ext in exts_for(sp):
			var dir := root if folder == "" else root.path_join(folder)
			out.append(dir.path_join("%s.%s" % [id, ext]))
	return out


## Pack art at its target size: "fit" resizes to an exact size, "scale"
## multiplies (nearest neighbour, so pixels stay crisp). Custom art is used as-is.
static func to_target(img: Image, sp: Dictionary) -> Image:
	var out := img.duplicate() as Image
	if out.is_compressed():
		out.decompress()
	if sp.has("fit"):
		var f: Array = sp["fit"]
		out.resize(int(f[0]), int(f[1]), Image.INTERPOLATE_NEAREST)
	elif float(sp.get("scale", 1)) != 1.0:
		var s := float(sp["scale"])
		out.resize(roundi(out.get_width() * s), roundi(out.get_height() * s), Image.INTERPOLATE_NEAREST)
	if sp.has("tint"):
		tint_image(out, Color(str(sp["tint"])))
	return out


## Palette swap: multiply every pixel by a color (pack art reused for a new enemy).
static func tint_image(img: Image, tint: Color) -> void:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))


## The size a missing asset's placeholder is drawn at.
static func target_size(sp: Dictionary, fallback: Vector2i) -> Vector2i:
	for key in ["fit", "size", "frame"]:
		if sp.has(key):
			var a: Array = sp[key]
			return Vector2i(int(a[0]), int(a[1]))
	if sp.has("native"):
		var n: Array = sp["native"]
		var s := float(sp.get("scale", 1))
		return Vector2i(roundi(float(n[0]) * s), roundi(float(n[1]) * s))
	return fallback


## Magenta with a dark border and the id written on it (wrapped to fit).
static func placeholder(id: String, size: Vector2i) -> Image:
	var w := maxi(size.x, 4)
	var h := maxi(size.y, 4)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(PLACEHOLDER)
	var dark := Color(0.25, 0.0, 0.25)
	for x in w:
		img.set_pixel(x, 0, dark)
		img.set_pixel(x, h - 1, dark)
	for y in h:
		img.set_pixel(0, y, dark)
		img.set_pixel(w - 1, y, dark)
	var per_line := maxi(1, (w - 2) / 4)
	var text := id.to_upper()
	var y0 := 2
	var i := 0
	while i < text.length() and y0 + 5 <= h - 1:
		var line := text.substr(i, per_line)
		for c in line.length():
			_glyph(img, str(line[c]), 2 + c * 4, y0, dark)
		i += per_line
		y0 += 6
	return img


static func _glyph(img: Image, ch: String, x0: int, y0: int, col: Color) -> void:
	var bits := str(GLYPHS.get(ch, ""))
	for b in bits.length():
		if bits[b] == "1":
			var x := x0 + b % 3
			var y := y0 + b / 3
			if x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)


## Replace one tile of a tileset image (tiles numbered left to right, top to bottom).
static func blit_tile(atlas: Image, tile: Vector2i, index: int, tile_img: Image) -> void:
	var cols := maxi(1, atlas.get_width() / tile.x)
	var src := tile_img
	if src.get_size() != tile:
		src = tile_img.duplicate() as Image
		src.resize(tile.x, tile.y, Image.INTERPOLATE_NEAREST)
	if src.get_format() != atlas.get_format():
		src = src.duplicate() as Image
		src.convert(atlas.get_format())
	atlas.blit_rect(src, Rect2i(Vector2i.ZERO, tile), Vector2i((index % cols) * tile.x, (index / cols) * tile.y))


## Tile ids that override cells of a tileset: index -> tile id.
static func tiles_of(db: Dictionary, tileset_id: String) -> Dictionary:
	var out := {}
	var all: Dictionary = manifest(db).get("assets", {})
	for id in all:
		var sp: Dictionary = all[id]
		if str(sp.get("kind", "")) == "tile" and str(sp.get("tileset", "")) == tileset_id:
			out[int(sp["index"])] = str(id)
	return out


## Every asset id the data refers to (NPC sprites and portraits, enemy sprites,
## tilesets, audio), as id -> where it is used.
static func referenced_ids(db: Dictionary) -> Dictionary:
	var out := {}
	for key in db:
		var k := str(key)
		if k.begins_with("npcs/"):
			for f in ["sprite", "portrait"]:
				if db[key].has(f):
					out[str(db[key][f])] = k
			if db[key].has("voice"):
				out[str(db[key]["voice"].get("id", "voice_default"))] = k + " voice"
		elif k.begins_with("enemies/"):
			for e in db[key].get("enemies", []):
				if e.has("sprite"):
					out[str(e["sprite"])] = "%s %s" % [k, e.get("id", "")]
	for p in db.get("town/styles", {}).get("packs", {}).values():
		out[str(p)] = "town/styles"
	if db.get("dungeon", {}).has("tileset"):
		out[str(db["dungeon"]["tileset"])] = "dungeon"
	for k in db.get("audio", {}).get("music", {}):
		var t: Variant = db["audio"]["music"][k]
		out[str(t.get("id", "") if t is Dictionary else t)] = "audio music %s" % k
	for k in db.get("audio", {}).get("ambience", {}):
		out[str(db["audio"]["ambience"][k])] = "audio ambience %s" % k
	for k in db.get("audio_events", {}).get("events", {}):
		for id in db["audio_events"]["events"][k].get("ids", []):
			out[str(id)] = "audio event %s" % k
	var roles: Dictionary = db.get("assets/roles", {})
	for k in roles:
		if k != "comment":
			out[str(roles[k])] = "assets/roles %s" % k
	_ui_ids(db.get("ui", {}).get("skin", {}), "ui skin", out)
	for s in db.get("ui", {}).get("statuses", {}).values():
		out[str(s.get("icon", ""))] = "ui statuses"
	for k in db.get("ui", {}).get("kindIcons", {}).values():
		out[str(k)] = "ui kindIcons"
	for k in db.get("ui", {}).get("intentIcons", {}).values():
		out[str(k)] = "ui intentIcons"
	for a in db.get("ui", {}).get("affixes", {}).values():
		out[str(a.get("icon", ""))] = "ui affixes"
	return out


## Asset ids inside data/ui.json "skin": strings, and the strings in nested
## records except numbers and layout keys.
static func _ui_ids(v: Variant, where: String, out: Dictionary) -> void:
	if v is String:
		out[str(v)] = where
	elif v is Dictionary:
		for k in v:
			if not str(k) in ["margin", "padding", "artPos", "costPos", "textPos"]:
				_ui_ids(v[k], "%s %s" % [where, k], out)


## Problems with the manifest: unknown kinds, tiles pointing at missing
## tilesets, and data referring to ids that are not listed.
static func validate(db: Dictionary) -> Array:
	var errors: Array = []
	var all: Dictionary = manifest(db).get("assets", {})
	var groups: Dictionary = manifest(db).get("groups", {})
	for id in all:
		var sp: Dictionary = all[id]
		if not groups.has(str(sp.get("type", ""))):
			errors.append("asset %s: unknown type '%s'" % [id, sp.get("type")])
		if str(sp.get("kind", "")) == "tile":
			if str(all.get(str(sp.get("tileset", "")), {}).get("kind", "")) != "tileset":
				errors.append("asset %s: tileset '%s' is not a tileset id" % [id, sp.get("tileset")])
		elif not sp.has("source") and not bool(sp.get("planned", false)):
			errors.append("asset %s: no source" % id)
	var refs := referenced_ids(db)
	for id in refs:
		if not all.has(id):
			errors.append("%s refers to unknown asset id '%s'" % [refs[id], id])
	return errors

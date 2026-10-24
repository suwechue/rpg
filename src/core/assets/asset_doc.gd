## Renders docs/ASSETS.md from the asset manifest: every id grouped by type,
## with its target size, frame layout, anchor, current source and a checkbox
## for "replaced with my art". tools/gen_assets_doc.gd writes the file.
extends RefCounted

const Spec := preload("res://src/core/assets/asset_specs.gd")


## `custom` is id -> custom file path for ids that already have a replacement.
static func render(db: Dictionary, custom: Dictionary) -> String:
	var m := Spec.manifest(db)
	var all: Dictionary = m.get("assets", {})
	var groups: Dictionary = m.get("groups", {})
	var d: Dictionary = db.get("display", {})
	var root := str(m.get("customRoot", "")).trim_prefix("res://")
	var out: Array = []
	out.append("# Assets")
	out.append("")
	out.append("Generated from `data/assets/manifest.json` by `tools/gen_assets_doc.gd`. Don't edit by hand; run the tool again after changing the manifest:")
	out.append("")
	out.append("`& \"<godot>\" --headless --path . -s res://tools/gen_assets_doc.gd`")
	out.append("")
	out.append("## How to replace art")
	out.append("")
	out.append("1. Find the asset below. Its **id** is the file name you'll use.")
	out.append("2. Draw it at the **target size**, with the frame layout shown. Save it as PNG (sounds: OGG or WAV; fonts: TTF or OTF).")
	out.append("3. Put it in `%s/<type>/<id>.png`, for example `%s/portraits/portrait_kelly.png`. Plain `%s/<id>.png` works too." % [root, root, root])
	out.append("4. Run the game. If it's already running, press **F1 > Art > Reload custom art**.")
	out.append("5. Tick the box here so you can see what's left.")
	out.append("")
	out.append("No code or manifest changes are needed. Delete your file to go back to the pack art. If a file is missing or broken the game shows a magenta square with the id written on it instead of crashing.")
	out.append("")
	out.append("Sizes: tiles %dx%d, characters %dx%d (up to %dx%d for tall ones), portraits %dx%d, card art %dx%d, icons %dx%d (UI) or %dx%d (items). The game runs at %dx%d and scales up by whole numbers." % [
		int(d.get("tileSize", 0)), int(d.get("tileSize", 0)), _a(d, "characterSize", 0), _a(d, "characterSize", 1), _a(d, "characterSize", 0), int(_a(d, "characterSize", 1) * 1.5),
		_a(d, "portraitSize", 0), _a(d, "portraitSize", 1), _a(d, "cardArtSize", 0), _a(d, "cardArtSize", 1),
		int(d.get("uiIconSize", 0)), int(d.get("uiIconSize", 0)), int(d.get("itemIconSize", 0)), int(d.get("itemIconSize", 0)),
		int(d.get("baseWidth", 0)), int(d.get("baseHeight", 0))])
	out.append("")
	out.append("Pack art is a placeholder: the 16x16 packs are scaled up 2x (nearest neighbour) to fit the 32x32 grid until you replace them.")
	out.append("")
	var counts: Array = []
	for g in groups:
		var n := 0
		var done := 0
		for id in all:
			if str(all[id].get("type", "")) == str(g):
				n += 1
				if custom.has(id):
					done += 1
		counts.append("%s %d/%d" % [groups[g], done, n])
	out.append("Replaced so far: " + ", ".join(PackedStringArray(counts)) + ".")
	for g in groups:
		var ids: Array = []
		for id in all:
			if str(all[id].get("type", "")) == str(g):
				ids.append(str(id))
		out.append("")
		out.append("## %s (%d)" % [groups[g], ids.size()])
		out.append("")
		if ids.is_empty():
			out.append("None yet.")
			continue
		out.append(_intro(str(g)))
		out.append("")
		out.append("| Done | Id | Target size | Layout | Anchor | Source | Notes |")
		out.append("| --- | --- | --- | --- | --- | --- | --- |")
		for id in ids:
			var sp: Dictionary = all[id]
			var src := "custom" if custom.has(id) else _pack_name(sp, all)
			out.append("| %s | `%s` | %s | %s | %s | %s | %s |" % ["[x]" if custom.has(id) else "[ ]", id, size_text(sp, d),
				str(sp.get("layout", "-")), str(sp.get("anchor", "-")), src, str(sp.get("notes", ""))])
	return "\n".join(PackedStringArray(out)) + "\n"


static func _a(d: Dictionary, key: String, i: int) -> int:
	var a: Array = d.get(key, [0, 0])
	return int(a[i])


static func _intro(group: String) -> String:
	match group:
		"characters", "enemies":
			return "Walk sheets: 4 columns (facing down, up, left, right), 4 rows (the walk cycle), each frame the target size, feet at the bottom center. Bosses are one row of idle frames."
		"tiles":
			return "Single tiles inside a tileset. Replacing one changes it everywhere it's used. Draw it at the tile size; it's pasted into its cell of the tileset."
		"tilesets":
			return "Whole tilesets. Replacing one swaps every tile in it at once (keep the same grid so tile numbers still line up)."
		"portraits":
			return "Faces shown when you talk to someone."
		"music":
			return "Background music; loops."
		"sfx":
			return "Short sound effects."
	return ""


## "32x32 frames (sheet 128x128)", "64x64", or "-" for sounds.
static func size_text(sp: Dictionary, display: Dictionary) -> String:
	var kind := str(sp.get("kind", ""))
	if kind in ["music", "sfx", "font"]:
		return "-"
	if kind == "tile":
		return "%dx%d" % [int(display.get("tileSize", 0)), int(display.get("tileSize", 0))]
	var s := Spec.target_size(sp, Vector2i.ZERO)
	if kind == "walker":
		return "%dx%d frames (sheet %dx%d)" % [s.x, s.y, s.x * 4, s.y * 4]
	if kind == "strip" and sp.has("native"):
		var n: Array = sp["native"]
		var frames := maxi(1, roundi(float(n[0]) * float(sp.get("scale", 1)) / float(s.x)))
		return "%dx%d frames x %d (strip %dx%d)" % [s.x, s.y, frames, s.x * frames, s.y]
	if kind == "tileset" and sp.has("native"):
		var n: Array = sp["native"]
		var sc := float(sp.get("scale", 1))
		return "%dx%d tiles (sheet %dx%d)" % [s.x, s.y, roundi(float(n[0]) * sc), roundi(float(n[1]) * sc)]
	return "%dx%d" % [s.x, s.y]


static func _pack_name(sp: Dictionary, all: Dictionary) -> String:
	if str(sp.get("kind", "")) == "tile":
		return "tile %d of `%s`" % [int(sp.get("index", 0)), sp.get("tileset", "")]
	var src := str(sp.get("source", "")).trim_prefix("res://assets/packs/")
	return "pack: " + src.get_slice("/", 0)

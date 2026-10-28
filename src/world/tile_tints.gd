## Tinted alternative tiles (ROADMAP M12b): every tile gets one alternative
## per tint in data/town/styles.json "roofTints", so a building style can
## reuse the same roof tiles in new colors. Returns { tint name: alternative id }.
extends RefCounted


static func add(ts: TileSet, tints: Dictionary) -> Dictionary:
	var names: Array = tints.keys()
	names.sort()
	var out := {}
	for i in names.size():
		out[str(names[i])] = i + 1
	for si in ts.get_source_count():
		var src := ts.get_source(ts.get_source_id(si)) as TileSetAtlasSource
		if src == null:
			continue
		for ti in src.get_tiles_count():
			var coords := src.get_tile_id(ti)
			for n in names:
				var alt := int(out[n])
				if not src.has_alternative_tile(coords, alt):
					src.create_alternative_tile(coords, alt)
				src.get_tile_data(coords, alt).modulate = Color(str(tints[n]))
	return out

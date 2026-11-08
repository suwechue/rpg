## The Lab Tuner's shortlist as presets (docs/LAB_TUNER.md Part 4): tuned_1 to
## tuned_5 in data/lab/presets.json, marked "generated", each with a one-line
## summary of what sets it apart. Rewrites only the generated entries.
extends RefCounted

const Rules := preload("res://src/core/combat/rules.gd")
const Sweep := preload("res://src/core/lab/sweep.gd")
const PREFIX := "tuned_"


static func lever_name(db: Dictionary, id: String) -> String:
	for s in Rules.lever_specs(db):
		if str(s["id"]) == id:
			return str(s.get("name", id))
	return id


## "Fog on, Enemy damage x 1.5": the levers a set changes, in words.
static func describe(db: Dictionary, levers: Dictionary) -> String:
	var keys: Array = levers.keys()
	keys.sort()
	var parts: Array = []
	for k in keys:
		var v: Variant = levers[k]
		var nm := lever_name(db, str(k))
		if typeof(v) == TYPE_BOOL:
			parts.append("%s %s" % [nm, "on" if bool(v) else "off"])
		else:
			parts.append("%s %s" % [nm, Sweep.norm(v)])
	return ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "no changes"


## Preset records for a shortlist ([{ levers, score, ... }]) on top of a base preset.
static func presets_for(db: Dictionary, base: String, short: Array) -> Array:
	var base_rec := Rules.preset_rec(db, base)
	var out: Array = []
	for i in short.size():
		var s: Dictionary = short[i]
		var lv: Dictionary = base_rec.get("levers", {}).duplicate()
		lv.merge(s["levers"], true)
		var rec := { "id": PREFIX + str(i + 1), "name": "Tuned %d" % (i + 1), "generated": true, "base": base,
			"text": "%s plus: %s." % [str(base_rec.get("name", base)), describe(db, s["levers"])], "score": s.get("score", 0.0), "levers": lv }
		if base_rec.has("fromGame"):
			rec["fromGame"] = base_rec["fromGame"]
		out.append(rec)
	return out


## The presets file with its generated entries replaced by these.
static func write(text: String, presets: Array) -> String:
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return text
	var kept: Array = (data.get("presets", []) as Array).filter(func(p: Dictionary) -> bool: return not bool(p.get("generated", false)))
	var lines: Array = []
	for p in kept:
		lines.append(_entry(text, str(p["id"])))
	for p in presets:
		lines.append(_indent(JSON.stringify(p, "  "), "    "))
	var head := text.substr(0, text.find("\"presets\""))
	return head + "\"presets\": [\n" + ",\n".join(PackedStringArray(lines)) + "\n  ]\n}\n"


## A hand-written preset's own text, as it is in the file.
static func _entry(text: String, id: String) -> String:
	var at := text.find("\"id\": \"%s\"" % id)
	var start := text.rfind("{", at)
	var depth := 0
	var i := start
	while i < text.length():
		var ch := text[i]
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				break
		i += 1
	var line_start := text.rfind("\n", start) + 1
	return text.substr(line_start, i + 1 - line_start)


static func _indent(s: String, pad: String) -> String:
	var rows := s.split("\n")
	for i in rows.size():
		rows[i] = pad + rows[i]
	return "\n".join(rows)

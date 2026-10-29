## Cutscenes (ROADMAP M14, pulled forward by docs/PATCH_2.md Part 3): data in
## data/cutscenes/*.json, each { "id", "steps": [...], "markers": { name: [x, y] } }.
## This pure part finds cutscenes, expands branches against the run's flags and
## validates steps; the Cutscenes autoload plays them. See docs/CUTSCENE_GUIDE.md.
extends RefCounted

const DT := preload("res://src/core/data_tables.gd")

## Every step type the player understands.
const STEPS := ["say", "narrator", "portrait_talk", "title_card", "choice", "if_flag", "wait", "wait_input", "fade", "music", "sfx",
	"image", "camera_shake", "camera_pan", "move", "face", "emote", "set_flag", "give", "start_combat", "seating"]


static func all(db: Dictionary) -> Array:
	return DT.records_under(db, "cutscenes/", "cutscenes")


static func find(db: Dictionary, id: String) -> Dictionary:
	for c in all(db):
		if str(c.get("id", "")) == id:
			return c
	return {}


## The steps that will play for this run: if_flag branches are resolved now
## (choices branch while playing, since they depend on the answer).
static func expand(steps: Array, flags: Dictionary) -> Array:
	var out: Array = []
	for s in steps:
		var st: Dictionary = s
		if str(st.get("type", "")) == "if_flag":
			var on := bool(flags.get(str(st.get("flag", "")), false))
			out.append_array(expand(st.get("then" if on else "else", []), flags))
		else:
			out.append(st)
	return out


## Problems in a cutscene, as readable lines (DataDB and the tests use this).
static func problems(db: Dictionary, c: Dictionary) -> Array:
	var out: Array = []
	_check_steps(c.get("steps", []), str(c.get("id", "?")), c.get("markers", {}), out)
	return out


static func _check_steps(steps: Array, id: String, markers: Dictionary, out: Array) -> void:
	for s in steps:
		var st: Dictionary = s
		var t := str(st.get("type", ""))
		if not STEPS.has(t):
			out.append("cutscene %s: unknown step '%s'" % [id, t])
			continue
		if t in ["say", "narrator", "portrait_talk", "title_card"] and not (st.has("text") or st.has("textKey")):
			out.append("cutscene %s: %s needs text or textKey" % [id, t])
		if t == "move" and st.get("to", null) is String and not markers.has(str(st["to"])):
			out.append("cutscene %s: move to unknown marker '%s'" % [id, st["to"]])
		if t == "if_flag":
			_check_steps(st.get("then", []), id, markers, out)
			_check_steps(st.get("else", []), id, markers, out)
		if t == "choice":
			for o in st.get("options", []):
				_check_steps(o.get("steps", []), id, markers, out)

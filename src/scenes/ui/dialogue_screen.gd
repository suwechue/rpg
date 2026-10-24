## Talking to someone: portrait, name, Bond tier, and what they say.
## M6 adds topics, gifts, hangouts and recruitment through `extra_options`.
extends "res://src/scenes/ui/modal.gd"

const VO := preload("res://src/core/vector_ops.gd")

static var extra_options: Array = []   # Callables(npc_id) -> [{ "label", "run": Callable, "disabled" }]

var npc_id := ""
var opts: Dictionary = {}
var _portrait: TextureRect


func _ready() -> void:
	var rec: Dictionary = DataDB.table("npcs/" + npc_id)
	build(str(rec.get("name", npc_id)), 400)
	_menu()


func header() -> void:
	var rec: Dictionary = DataDB.table("npcs/" + npc_id)
	var r := row()
	_portrait = TextureRect.new()
	var path := str(rec.get("portrait", ""))
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
	_portrait.custom_minimum_size = Vector2(38, 38)
	r.add_child(_portrait)
	var bond := float(GameState.bonds.get(npc_id, 0.0))
	var tier := VO.gate_tier(bond, DataDB.table("bonds").get("tiers", []))
	var info := UiTheme.label("%s\nBond %d (%s)" % [rec.get("role", ""), roundi(bond), tier], UiTheme.DIM)
	r.add_child(info)


func _menu() -> void:
	clear_body()
	header()
	var rec: Dictionary = DataDB.table("npcs/" + npc_id)
	text("\"%s\"" % str(rec.get("greeting", "...")))
	for hook in extra_options:
		for o in hook.call(npc_id):
			var opt: Dictionary = o
			add_button(str(opt["label"]), func() -> void: await opt["run"].call(self), bool(opt.get("disabled", false)), str(opt.get("tip", "")))
	add_button("Bye", func() -> void: finish(null))
	focus_first()


## Called by option handlers to show a result and come back to the menu.
func show_result(lines: Array) -> void:
	clear_body()
	header()
	for l in lines:
		text(str(l))
	add_button("Continue", _menu)
	focus_first()

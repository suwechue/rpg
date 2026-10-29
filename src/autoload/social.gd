## Conversations with NPCs. talk() opens the dialogue screen for a person; the
## rules (topics, Gates, reception, misinterpretation, Bonds) live in
## src/core/social/. Await talk() from scenes.
extends Node

const DialogueScreen := preload("res://src/scenes/ui/dialogue_screen.gd")
const Truancy := preload("res://src/core/town/truancy.gd")


func talk(npc_id: String, opts: Dictionary = {}) -> void:
	var rec: Dictionary = DataDB.table("npcs/" + npc_id)
	if rec.is_empty():
		return
	# TL Part 5: a school-hours townsperson's scene, the first time you meet them while skipping.
	var scene := Truancy.daytime_scene(DataDB.all(), GameState.run, rec, Calendar.part_id())
	if scene != "":
		await Cutscenes.play(scene, get_tree().current_scene)
	var st: Dictionary = GameState.run["npcs"].get(npc_id, {})
	if not st.is_empty():
		st["met"] = true
	var s := DialogueScreen.new()
	s.npc_id = npc_id
	s.opts = opts
	await Flow.show_modal(s)
	EventBus.stats_changed.emit("player")

## The narrator: comments on everything, and is also a character with a Bond.
## Their tone (sarcastic, dry, warm) follows that Bond (data/narrator.json).
extends Node

signal line_said(text: String)

const VO := preload("res://src/core/vector_ops.gd")

var last_line := ""
var history: Array[String] = []


func say(text: String) -> void:
	last_line = text
	history.append(text)
	if history.size() > 200:
		history.remove_at(0)
	line_said.emit(text)
	print("[Narrator] ", text)


## sarcastic, dry or warm, from your Bond with the narrator.
func tone() -> String:
	var bond := 0.0
	if GameState.has_run():
		bond = float(GameState.bonds.get("narrator", 0.0))
	var tier := VO.gate_tier(bond, DataDB.table("bonds").get("tiers", []))
	return str(DataDB.table("narrator").get("tiers", {}).get(tier, "dry"))


## A line for a situation in the narrator's current tone (seeded pick).
func line(key: String) -> String:
	var lines: Dictionary = DataDB.table("narrator").get("lines", {}).get(key, {})
	var pool: Array = lines.get(tone(), lines.get("dry", []))
	if pool.is_empty():
		return ""
	return str(pool[Rng.stream("dialogue").randi_range(0, pool.size() - 1)])


## Say a situational line.
func react(key: String) -> String:
	var l := line(key)
	if l != "":
		say(l)
	return l

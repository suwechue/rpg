## The narrator: a character who comments on everything. For now, a line queue
## that the HUD displays. Later: portraits, Bond-based tone, typed text.
extends Node

signal line_said(text: String)

var last_line := ""
var history: Array[String] = []


func say(text: String) -> void:
	last_line = text
	history.append(text)
	line_said.emit(text)
	print("[Narrator] ", text)

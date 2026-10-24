## Registers the input map in code (keyboard + controller) so it is easy to read
## and edit. Actions: move_up/down/left/right, interact, end_part, cancel, pause,
## save_run, load_run, debug_menu.
extends Node

const KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E, KEY_ENTER],
	"end_part": [KEY_SPACE],
	"cancel": [KEY_ESCAPE, KEY_BACKSPACE],
	"pause": [KEY_P],
	"save_run": [KEY_F5],
	"load_run": [KEY_F9],
	"debug_menu": [KEY_F1],
}

const PAD_BUTTONS := {
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"interact": [JOY_BUTTON_A],
	"cancel": [JOY_BUTTON_B],
	"end_part": [JOY_BUTTON_Y],
	"pause": [JOY_BUTTON_START],
}


func _ready() -> void:
	for action in KEYS:
		_ensure(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in PAD_BUTTONS:
		_ensure(action)
		for button in PAD_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

## Registers the input map in code (keyboard + controller) so it is easy to read
## and edit. Actions: move_up/down/left/right, interact, end_part, cancel, pause,
## save_run, load_run, debug_menu, card_prev/card_next (highlight a card in
## combat), fast_forward (hold to speed up enemy turns), threat_view (hold to
## shade every combat tile by incoming damage).
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
	"feedback": [KEY_F8],
	"card_prev": [KEY_Q],
	"card_next": [KEY_TAB],
	"fast_forward": [KEY_SHIFT],
	"threat_view": [KEY_T],
	"goals": [KEY_G],
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
	"card_prev": [JOY_BUTTON_LEFT_SHOULDER],
	"card_next": [JOY_BUTTON_RIGHT_SHOULDER],
	"fast_forward": [JOY_BUTTON_X],
	"threat_view": [JOY_BUTTON_LEFT_STICK],
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


	_load_rebinds()


## M22: keys the player rebound in Options (user://settings.cfg "keys").
func _load_rebinds() -> void:
	var c := ConfigFile.new()
	if c.load("user://settings.cfg") != OK or not c.has_section("keys"):
		return
	for action in c.get_section_keys("keys"):
		rebind(str(action), int(c.get_value("keys", action, 0)), false)


## Replace an action's keyboard keys with one key (controller buttons stay).
func rebind(action: String, keycode: int, save: bool = true) -> void:
	if not InputMap.has_action(action) or keycode == 0:
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var k := InputEventKey.new()
	k.physical_keycode = keycode as Key
	InputMap.action_add_event(action, k)
	if save:
		var c := ConfigFile.new()
		c.load("user://settings.cfg")
		c.set_value("keys", action, keycode)
		c.save("user://settings.cfg")


## The first key bound to an action, as text ("E").
func key_text(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "-"


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

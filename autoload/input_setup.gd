extends Node

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_W, KEY_UP, KEY_SPACE],
	"attack": [KEY_J, KEY_Z],
	"heavy_attack": [KEY_K, KEY_X],
	"special": [KEY_L, KEY_C],
	"block": [KEY_Q],
}

const JOY_BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"jump": [JOY_BUTTON_A, JOY_BUTTON_DPAD_UP],
	"attack": [JOY_BUTTON_X],
	"heavy_attack": [JOY_BUTTON_Y],
	"special": [JOY_BUTTON_RIGHT_SHOULDER],
	"block": [JOY_BUTTON_LEFT_SHOULDER],
}

const JOY_TRIGGERS := {
	"special": [JOY_AXIS_TRIGGER_RIGHT],
	"block": [JOY_AXIS_TRIGGER_LEFT],
}

const JOY_AXES := {
	"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
}

const JOY_UI := {
	"ui_accept": [JOY_BUTTON_A],
	"ui_cancel": [JOY_BUTTON_START],
}


func _ready() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_set_deadzone(action, 0.25)
		for key: Key in ACTIONS[action]:
			_add_key(action, key)
		for button: JoyButton in JOY_BUTTONS.get(action, []):
			_add_button(action, button)
		for axis: JoyAxis in JOY_TRIGGERS.get(action, []):
			_add_axis(action, axis, 1.0)
		for pair: Array in JOY_AXES.get(action, []):
			_add_axis(action, pair[0], pair[1])
	for ui_action: String in JOY_UI:
		for button: JoyButton in JOY_UI[ui_action]:
			_add_button(ui_action, button)


func _add_key(action: String, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _add_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

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


func _ready() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
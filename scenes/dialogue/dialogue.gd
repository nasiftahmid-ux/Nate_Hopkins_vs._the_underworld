extends CanvasLayer

var idx := 0

@onready var speaker_label: Label = $Panel/Speaker
@onready var text_label: Label = $Panel/Text
@onready var hint_label: Label = $Panel/Hint


func _ready() -> void:
	show_line()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		advance()


		get_viewport().set_input_as_handled()


func show_line() -> void:
	if idx >= GameState.dialogue_lines.size():
		return
	var line: Dictionary = GameState.dialogue_lines[idx]
	speaker_label.text = str(line.get("speaker", ""))
	text_label.text = str(line.get("text", ""))
	hint_label.visible = idx < GameState.dialogue_lines.size() - 1


func advance() -> void:
	idx += 1
	if idx >= GameState.dialogue_lines.size():
		var next := GameState.scene_after_dialogue
		if next == "":
			get_tree().quit()
		else:
			get_tree().change_scene_to_file(next)
	else:
		show_line()

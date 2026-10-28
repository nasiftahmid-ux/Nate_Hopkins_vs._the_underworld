extends CanvasLayer

var idx := 0

@onready var speaker_label: Label = $Panel/Speaker
@onready var text_label: Label = $Panel/Text
@onready var hint_label: Label = $Panel/Hint


func _ready() -> void:
	GameState.clock_running = false
	show_line()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


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
		if GameState.pending_completion:
			GameState.pending_completion = false
			if GameState.active_slot >= 0 and not GameState.sandbox:
				var d := {}
				var f := FileAccess.open(GameState.slot_path(GameState.active_slot), FileAccess.READ)
				if f:
					var p = JSON.parse_string(f.get_as_text())
					f.close()
					if p is Dictionary:
						d = p
				if d.is_empty():
					d = GameState._default_slot_data("Nate")
				d["completed"] = true
				d["best_score"] = GameState.best_score
				d["heartbreak"] = GameState.heartbreak
				GameState._atomic_write_slot(GameState.active_slot, d)
			GameState.show_completion_panel = true
			GameState.clock_running = true
			get_tree().change_scene_to_file("res://scenes/ui/main.tscn")
			return
		if next == "":
			get_tree().quit()
		else:
			GameState.clock_running = true
			get_tree().change_scene_to_file(next)
	else:
		show_line()

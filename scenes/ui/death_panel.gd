extends CanvasLayer

@onready var restart_level_button: Button = $Center/VBox/RestartLevelButton
@onready var restart_game_button: Button = $Center/VBox/RestartGameButton


func _ready() -> void:
	get_tree().paused = true
	restart_level_button.text = "AGAIN"
	restart_game_button.text = "MENU"
	restart_level_button.pressed.connect(_on_again)
	restart_game_button.pressed.connect(_on_menu)
	restart_level_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_again()


func _on_again() -> void:
	GameState.start_new_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.RUN_ROUTE[0])


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main.tscn")

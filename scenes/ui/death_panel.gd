extends CanvasLayer

@onready var restart_level_button: Button = $Center/VBox/RestartLevelButton
@onready var restart_game_button: Button = $Center/VBox/RestartGameButton


func _ready() -> void:
	get_tree().paused = true
	restart_level_button.pressed.connect(_on_restart_level)
	restart_game_button.pressed.connect(_on_restart_game)
	restart_level_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_restart_level()


func _on_restart_level() -> void:
	GameState.player_health = GameState.player_max_hp
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_restart_game() -> void:
	GameState.new_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main.tscn")

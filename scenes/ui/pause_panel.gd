extends CanvasLayer

@onready var resume_button: Button = $Center/VBox/ResumeButton
@onready var restart_button: Button = $Center/VBox/RestartButton
@onready var quit_button: Button = $Center/VBox/QuitButton

var paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	quit_button.pressed.connect(_on_quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _can_pause():
		get_viewport().set_input_as_handled()
		_toggle_pause()


func _can_pause() -> bool:
	var scene := get_tree().current_scene
	if scene == null or scene.name == "Main":
		return false
	if scene.has_node("DeathPanel"):
		return false
	return true


func _toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	visible = paused
	if paused:
		resume_button.grab_focus()


func _on_resume() -> void:
	paused = false
	get_tree().paused = false
	visible = false


func _on_restart() -> void:
	GameState.player_health = GameState.player_max_hp
	paused = false
	get_tree().paused = false
	visible = false
	get_tree().reload_current_scene()


func _on_quit() -> void:
	paused = false
	get_tree().paused = false
	visible = false
	GameState.new_game()
	get_tree().change_scene_to_file("res://scenes/ui/main.tscn")
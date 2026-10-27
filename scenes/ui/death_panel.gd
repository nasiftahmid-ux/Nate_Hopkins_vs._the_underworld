extends CanvasLayer

@onready var restart_level_button: Button = $Center/VBox/RestartLevelButton
@onready var restart_game_button: Button = $Center/VBox/RestartGameButton


func _ready() -> void:
	get_tree().paused = true
	restart_level_button.text = "AGAIN"
	restart_game_button.text = "MENU"
	# Results summary
	var score := GameState.calculate_run_score()
	var score_label := Label.new()
	score_label.text = "SCORE: %d" % score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Center/VBox.add_child(score_label)
	var best_label := Label.new()
	if score >= GameState.best_score and score > 0:
		best_label.text = "NEW BEST!"
	else:
		best_label.text = "BEST: %d" % GameState.best_score
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Center/VBox.add_child(best_label)
	var grade_label := Label.new()
	grade_label.text = "GRADE: %s" % GameState.grade_id()
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Center/VBox.add_child(grade_label)
	var rooms_label := Label.new()
	rooms_label.text = "ROOMS: %d" % GameState.rooms_cleared
	rooms_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Center/VBox.add_child(rooms_label)
	# move buttons after? They are already in tree; labels appended after buttons. Reorder not critical.
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

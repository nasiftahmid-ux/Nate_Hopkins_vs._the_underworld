extends CanvasLayer

@onready var restart_level_button: Button = $Center/VBox/RestartLevelButton
@onready var restart_game_button: Button = $Center/VBox/RestartGameButton


func _ready() -> void:
	get_tree().paused = true
	restart_level_button.text = "AGAIN"
	restart_game_button.text = "MENU"
	var score := GameState.calculate_run_score()
	var hb := GameState.payout_heartbreak(false)
	var vbox := $Center/VBox
	var score_label := Label.new()
	score_label.text = "SCORE: %d" % score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_label)
	var best_label := Label.new()
	best_label.text = "BEST: %d" % GameState.best_score
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(best_label)
	var grade_label := Label.new()
	grade_label.text = "GRADE: %s" % GameState.grade_id()
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(grade_label)
	var rooms_label := Label.new()
	rooms_label.text = "ENDED IN ROOM %d OF 3" % (GameState.rooms_cleared + 1)
	rooms_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rooms_label)
	var hb_label := Label.new()
	hb_label.text = "+%d HEARTBREAK" % hb
	hb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hb_label)
	var visits_label := Label.new()
	visits_label.text = "NEGATIVE VISITS: %d" % GameState.negative_visits
	visits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(visits_label)
	var roasts := [
		""You fought like a man apologizing with his fists."",
		""The Underworld will miss you. Briefly."",
		""Try not to die next time. It's unbecoming."",
		""I've seen better from a haunted toaster."",
		""At least you're consistent."",
		""Love is a battlefield. You lost."",
		""Next time, bring snacks."",
		""Aphrodite is not impressed. Aphrodite is never impressed."",
	]
	var roast := roasts[GameState.rooms_cleared % roasts.size()]
	var roast_label := Label.new()
	roast_label.text = roast
	roast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(roast_label)
	var upg_btn := Button.new()
	upg_btn.text = "BUY +5s START (%d HB)" % GameState.perm_upgrade_price()
	upg_btn.pressed.connect(_on_buy_upgrade)
	vbox.add_child(upg_btn)
	restart_level_button.pressed.connect(_on_again)
	restart_game_button.pressed.connect(_on_menu)
	restart_level_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_again()


func _on_buy_upgrade() -> void:
	if GameState.buy_perm_upgrade():
		pass


func _on_again() -> void:
	GameState.start_new_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.RUN_ROUTE[0])


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main.tscn")

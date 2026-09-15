extends Control

@onready var start_button: Button = $Center/VBox/StartButton
@onready var quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	GameState.new_game()
	start_button.grab_focus()
	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(func() -> void: get_tree().quit())


func _on_start() -> void:
	GameState.dialogue_lines = [
		{"speaker": "Narrator", "text": "A Friday night. Another party. Another chance for Nate Jacobs to make questionable life decisions."},
		{"speaker": "Nate", "text": "Hey Tracy, who's that girl? The one by the punch bowl."},
		{"speaker": "Tracy", "text": "Absolutely not. Last girl I set you up with? You broke her heart in the most brutal way possible."},
		{"speaker": "Tracy", "text": "I'm done playing matchmaker. You can figure this one out yourself."},
		{"speaker": "Nate", "text": "Fine. I'll find out myself."},
		{"speaker": "Hazel", "text": "Hi, I'm Hazel Abegnile Frye. You look like you just lost an argument."},
		{"speaker": "Nate", "text": "Nate Jacobs. And I never lose. Usually."},
		{"speaker": "Nate", "text": "So what brings you here, Hazel?"},
		{"speaker": "Aphrodite", "text": "NATE JACOBS."},
		{"speaker": "Aphrodite", "text": "Last time, your heart was broken and you swore you'd never fall in love again. And now? Already chasing another?"},
		{"speaker": "Aphrodite", "text": "My brother Hades is expecting you. You're going DOWN - to the Underworld."},
		{"speaker": "Aphrodite", "text": "Survive. Fight your way back up. Prove you deserve another chance at love. Or don't come back at all."},
	]
	GameState.scene_after_dialogue = "res://scenes/levels/level1.tscn"
	get_tree().change_scene_to_file("res://scenes/dialogue/dialogue.tscn")
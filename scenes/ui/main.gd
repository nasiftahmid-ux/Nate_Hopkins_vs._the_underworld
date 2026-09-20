extends Control

@onready var start_button: Button = $Center/VBox/StartButton
@onready var quit_button: Button = $Center/VBox/QuitButton

var level_select: Array[Dictionary] = [
	{"label": "L1", "scene": "res://scenes/levels/level1.tscn"},
	{"label": "L2", "scene": "res://scenes/levels/level2.tscn"},
	{"label": "L3", "scene": "res://scenes/levels/level3.tscn"},
	{"label": "L4", "scene": "res://scenes/levels/level4.tscn"},
	{"label": "L5", "scene": "res://scenes/levels/level5.tscn"},
	{"label": "BOSS 1", "scene": "res://scenes/bosses/boss_arena.tscn", "exes": 0},
	{"label": "BOSS 2", "scene": "res://scenes/bosses/boss_arena.tscn", "exes": 1},
	{"label": "RHYTHM 1", "scene": "res://scenes/bosses/final_rhythm.tscn", "rhythm": 1},
	{"label": "RHYTHM 2", "scene": "res://scenes/bosses/final_rhythm.tscn", "rhythm": 2},
]


func _ready() -> void:
	GameState.new_game()
	start_button.grab_focus()
	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	_build_level_select()


func _build_level_select() -> void:
	for entry in level_select:
		var button := Button.new()
		button.text = entry["label"]
		button.custom_minimum_size = Vector2(0, 34)
		button.pressed.connect(_on_level_selected.bind(entry))
		$Center/VBox/LevelRow.add_child(button)


func _on_level_selected(entry: Dictionary) -> void:
	if entry.has("rhythm"):
		_setup_rhythm(entry["rhythm"])
	elif entry.has("exes"):
		GameState.defeated_exes = entry["exes"]
	GameState.player_health = GameState.player_max_hp
	get_tree().change_scene_to_file(entry["scene"])


func _setup_rhythm(phase: int) -> void:
	GameState.defeated_exes = phase
	if phase == 1:
		GameState.rhythm_window = 1.0
		GameState.rhythm_notes = 20
		GameState.rhythm_followup_lines = []
		GameState.rhythm_followup_scene = "res://scenes/levels/level5.tscn"
	else:
		GameState.rhythm_window = 1.0
		GameState.rhythm_notes = 30
		GameState.rhythm_followup_lines = [
			{"speaker": "Nate", "text": "Hazel... I clawed my way out of the actual Underworld for this."},
			{"speaker": "Hazel", "text": "...That's the weirdest pickup line I've ever heard."},
			{"speaker": "Hazel", "text": "But I guess anyone who fights through Hell deserves a first date. Dinner?"},
			{"speaker": "Narrator", "text": "Nate became a master of the Underworld dating circuit. 10/10 no notes."},
		]
		GameState.rhythm_followup_scene = "res://scenes/ui/main.tscn"


func _on_start() -> void:
	GameState.dialogue_lines = [
		{"speaker": "Narrator", "text": "A Friday night. Another party. Another chance for Nate Hopkins to make questionable life decisions."},
		{"speaker": "Nate", "text": "Hey Tracy, who's that girl? The one by the punch bowl."},
		{"speaker": "Tracy", "text": "Absolutely not. Last girl I set you up with? You broke her heart in the most brutal way possible."},
		{"speaker": "Tracy", "text": "I'm done playing matchmaker. You can figure this one out yourself."},
		{"speaker": "Nate", "text": "Fine. I'll find out myself."},
		{"speaker": "Hazel", "text": "Hi, I'm Hazel Abegnile Frye. You look like you just lost an argument."},
		{"speaker": "Nate", "text": "Nate Hopkins. And I never lose. Usually."},
		{"speaker": "Nate", "text": "So what brings you here, Hazel?"},
		{"speaker": "Aphrodite", "text": "NATE HOPKINS."},
		{"speaker": "Aphrodite", "text": "Last time, your heart was broken and you swore you'd never fall in love again. And now? Already chasing another?"},
		{"speaker": "Aphrodite", "text": "My brother Hades is expecting you. You're going DOWN - to the Underworld."},
		{"speaker": "Aphrodite", "text": "Survive. Fight your way back up. Prove you deserve another chance at love. Or don't come back at all."},
	]
	GameState.scene_after_dialogue = "res://scenes/levels/level1.tscn"
	get_tree().change_scene_to_file("res://scenes/dialogue/dialogue.tscn")

extends CanvasLayer


func _process(_delta: float) -> void:
	$HPLabel.text = "HP: %d / %d" % [int(GameState.player_health), int(GameState.player_max_hp)]
	$CoinsLabel.text = "Coins: %d" % GameState.money
	$LVLabel.text = "LV %d  XP: %d / %d" % [GameState.level, GameState.exp, GameState.exp_to_next_level()]
	$LivesLabel.text = "Defeated Exes: %d / 2" % GameState.defeated_exes
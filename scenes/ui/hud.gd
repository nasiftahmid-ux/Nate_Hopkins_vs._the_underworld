extends CanvasLayer


func _process(_delta: float) -> void:
	$HPLabel.text = "HP: %d / %d" % [int(GameState.player_health), int(GameState.player_max_hp)]
	$CoinsLabel.text = "Coins: %d" % GameState.money
	var mult := GameState.xp_multiplier()
	var penalty := ""
	if mult < 1.0:
		penalty = "   XP x%.2f  HEAL %d%%" % [mult, int(GameState.level_up_heal_ratio() * 100.0)]
	$LVLabel.text = "LV %d  XP: %d / %d%s" % [GameState.level, GameState.exp, GameState.exp_to_next_level(), penalty]
	$LivesLabel.text = "Defeated Exes: %d / 2" % GameState.defeated_exes

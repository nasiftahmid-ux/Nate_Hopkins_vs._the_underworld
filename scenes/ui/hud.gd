extends CanvasLayer


func _process(_delta: float) -> void:
	var t := maxf(0.0, GameState.player_health)
	var mins := int(t) / 60
	var secs := t - float(mins * 60)
	$HPLabel.text = "%02d:%05.2f" % [mins, secs]
	if t < 10.0:
		$HPLabel.modulate = Color(1, 0.2, 0.2)
		$HPLabel.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
	else:
		$HPLabel.modulate = Color.WHITE
	$CoinsLabel.text = "Coins: %d" % GameState.money
	$LVLabel.text = "LV %d  XP: %d / %d" % [GameState.level, GameState.exp, GameState.exp_to_next_level()]

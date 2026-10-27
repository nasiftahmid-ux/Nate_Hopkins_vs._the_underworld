extends "res://scenes/enemies/basic_enemy.gd"
# Placeholder negative-world enemy: fast swarmer. TODO: replace with real sprites.

func _ready() -> void:
	super()
	time_reward = 1.0
	speed = 130.0
	max_hp = 15.0
	money_reward = 2
	exp_reward = 10
	if sprite:
		sprite.modulate = Color(0.7, 0.7, 0.75)

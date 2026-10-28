extends Node2D

@onready var camera: Camera2D = $Player/Camera2D


func _ready() -> void:
	GameState.negative_mode = false
	GameState.return_stage = ""
	GameState.apply_unlocks_for_stage("res://scenes/bosses/boss_arena.tscn")
	camera.limit_left = 0
	camera.limit_top = -400
	camera.limit_right = 900
	camera.limit_bottom = 500

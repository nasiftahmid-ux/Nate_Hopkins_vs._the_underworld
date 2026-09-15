extends Node2D

@onready var camera: Camera2D = $Player/Camera2D


func _ready() -> void:
	camera.limit_left = 0
	camera.limit_top = -400
	camera.limit_right = 3000
	camera.limit_bottom = 500

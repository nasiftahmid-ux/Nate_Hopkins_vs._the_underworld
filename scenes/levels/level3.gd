extends Node2D

@onready var camera: Camera2D = $Player/Camera2D
@onready var hint_panel: ColorRect = $HintLayer/HintPanel
@onready var hint_label: Label = $HintLayer/HintLabel


func _ready() -> void:
	camera.limit_left = 0
	camera.limit_top = -400
	camera.limit_right = 11250
	camera.limit_bottom = 500
	$HintLayer/HintTimer.timeout.connect(_on_hint_timer_timeout)
	hint_panel.visible = false


func show_hint(text: String) -> void:
	hint_label.text = text
	hint_panel.visible = true
	$HintLayer/HintTimer.start()


func _on_hint_timer_timeout() -> void:
	hint_panel.visible = false
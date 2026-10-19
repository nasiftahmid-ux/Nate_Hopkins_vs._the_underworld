extends Node2D
# Shared level script. Each level .tscn sets camera_limit_right (and has_hints)
# via the Inspector exports on the root node.

@export var camera_limit_right := 4900
@export var has_hints := false
## Populate this level's enemies at runtime: group them into packs and give them
## idle homes. Set false for a level whose enemies are managed by hand.
@export var spawn_enemies := true
## Seed for the enemies' idle wandering. Only affects which way they pace and
## how long they pause; set a non-zero value to reproduce a layout exactly.
@export var enemy_seed := 0

@onready var camera: Camera2D = $Player/Camera2D
var hint_panel: ColorRect
var hint_label: Label


func _ready() -> void:
	GameState.begin_stage()
	Music.play_level()
	camera.limit_left = 0
	camera.limit_top = -400
	camera.limit_right = camera_limit_right
	camera.limit_bottom = 500
	if has_hints:
		hint_panel = $HintLayer/HintPanel
		hint_label = $HintLayer/HintLabel
		$HintLayer/HintTimer.timeout.connect(_on_hint_timer_timeout)
		hint_panel.visible = false
	if spawn_enemies and get_node_or_null("EnemyDirector") == null:
		_spawn_enemy_director()


## Builds the level's enemy director. Created in code rather than pinned into
## every level scene so all five stages share one populator, and so a level can
## opt out with `spawn_enemies = false`.
func _spawn_enemy_director() -> void:
	var director := preload("res://scenes/levels/enemy_director.gd").new()
	director.name = "EnemyDirector"
	director.debug_seed = enemy_seed
	add_child(director)


func show_hint(text: String) -> void:
	if not has_hints:
		return
	hint_label.text = text
	hint_panel.visible = true
	$HintLayer/HintTimer.start()


func _on_hint_timer_timeout() -> void:
	hint_panel.visible = false

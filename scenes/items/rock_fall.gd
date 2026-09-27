extends Area2D

@export var drop_count := 6
@export var interval := 0.9
@export var drop_delay := 0.4

const ROCK_SCENE := preload("res://scenes/items/rock.tscn")

var _player_inside := false
var _drops_left := 0
var _timer := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if not _player_inside or _drops_left <= 0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_drop_rock()
		_drops_left -= 1
		_timer = interval


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_drops_left = drop_count
		_timer = drop_delay


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_drops_left = 0


func _drop_rock() -> void:
	var rock := ROCK_SCENE.instantiate()
	rock.position = Vector2(global_position.x + randf_range(-280.0, 280.0), -460.0)
	rock.start_fall(0.0)
	get_tree().current_scene.add_child(rock)
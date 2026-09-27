extends CharacterBody2D
class_name EnemyBase
# Shared behavior for all ground enemies: hp, hit flash, death rewards and coin drop.

@export var max_hp := 30.0
@export var exp_reward := 20
@export var money_reward := 0
@export var hit_color := Color(1.0, 0.85, 0.4)
@export var hit_flash_time := 0.1
@export var death_delay := 0.6
@export var knockback_x := 220.0
@export var knockback_y := -180.0

var hp: float
var alive := true

@onready var body: ColorRect = $Body

var _player: Node2D


func _ready() -> void:
	hp = max_hp
	add_to_group("enemy")


func _get_player() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	return _player


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	hp -= dmg
	velocity.x = dir * knockback_x
	velocity.y = knockback_y
	body.color = hit_color
	get_tree().create_timer(hit_flash_time).timeout.connect(_reset_color)
	if hp <= 0.0:
		die()


func _reset_color() -> void:
	body.color = _base_color()


func _base_color() -> Color:
	return Color(0.85, 0.2, 0.25, 1)


func die() -> void:
	if not alive:
		return
	alive = false
	GameState.add_exp(exp_reward)
	if money_reward > 0:
		GameState.add_money(money_reward)
	_spawn_coin()
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	body.color = Color(0.35, 0.35, 0.35)
	await get_tree().create_timer(death_delay).timeout
	queue_free()


func _spawn_coin() -> void:
	var coin := preload("res://scenes/items/coin.tscn").instantiate()
	coin.global_position = global_position + Vector2(0, -20)
	get_tree().current_scene.add_child(coin)
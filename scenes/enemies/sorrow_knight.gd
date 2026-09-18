extends CharacterBody2D

const GRAVITY := 1600.0

var hp := 120.0
var speed := 42.0
var damage := 12.0
var alive := true
var attack_cooldown := 0.0

@onready var body: ColorRect = $Body


func _ready() -> void:
	add_to_group("enemy")


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	attack_cooldown -= delta
	var player := get_tree().get_first_node_in_group("player")
	var vx := 0.0
	if player:
		var dir := signf(player.global_position.x - global_position.x)
		if absf(player.global_position.x - global_position.x) > 48.0:
			vx = dir * speed
		if dir != 0.0:
			body.scale.x = dir
		if global_position.distance_to(player.global_position) < 56.0 and attack_cooldown <= 0.0:
			attack_cooldown = 2.0
			if player.has_method("take_damage"):
				player.take_damage(damage)
	velocity.x = move_toward(velocity.x, vx, 300.0 * delta)
	move_and_slide()


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	hp -= dmg
	velocity.x = dir * 100.0
	velocity.y = -80.0
	body.color = Color(1.0, 0.8, 0.4)
	get_tree().create_timer(0.12).timeout.connect(_reset_color)
	if hp <= 0.0:
		die()


func _reset_color() -> void:
	body.color = Color(0.55, 0.3, 0.65, 1)


func die() -> void:
	if not alive:
		return
	alive = false
	GameState.add_money(20)
	GameState.add_exp(60)
	_spawn_coin()
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	body.color = Color(0.35, 0.35, 0.35)
	await get_tree().create_timer(0.8).timeout
	queue_free()


func _spawn_coin() -> void:
	var coin := preload("res://scenes/items/coin.tscn").instantiate()
	coin.global_position = global_position + Vector2(0, -20)
	get_tree().current_scene.add_child(coin)

extends CharacterBody2D

const GRAVITY := 1600.0

var hp := 120.0
var speed := 42.0
var damage := 12.0
var alive := true
var attack_cooldown := 0.0
var blocking := false
var block_timer := 0.0

const BLOCK_RANGE := 84.0

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
		var dist := global_position.distance_to(player.global_position)
		if blocking:
			block_timer -= delta
			if block_timer <= 0.0:
				blocking = false
				body.color = Color(0.55, 0.3, 0.65, 1)
		elif dist < BLOCK_RANGE and player.get("is_attacking") == true:
			blocking = true
			block_timer = 0.7
			velocity.x = 0.0
			body.color = Color(0.35, 0.8, 0.55, 1)
		if absf(player.global_position.x - global_position.x) > 48.0 and not blocking:
			vx = dir * speed
		if dir != 0.0:
			body.scale.x = dir
		if dist < 56.0 and attack_cooldown <= 0.0 and not blocking:
			attack_cooldown = 2.0
			if player.has_method("take_damage"):
				player.take_damage(damage)
	velocity.x = move_toward(velocity.x, vx, 300.0 * delta)
	move_and_slide()


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	if blocking:
		hp -= dmg * 0.15
		velocity.x = dir * 20.0
		body.color = Color(0.9, 0.95, 0.5)
		get_tree().create_timer(0.12).timeout.connect(_block_reset_color)
		if hp <= 0.0:
			die()
		return
	hp -= dmg
	velocity.x = dir * 100.0
	velocity.y = -80.0
	body.color = Color(1.0, 0.8, 0.4)
	get_tree().create_timer(0.12).timeout.connect(_reset_color)
	if hp <= 0.0:
		die()


func _block_reset_color() -> void:
	if not blocking:
		return
	body.color = Color(0.35, 0.8, 0.55, 1)


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

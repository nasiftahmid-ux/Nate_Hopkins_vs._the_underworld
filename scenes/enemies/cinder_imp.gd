extends CharacterBody2D

const GRAVITY := 1600.0

var hp := 16.0
var speed := 175.0
var damage := 5.0
var alive := true
var attack_cooldown := 0.0
var dodge_cooldown := 0.0
var dodging := false

const DODGE_DURATION := 0.3
const DODGE_INVULN := 0.35

@onready var body: ColorRect = $Body


func _ready() -> void:
	add_to_group("enemy")


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	attack_cooldown -= delta
	dodge_cooldown -= delta
	var player := get_tree().get_first_node_in_group("player")
	var vx := 0.0
	if player:
		var dir := signf(player.global_position.x - global_position.x)
		var dist := global_position.distance_to(player.global_position)
		if dodging:
			vx = -dir * speed * 1.6
		elif absf(player.global_position.x - global_position.x) > 26.0:
			vx = dir * speed
		if dir != 0.0:
			body.scale.x = dir
		if player.get("is_attacking") == true and dist < 90.0 and dodge_cooldown <= 0.0:
			_start_dodge()
		if dist < 32.0 and attack_cooldown <= 0.0:
			attack_cooldown = 0.7
			if player.has_method("take_damage"):
				player.take_damage(damage)
	velocity.x = move_toward(velocity.x, vx, 900.0 * delta)
	move_and_slide()
	if dodging and dodge_time_left <= 0.0:
		dodging = false
		body.color = Color(1, 0.45, 0.2, 1)

var dodge_time_left := 0.0


func _start_dodge() -> void:
	dodging = true
	dodge_time_left = DODGE_DURATION
	dodge_cooldown = 1.6
	velocity.x = -signf(get_tree().get_first_node_in_group("player").global_position.x - global_position.x) * speed * 1.6
	velocity.y = -240.0
	body.color = Color(0.6, 0.35, 1.0)


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	if dodging:
		return
	hp -= dmg
	velocity.x = dir * 240.0
	velocity.y = -160.0
	body.color = Color(1.0, 0.85, 0.4)
	get_tree().create_timer(0.1).timeout.connect(_reset_color)
	if hp <= 0.0:
		die()


func _reset_color() -> void:
	body.color = Color(1, 0.45, 0.2, 1)


func die() -> void:
	if not alive:
		return
	alive = false
	GameState.add_exp(15)
	_spawn_coin()
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	body.color = Color(0.35, 0.35, 0.35)
	await get_tree().create_timer(0.4).timeout
	queue_free()


func _spawn_coin() -> void:
	var coin := preload("res://scenes/items/coin.tscn").instantiate()
	coin.global_position = global_position + Vector2(0, -20)
	get_tree().current_scene.add_child(coin)

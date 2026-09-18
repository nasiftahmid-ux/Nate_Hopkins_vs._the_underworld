extends CharacterBody2D

const GRAVITY := 1600.0
const MIN_RANGE := 130.0
const FIRE_RANGE := 300.0
const FAKE_COIN := 8

var hp := 24.0
var speed := 55.0
var fire_timer := 2.0
var alive := true

@onready var body: ColorRect = $Body


func _ready() -> void:
	add_to_group("enemy")


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var player := get_tree().get_first_node_in_group("player")
	var vx := 0.0
	if player:
		var dx: float = player.global_position.x - global_position.x
		var dir := signf(dx)
		if dir != 0.0:
			body.scale.x = dir
		var dist := global_position.distance_to(player.global_position)
		if absf(dx) > MIN_RANGE:
			vx = dir * speed
		elif dist < MIN_RANGE and absf(dx) > 30.0:
			vx = -dir * speed
		fire_timer -= delta
		if fire_timer <= 0.0 and dist < FIRE_RANGE:
			fire_timer = 2.0
			_fire(player)
	velocity.x = move_toward(velocity.x, vx, 400.0 * delta)
	move_and_slide()


func _fire(player: Node2D) -> void:
	var p := preload("res://scenes/enemies/teardrop.tscn").instantiate()
	p.global_position = global_position
	p.vel = (player.global_position - global_position).normalized() * 220.0
	get_tree().current_scene.add_child(p)


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	hp -= dmg
	velocity.x = dir * 200.0
	velocity.y = -160.0
	body.color = Color(1.0, 0.85, 0.4)
	get_tree().create_timer(0.1).timeout.connect(_reset_color)
	if hp <= 0.0:
		die()


func _reset_color() -> void:
	body.color = Color(0.2, 0.7, 0.85, 1)


func die() -> void:
	if not alive:
		return
	alive = false
	GameState.add_exp(30)
	_spawn_coin()
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	body.color = Color(0.35, 0.35, 0.35)
	await get_tree().create_timer(0.6).timeout
	queue_free()


func _spawn_coin() -> void:
	var coin := preload("res://scenes/items/coin.tscn").instantiate()
	coin.global_position = global_position + Vector2(0, -20)
	get_tree().current_scene.add_child(coin)

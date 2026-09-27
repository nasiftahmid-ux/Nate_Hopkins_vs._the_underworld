extends EnemyBase

const GRAVITY := 1600.0
const MIN_RANGE := 260.0
const FIRE_RANGE := 620.0
const FAKE_COIN := 8

var speed := 70.0
var fire_timer := 2.0


func _ready() -> void:
	max_hp = 24.0
	exp_reward = 30
	knockback_x = 200.0
	knockback_y = -160.0
	super._ready()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var player := _get_player()
	var vx := 0.0
	if player:
		var dx: float = player.global_position.x - global_position.x
		var dir := signf(dx)
		if dir != 0.0:
			body.scale.x = dir
		var dist := global_position.distance_to(player.global_position)
		if absf(dx) < MIN_RANGE:
			vx = -dir * speed
		elif dist > FIRE_RANGE + 40.0:
			vx = dir * speed
		fire_timer -= delta
		if fire_timer <= 0.0 and dist <= FIRE_RANGE:
			fire_timer = 1.6
			_fire(player)
	velocity.x = move_toward(velocity.x, vx, 400.0 * delta)
	move_and_slide()


func _fire(player: Node2D) -> void:
	var p := preload("res://scenes/enemies/teardrop.tscn").instantiate()
	p.global_position = global_position
	p.vel = (player.global_position - global_position).normalized() * 220.0
	get_tree().current_scene.add_child(p)


func _base_color() -> Color:
	return Color(0.2, 0.7, 0.85, 1)
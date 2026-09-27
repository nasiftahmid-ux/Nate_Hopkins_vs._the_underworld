extends EnemyBase

const GRAVITY := 1600.0

var speed := 42.0
var damage := 12.0
var attack_cooldown := 0.0
var blocking := false
var block_timer := 0.0

const BLOCK_RANGE := 84.0


func _ready() -> void:
	max_hp = 120.0
	exp_reward = 60
	money_reward = 20
	hit_color = Color(1.0, 0.8, 0.4)
	hit_flash_time = 0.12
	death_delay = 0.8
	knockback_x = 100.0
	knockback_y = -80.0
	super._ready()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	attack_cooldown -= delta
	var player := _get_player()
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
		get_tree().create_timer(hit_flash_time).timeout.connect(_block_reset_color)
		if hp <= 0.0:
			die()
		return
	super.take_hit(dmg, dir)


func _block_reset_color() -> void:
	if not blocking:
		return
	body.color = Color(0.35, 0.8, 0.55, 1)


func _base_color() -> Color:
	return Color(0.55, 0.3, 0.65, 1)
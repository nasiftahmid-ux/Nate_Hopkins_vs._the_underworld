extends EnemyBase

const GRAVITY := 1600.0

var speed := 175.0
var damage := 5.0
var attack_cooldown := 0.0
var dodge_cooldown := 0.0
var dodge_time_left := 0.0
var dodging := false

const DODGE_DURATION := 0.3
const DODGE_INVULN := 0.35


func _ready() -> void:
	max_hp = 16.0
	exp_reward = 15
	death_delay = 0.4
	knockback_x = 240.0
	knockback_y = -160.0
	super._ready()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	attack_cooldown -= delta
	dodge_cooldown -= delta
	var player := _get_player()
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


func _start_dodge() -> void:
	dodging = true
	dodge_time_left = DODGE_DURATION
	dodge_cooldown = 1.6
	velocity.x = -signf(_get_player().global_position.x - global_position.x) * speed * 1.6
	velocity.y = -240.0
	body.color = Color(0.6, 0.35, 1.0)


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	if dodging:
		return
	super.take_hit(dmg, dir)
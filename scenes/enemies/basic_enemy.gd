extends EnemyBase
# A drifting soul that chases the player on foot.
# It simply walks toward the player and stops at ledges so it won't fall.

const GRAVITY := 1600.0

var speed := 80.0
var damage := 8.0

var attack_cooldown := 0.0

@onready var floor_ahead: RayCast2D = $FloorAhead


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
		if absf(player.global_position.x - global_position.x) > 30.0:
			vx = dir * speed
			if is_on_floor():
				floor_ahead.position = Vector2(dir * 15.0, 24.0)
				floor_ahead.target_position = Vector2(0, 20)
				floor_ahead.force_raycast_update()
				if not floor_ahead.is_colliding():
					vx = 0.0
		if dir != 0.0:
			body.scale.x = dir
		if global_position.distance_to(player.global_position) < 40.0 and attack_cooldown <= 0.0:
			attack_cooldown = 1.2
			if player.has_method("take_damage"):
				player.take_damage(damage, true, global_position)

	velocity.x = move_toward(velocity.x, vx, 500.0 * delta)
	move_and_slide()
extends EnemyBase
# A drifting soul that chases the player on foot.
# It simply walks toward the player and stops at ledges so it won't fall.

const GRAVITY := 1600.0

var speed := 80.0
var damage := 8.0

var attack_cooldown := 0.0

@onready var floor_ahead: RayCast2D = $FloorAhead
@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	super()
	# The Base node is only a stand-in so the shared script has something to tint.
	# This enemy draws a sprite instead, so keep it out of sight.
	body.visible = false


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
			sprite.flip_h = dir < 0.0
		if global_position.distance_to(player.global_position) < 40.0 and attack_cooldown <= 0.0:
			attack_cooldown = 1.2
			_play("attack")
			if player.has_method("take_damage"):
				player.take_damage(damage, true, global_position)

	velocity.x = move_toward(velocity.x, vx, 500.0 * delta)
	move_and_slide()

	# Don't cut a one-shot short (an attack, a hit reaction, a death).
	if not _one_shot_playing():
		_play("run" if absf(velocity.x) > 1.0 else "idle")


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	_play("hurt")
	_flash()
	super.take_hit(dmg, dir)


func die() -> void:
	if not alive:
		return
	_play("death")
	super.die()


## Plays `anim` unless it is already the current, still-running animation.
func _play(anim: String) -> void:
	if not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation == anim and sprite.is_playing():
		return
	sprite.play(anim)


## True while a non-looping animation (attack/hurt/death) is still running.
func _one_shot_playing() -> bool:
	if not sprite.is_playing():
		return false
	return not sprite.sprite_frames.get_animation_loop(sprite.animation)


func _flash() -> void:
	sprite.modulate = Color(1.7, 1.7, 1.7)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, hit_flash_time)

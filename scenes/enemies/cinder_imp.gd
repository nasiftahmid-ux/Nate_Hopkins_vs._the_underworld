extends EnemyBase
# A small fire spirit that closes on the player and hits on contact.
# It reads the player's attack state and dodges sideways, so its tell is the
# small hop before slipping out of range.

const GRAVITY := 1600.0

var speed := 120.0
var damage := 10.0
var attack_cooldown := 0.0
var dodging := false
var dodge_time_left := 0.0
var dodge_cooldown := 0.0
var _growl_cooldown := 0.0

const DODGE_DURATION := 0.22
const DODGE_SPEED_MULT := 1.6

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	super()
	attack_sound = "attack_slash"
	death_sound = "death_imp"
	hp = 16.0
	_growl_cooldown = randf_range(2.0, 5.0)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	# Staggered by an uppercut: hold the hurt pose and skip the AI.
	if _stun_tick(delta):
		_play("hurt")
		return
	_update_awareness(delta)
	attack_cooldown -= delta
	dodge_cooldown -= delta
	_growl_cooldown -= delta
	var vx := 0.0
	if _in_combat():
		vx = _chase()
	elif awareness == Awareness.ALERTED:
		# Poised and watching, not yet committed: stand and face the player.
		var dir := _aware_player_dir()
		if dir != 0.0:
			sprite.flip_h = dir < 0.0
	else:
		if dodging:
			dodging = false
			sprite.modulate = Color.WHITE
		vx = _idle_velocity(delta, speed)
		if absf(vx) > 1.0:
			sprite.flip_h = vx < 0.0
	velocity.x = move_toward(velocity.x, vx, 900.0 * delta)
	move_and_slide()
	_update_footsteps(delta, absf(vx) > 0.0)
	if dodging and dodge_time_left <= 0.0:
		dodging = false
		sprite.modulate = Color.WHITE

	# Don't cut a one-shot short (an attack, a dodge, a hit, a death).
	if not _one_shot_playing():
		_play("run" if absf(velocity.x) > 1.0 else "idle")


## Closes on the player, hits on contact, and side-hops when the player swings.
func _chase() -> float:
	var player := _get_player()
	if player == null or not is_instance_valid(player):
		return 0.0
	var dir := signf(player.global_position.x - global_position.x)
	var dist := global_position.distance_to(player.global_position)
	if dist < 160.0 and _growl_cooldown <= 0.0:
		Sfx.play("monster_growl", -12.0, randf_range(0.92, 1.08))
		_growl_cooldown = randf_range(3.0, 6.0)
	var vx := 0.0
	if dodging:
		vx = -dir * speed * DODGE_SPEED_MULT
	elif absf(player.global_position.x - global_position.x) > 26.0:
		vx = dir * speed
	if dir != 0.0:
		sprite.flip_h = dir < 0.0
	if player.get("is_attacking") == true and dist < 90.0 and dodge_cooldown <= 0.0:
		_start_dodge()
	if dist < 32.0 and attack_cooldown <= 0.0:
		attack_cooldown = 0.7
		_play("attack")
		play_attack_sound()
		if player.has_method("take_damage"):
			player.take_damage(damage, true, global_position, PARRY_WINDOW, self)
	return vx


func awareness_facing() -> float:
	return -1.0 if sprite.flip_h else 1.0


func _start_dodge() -> void:
	dodging = true
	dodge_time_left = DODGE_DURATION
	dodge_cooldown = 1.6
	velocity.x = -signf(_get_player().global_position.x - global_position.x) * speed * 1.6
	sprite.modulate = Color(0.8, 0.9, 1.2)


func on_uppercut(duration: float = STUN_DURATION) -> void:
	if dodging:
		return
	super.on_uppercut(duration)


func _process(delta: float) -> void:
	super._process(delta)
	if dodging:
		dodge_time_left -= delta


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	_play("hurt")
	_flash()
	super.take_hit(dmg, dir)


func die() -> void:
	if is_dead:
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

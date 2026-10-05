extends EnemyBase
# A small fire spirit that closes on the player and hits on contact.
# It reads the player's attack state and dodges sideways, so its tell is the
# purple flash plus the dodge burst: purple means "committed, cannot be hit".

const GRAVITY := 1600.0

var speed := 175.0
var damage := 5.0
var attack_cooldown := 0.0
var dodge_cooldown := 0.0
var dodge_time_left := 0.0
var dodging := false

const DODGE_DURATION := 0.3
const DODGE_INVULN := 0.35
## The invulnerability tell. Purple while dodging, back to normal when it ends.
const DODGE_TINT := Color(0.6, 0.35, 1.0)

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	max_hp = 16.0
	exp_reward = 15
	# Long enough for the 5-frame death animation at 8 fps to finish.
	death_delay = 0.65
	knockback_x = 240.0
	knockback_y = -160.0
	super._ready()
	# The Body node is only a stand-in so the shared script has something to tint.
	# This enemy draws a sprite instead, so keep it out of sight.
	body.visible = false


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
			sprite.flip_h = dir < 0.0
		if player.get("is_attacking") == true and dist < 90.0 and dodge_cooldown <= 0.0:
			_start_dodge()
		if dist < 32.0 and attack_cooldown <= 0.0:
			attack_cooldown = 0.7
			_play("attack")
			if player.has_method("take_damage"):
				player.take_damage(damage, true, global_position)
	velocity.x = move_toward(velocity.x, vx, 900.0 * delta)
	move_and_slide()
	if dodging and dodge_time_left <= 0.0:
		dodging = false
		sprite.modulate = Color.WHITE

	# Don't cut a one-shot short (an attack, a dodge, a hit, a death).
	if not _one_shot_playing():
		_play("run" if absf(velocity.x) > 1.0 else "idle")


func _start_dodge() -> void:
	dodging = true
	dodge_time_left = DODGE_DURATION
	dodge_cooldown = 1.6
	velocity.x = -signf(_get_player().global_position.x - global_position.x) * speed * 1.6
	velocity.y = -240.0
	_play("dodge")
	sprite.modulate = DODGE_TINT


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	if dodging:
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


## True while a non-looping animation (attack/dodge/hurt/death) is still running.
func _one_shot_playing() -> bool:
	if not sprite.is_playing():
		return false
	return not sprite.sprite_frames.get_animation_loop(sprite.animation)


func _flash() -> void:
	sprite.modulate = Color(1.7, 1.7, 1.7)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, hit_flash_time)

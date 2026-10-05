extends EnemyBase
# A ranged enemy that kites: it backs away when the player gets close and lobs
# teardrops from a distance. Its silhouette is deliberately thin and tall so it
# reads as a caster next to the chunkier melee enemies.

const GRAVITY := 1600.0
const MIN_RANGE := 260.0
const FIRE_RANGE := 620.0
const FAKE_COIN := 8

var speed := 70.0
var fire_timer := 2.0
## True while it is backing away rather than closing in, so the retreat
## animation only plays when the enemy is actually retreating.
var _retreating := false

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	max_hp = 24.0
	exp_reward = 30
	# Long enough for the 5-frame death animation at 8 fps to finish.
	death_delay = 0.65
	knockback_x = 200.0
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
	var player := _get_player()
	var vx := 0.0
	_retreating = false
	if player:
		var dx: float = player.global_position.x - global_position.x
		var dir := signf(dx)
		if dir != 0.0:
			sprite.flip_h = dir < 0.0
		var dist := global_position.distance_to(player.global_position)
		if absf(dx) < MIN_RANGE:
			vx = -dir * speed
			_retreating = true
		elif dist > FIRE_RANGE + 40.0:
			vx = dir * speed
		fire_timer -= delta
		if fire_timer <= 0.0 and dist <= FIRE_RANGE:
			fire_timer = 1.6
			_play("shoot")
			_fire(player)
	velocity.x = move_toward(velocity.x, vx, 400.0 * delta)
	move_and_slide()

	# Don't cut a one-shot short (a shot, a hit, a death).
	if not _one_shot_playing():
		if _retreating:
			_play("retreat")
		else:
			_play("run" if absf(velocity.x) > 1.0 else "idle")


func _fire(player: Node2D) -> void:
	var p := preload("res://scenes/enemies/teardrop.tscn").instantiate()
	p.global_position = global_position
	p.vel = (player.global_position - global_position).normalized() * 220.0
	get_tree().current_scene.add_child(p)


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


## True while a non-looping animation (shoot/hurt/death) is still running.
func _one_shot_playing() -> bool:
	if not sprite.is_playing():
		return false
	return not sprite.sprite_frames.get_animation_loop(sprite.animation)


func _flash() -> void:
	sprite.modulate = Color(1.7, 1.7, 1.7)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, hit_flash_time)


func _base_color() -> Color:
	return Color(0.2, 0.7, 0.85, 1)

extends EnemyBase
# Placeholder negative-world enemy: floating clock drainer. TODO: replace with real sprites.

const GRAVITY := 0.0
var speed := 60.0
var drain_rate := 2.0
var latch_radius := 60.0
var _drain_cooldown := 0.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite")

func _ready() -> void:
	super()
	time_reward = 4.0
	max_hp = 20.0
	money_reward = 3
	exp_reward = 12
	if sprite:
		sprite.modulate = Color(0.5, 0.9, 0.9)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _stun_tick(delta):
		if sprite: _play("hurt")
		return
	_update_awareness(delta)
	var player := _player()
	if player and global_position.distance_to(player.global_position) < latch_radius:
		GameState.player_health = maxf(0.0, GameState.player_health - drain_rate * delta)
		GameState.clock_seconds = GameState.player_health
	# float toward player
	if player:
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * speed
		global_position += velocity * delta
	if sprite:
		sprite.play("run" if velocity.length() > 1.0 else "idle")

func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func _play(anim: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

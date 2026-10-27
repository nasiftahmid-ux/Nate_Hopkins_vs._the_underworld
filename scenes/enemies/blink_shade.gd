extends EnemyBase
# Placeholder negative-world enemy: teleports behind player. TODO: replace with real sprites.

var speed := 90.0
var teleport_delay := 1.0
var _timer := 0.0
var _flashed := false

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite")

func _ready() -> void:
	super()
	time_reward = 3.0
	max_hp = 18.0
	money_reward = 2
	exp_reward = 10
	if sprite:
		sprite.modulate = Color(0.8, 0.5, 0.9)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _stun_tick(delta):
		if sprite: _play("hurt")
		return
	_update_awareness(delta)
	var player := _player()
	if player:
		_timer += delta
		if _timer >= teleport_delay:
			_timer = 0.0
			# flash
			if sprite:
				sprite.modulate.a = 0.2
			await get_tree().create_timer(0.2).timeout
			if not alive:
				return
			global_position = player.global_position + Vector2(-60 * signf(player.global_position.x - global_position.x), 0)
			if sprite:
				sprite.modulate.a = 1.0
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

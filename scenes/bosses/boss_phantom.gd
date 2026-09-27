extends Node2D

const TEAR_SCENE := preload("res://scenes/bosses/boss_tear.tscn")
const COLOR := Color(0.95, 0.3, 0.55)
const LIFETIME := 5.0
const FIRE_INTERVAL := 1.35
const DRIFT_SPEED := 62.0
const ARENA_LEFT := 60.0
const ARENA_RIGHT := 840.0

var base_color := COLOR
var ttl := LIFETIME
var fire_timer := 0.6
var fire_damage := 6.0

var _body: ColorRect
var _core: ColorRect
var _player: Node2D
var _face := 1.0


func _ready() -> void:
	add_to_group("boss_hazard")
	_body = ColorRect.new()
	_body.size = Vector2(48, 84)
	_body.pivot_offset = Vector2(24, 84)
	_body.position = Vector2(-24, -84)
	_body.color = Color(base_color.r, base_color.g, base_color.b, 0.45)
	add_child(_body)
	_core = ColorRect.new()
	_core.size = Vector2(16, 22)
	_core.pivot_offset = Vector2(8, 22)
	_core.position = Vector2(-8, -62)
	_core.color = Color(1, 0.85, 0.9, 0.5)
	add_child(_core)


func _physics_process(delta: float) -> void:
	ttl -= delta
	if ttl <= 0.0:
		queue_free()
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var target_x := global_position.x
	if is_instance_valid(_player):
		target_x = _player.global_position.x
		var dir := signf(_player.global_position.x - global_position.x)
		if dir != 0.0:
			_face = dir
	global_position.x = move_toward(global_position.x, clampf(target_x, ARENA_LEFT, ARENA_RIGHT), DRIFT_SPEED * delta)
	_body.scale.x = _face
	_body.color.a = 0.45 * clampf(ttl / 0.8, 0.0, 1.0)
	fire_timer -= delta
	if fire_timer <= 0.0 and is_instance_valid(_player):
		fire_timer = FIRE_INTERVAL
		_spit()


func _spit() -> void:
	var dir := Vector2(_face * 0.55, -0.83)
	if is_instance_valid(_player):
		dir = (_player.global_position + Vector2(0, -30) - (global_position + Vector2(0, -60))).normalized()
	dir = dir.rotated(randf_range(-0.25, 0.25))
	var tear := TEAR_SCENE.instantiate()
	tear.global_position = global_position + Vector2(0, -60)
	tear.vel = dir * 150.0
	tear.damage = fire_damage
	tear.modulate.a = 0.7
	get_tree().current_scene.add_child(tear)

extends AnimatableBody2D

const CRUSH_DAMAGE_PERCENT := 0.3
const BLOCK_SEARCH_DIST := 14.0

@export var axis := 0
@export var travel := 160.0
@export var speed := 70.0

var _start_pos := Vector2.ZERO
var _activated := false
var _progress := 0.0
var _dir := 1.0

@onready var _platform_half_height: float = _shape_half_size().y
@onready var _platform_half_width: float = _shape_half_size().x


func _ready() -> void:
	_start_pos = global_position


func _physics_process(delta: float) -> void:
	if not _activated:
		_try_activate()
		return
	_progress += speed * delta * _dir
	if _progress >= travel:
		_progress = travel
		_dir = -1.0
	elif _progress <= 0.0:
		_progress = 0.0
		_dir = 1.0
	var offset := Vector2(_progress if axis == 0 else 0.0, _progress if axis == 1 else 0.0)
	global_position = _start_pos + offset
	_check_crush()


func _try_activate() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var player_feet: float = player.global_position.y + 32.0
	var platform_top: float = global_position.y - _platform_half_height
	var vertical_distance: float = absf(player_feet - platform_top)
	if vertical_distance < 2.0 and absf(player.global_position.x - global_position.x) < _platform_half_width:
		_activated = true


func _check_crush() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	var half := _player_half(player)
	var crushed := false
	if axis == 1:
		if _dir > 0.0:
			crushed = _down_crush(player, half)
		else:
			crushed = _up_crush(player, half)
	else:
		if _dir > 0.0:
			crushed = _right_crush(player, half)
		else:
			crushed = _left_crush(player, half)
	if crushed:
		player.take_damage(player.max_hp * CRUSH_DAMAGE_PERCENT, false)


func _down_crush(player: Node2D, half: Vector2) -> bool:
	var plat_bottom: float = global_position.y + _platform_half_height
	var top: float = player.global_position.y - half.y
	var center: float = player.global_position.y
	if plat_bottom < top - 4.0 or plat_bottom > center:
		return false
	if absf(player.global_position.x - global_position.x) > _platform_half_width + half.x:
		return false
	return _ray_hits(player, Vector2(player.global_position.x, player.global_position.y + half.y),
			Vector2(player.global_position.x, player.global_position.y + half.y + BLOCK_SEARCH_DIST))


func _up_crush(player: Node2D, half: Vector2) -> bool:
	var plat_top: float = global_position.y - _platform_half_height
	var center: float = player.global_position.y
	var bottom: float = player.global_position.y + half.y
	if plat_top < center or plat_top > bottom + 4.0:
		return false
	if absf(player.global_position.x - global_position.x) > _platform_half_width + half.x:
		return false
	return _ray_hits(player, Vector2(player.global_position.x, player.global_position.y - half.y),
			Vector2(player.global_position.x, player.global_position.y - half.y - BLOCK_SEARCH_DIST))


func _right_crush(player: Node2D, half: Vector2) -> bool:
	var plat_right: float = global_position.x + _platform_half_width
	var player_left: float = player.global_position.x - half.x
	var center: float = player.global_position.x
	var player_bottom: float = player.global_position.y + half.y
	if plat_right < player_left - 4.0 or plat_right > center:
		return false
	if absf(player.global_position.y - global_position.y) > half.y + _platform_half_height:
		return false
	if global_position.y - _platform_half_height > player_bottom - 4.0:
		return false
	return _ray_hits(player, Vector2(player.global_position.x + half.x, player.global_position.y),
			Vector2(player.global_position.x + half.x + BLOCK_SEARCH_DIST, player.global_position.y))


func _left_crush(player: Node2D, half: Vector2) -> bool:
	var plat_left: float = global_position.x - _platform_half_width
	var player_right: float = player.global_position.x + half.x
	var center: float = player.global_position.x
	var player_bottom: float = player.global_position.y + half.y
	if plat_left > player_right + 4.0 or plat_left < center:
		return false
	if absf(player.global_position.y - global_position.y) > half.y + _platform_half_height:
		return false
	if global_position.y - _platform_half_height > player_bottom - 4.0:
		return false
	return _ray_hits(player, Vector2(player.global_position.x - half.x, player.global_position.y),
			Vector2(player.global_position.x - half.x - BLOCK_SEARCH_DIST, player.global_position.y))


func _ray_hits(player: Node2D, from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [get_rid(), player.get_rid()]
	var space := get_world_2d().direct_space_state
	return not space.intersect_ray(query).is_empty()


func _player_half(player: Node2D) -> Vector2:
	var shape_node := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size * 0.5
	return Vector2(17, 32)


func _shape_half_size() -> Vector2:
	var col := get_node("Col") as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		return (col.shape as RectangleShape2D).size * 0.5
	return Vector2(90, 12)
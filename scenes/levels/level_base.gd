extends Node2D
# Shared level script. Each level .tscn sets camera_limit_right (and has_hints)
# via the Inspector exports on the root node.

@export var camera_limit_right := 4900
@export var has_hints := false
## Populate this level's enemies at runtime: group them into packs and give them
## idle homes. Set false for a level whose enemies are managed by hand.
@export var spawn_enemies := true
## Seed for the enemies' idle wandering. Only affects which way they pace and
## how long they pause; set a non-zero value to reproduce a layout exactly.
@export var enemy_seed := 0

@onready var camera: Camera2D = $Player/Camera2D
var hint_panel: ColorRect
var hint_label: Label

var _gray_material: ShaderMaterial
var _gray_count := 0


func _ready() -> void:
	GameState.begin_stage()
	GameState.apply_unlocks_for_stage(scene_file_path)
	if (not GameState.negative_mode) and scene_file_path.ends_with("level1.tscn") and GameState.should_play_story("S2_BEFORE_LEVEL_1"):
		GameState.play_story("S2_BEFORE_LEVEL_1", GameState.story_lines("S2_BEFORE_LEVEL_1"), scene_file_path)
		return
	if (not GameState.negative_mode) and scene_file_path.ends_with("level3.tscn") and GameState.should_play_story("S8_BEFORE_LEVEL_3"):
		GameState.play_story("S8_BEFORE_LEVEL_3", GameState.story_lines("S8_BEFORE_LEVEL_3"), scene_file_path)
		return
	var _play_neg_story := false
	if GameState.negative_mode:
		GameState.player_max_hp = float(GameState.NEGATIVE_ENEMIES["negative_start"])
		GameState.player_health = GameState.player_max_hp
		await get_tree().process_frame
		_apply_negative_visuals()
		if GameState.should_play_story("S3_FIRST_TIME_NEGATIVE_WORLD"):
			_play_neg_story = true
	if _play_neg_story:
		GameState.play_story("S3_FIRST_TIME_NEGATIVE_WORLD", GameState.story_lines("S3_FIRST_TIME_NEGATIVE_WORLD"), scene_file_path)
		return
	Music.play_level()
	camera.limit_left = 0
	camera.limit_top = -400
	camera.limit_right = camera_limit_right
	camera.limit_bottom = 500
	if has_hints:
		hint_panel = $HintLayer/HintPanel
		hint_label = $HintLayer/HintLabel
		$HintLayer/HintTimer.timeout.connect(_on_hint_timer_timeout)
		hint_panel.visible = false
	if spawn_enemies and get_node_or_null("EnemyDirector") == null:
		_spawn_enemy_director()
	if GameState.negative_mode:
		_spawn_negative_extras()
	GameState.clock_running = true


var _neg_originals: Array = []
var _neg_remaining: int = 0
var _neg_level: int = 0


func _negative_level_number() -> int:
	var path := scene_file_path
	if path.is_empty() and get_tree() and get_tree().current_scene:
		path = get_tree().current_scene.scene_file_path
	var digits := path.get_file().get_basename().trim_prefix("level")
	return int(digits) if digits.is_valid_int() else 0


func _spawn_negative_extras() -> void:
	if not GameState.negative_mode:
		return
	_neg_originals.clear()
	for child in get_children():
		if child is EnemyBase and is_instance_valid(child):
			_neg_originals.append(child)
	var normal_count: int = _neg_originals.size()
	var mult_map: Dictionary = GameState.NEGATIVE_ENEMIES.get("spawn_multiplier_by_level", {})
	var mult: int = int(mult_map.get(_negative_level_number(), GameState.NEGATIVE_ENEMIES.get("spawn_multiplier_default", 2)))
	var quota: int = int(ceil(float(normal_count) * float(mult)))
	_neg_level = _negative_level_number()
	if OS.is_debug_build():
		print("NEGATIVE: level %d, normal count %d, quota %d, max_alive %d, damage mult 3.0" % [_neg_level, normal_count, quota, int(GameState.NEGATIVE_ENEMIES["max_alive"])])
	GameState.negative_total = quota
	_neg_remaining = maxi(0, quota - normal_count)
	GameState.negative_remaining_spawns = _neg_remaining
	# Spawn up to the alive cap now; the rest follow as enemies die.
	var max_alive: int = int(GameState.NEGATIVE_ENEMIES["max_alive"])
	var slots: int = max_alive - get_tree().get_nodes_in_group("enemy").size()
	var to_spawn_now: int = mini(_neg_remaining, maxi(0, slots))
	for i in range(to_spawn_now):
		_spawn_one_negative_extra()
		_neg_remaining -= 1


func _spawn_one_negative_extra() -> void:
	if _neg_originals.is_empty():
		return
	var e: EnemyBase = _neg_originals[randi() % _neg_originals.size()]
	var r: int = randi() % 100
	var scene_path: String
	if r < 50:
		scene_path = "res://scenes/enemies/husk.tscn"
	elif r < 70:
		scene_path = "res://scenes/enemies/time_leech.tscn"
	else:
		scene_path = "res://scenes/enemies/blink_shade.tscn"
	var packed := load(scene_path)
	if packed == null:
		return
	var inst = packed.instantiate()
	if inst == null:
		return
	add_child(inst)
	# horizontal offset
	var offset_x: float = randf_range(-80.0, 80.0)
	var target_x: float = e.global_position.x + offset_x
	target_x = clampf(target_x, 120.0, float(camera_limit_right) - 120.0)
	# avoid player proximity
	var player := get_node_or_null("Player")
	if player != null and is_instance_valid(player):
		if absf(target_x - player.global_position.x) < 400.0:
			target_x = player.global_position.x + (400.0 if target_x >= player.global_position.x else -400.0)
			target_x = clampf(target_x, 120.0, float(camera_limit_right) - 120.0)
	# snap to floor
	var half := 0.0
	for c in inst.get_children():
		var cs := c as CollisionShape2D
		if cs != null and cs.shape is RectangleShape2D:
			half = (cs.shape as RectangleShape2D).size.y * 0.5 * absf(cs.scale.y)
			break
	var from := Vector2(target_x, e.global_position.y - 40.0)
	var to := Vector2(target_x, e.global_position.y + 900.0)
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, 1, [inst.get_rid()])
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var surface_y: float = hit.position.y
		var authored_feet: float = e.global_position.y + half
		if absf(surface_y - authored_feet) <= 90.0:
			inst.global_position = Vector2(target_x, surface_y - half - 1.0)
		else:
			inst.global_position = Vector2(target_x, e.global_position.y)
	else:
		inst.global_position = Vector2(target_x, e.global_position.y)
	# staggered respawn hook
	inst.tree_exited.connect(_on_negative_enemy_exited)


func _on_negative_enemy_exited() -> void:
	if not GameState.negative_mode:
		return
	if _neg_remaining <= 0:
		return
	var max_alive: int = int(GameState.NEGATIVE_ENEMIES["max_alive"])
	if get_tree().get_nodes_in_group("enemy").size() >= max_alive:
		return
	var delay: float = randf_range(0.5, 1.5)
	var t := get_tree().create_timer(delay)
	t.timeout.connect(func():
		if not GameState.negative_mode:
			return
		if _neg_remaining <= 0:
			return
		if get_tree().get_nodes_in_group("enemy").size() >= max_alive:
			return
		_spawn_one_negative_extra()
		_neg_remaining -= 1
		GameState.negative_remaining_spawns = _neg_remaining
	)


func _spawn_enemy_director() -> void:
	var director := preload("res://scenes/levels/enemy_director.gd").new()
	director.name = "EnemyDirector"
	director.debug_seed = enemy_seed
	add_child(director)


func _apply_negative_visuals() -> void:
	if not GameState.NEGATIVE_ENEMIES.get("gray_actors", true):
		return
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() { float g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114)); COLOR.rgb = vec3(g); }"
	_gray_material = ShaderMaterial.new()
	_gray_material.shader = shader
	_gray_count = 0
	_apply_gray_recursive(self)
	get_tree().node_added.connect(_on_node_added)
	print("NEGATIVE GRAYSCALE: applied to %d nodes" % _gray_count)


func _is_ui_node(node: Node) -> bool:
	if node == null:
		return false
	if node.name == "HUD" or node.name == "HintLayer":
		return true
	var p := node.get_parent()
	while p != null:
		if p.name == "HUD" or p.name == "HintLayer":
			return true
		p = p.get_parent()
	return false


func _apply_gray_recursive(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _is_ui_node(node):
		return
	# Enemies keep their own coloring so they stay readable in the gray world.
	var p := node.get_parent()
	while p != null:
		if p is EnemyBase:
			return
		p = p.get_parent()
	if node is EnemyBase:
		return
	if node is CanvasItem:
		# If a node already has its own ShaderMaterial, replace it in negative mode only.
		node.material = _gray_material
		_gray_count += 1
	for child in node.get_children():
		_apply_gray_recursive(child)


func _on_node_added(node: Node) -> void:
	if not GameState.negative_mode:
		return
	if node == null or not is_instance_valid(node):
		return
	if _is_ui_node(node):
		return
	var p := node.get_parent()
	while p != null:
		if p is EnemyBase:
			return
		p = p.get_parent()
	if node is EnemyBase:
		return
	if node is CanvasItem:
		node.material = _gray_material


func show_hint(text: String) -> void:
	if not has_hints:
		return
	hint_label.text = text
	hint_panel.visible = true
	$HintLayer/HintTimer.start()


func _on_hint_timer_timeout() -> void:
	hint_panel.visible = false

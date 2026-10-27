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
	if GameState.negative_mode:
		GameState.player_max_hp = float(GameState.NEGATIVE_ENEMIES["negative_start"])
		GameState.player_health = GameState.player_max_hp
		await get_tree().process_frame
		_apply_negative_visuals()
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
		GameState.negative_total = get_tree().get_nodes_in_group("enemy").size()
	GameState.clock_running = true


func _spawn_negative_extras() -> void:
	var extras := ["res://scenes/enemies/husk.tscn","res://scenes/enemies/time_leech.tscn","res://scenes/enemies/blink_shade.tscn"]
	var originals := []
	for child in get_children():
		if child is EnemyBase and is_instance_valid(child):
			originals.append(child)
	var idx := 0
	for e in originals:
		for k in range(2):
			if get_tree().get_nodes_in_group("enemy").size() >= int(GameState.NEGATIVE_ENEMIES["max_alive"]):
				return
			var scene_path: String = extras[(idx + k) % extras.size()]
			var packed := load(scene_path)
			if packed == null:
				continue
			var inst = packed.instantiate()
			if inst == null:
				continue
			inst.global_position = e.global_position + Vector2(40.0 * (k + 1), 0.0)
			add_child(inst)
			idx += 1


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

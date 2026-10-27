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
			var scene_path := extras[(idx + k) % extras.size()]
			var packed := load(scene_path)
			if packed == null:
				continue
			var inst = packed.instantiate()
			if inst == null:
				continue
			inst.global_position = e.global_position + Vector2(40.0 * (k + 1), 0.0)
			add_child(inst)
			idx += 1
	# Fallback full-screen grayscale shader (tell: used fallback).
	var layer := CanvasLayer.new()
	layer.layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture;\nuniform float strength = 0.9;\nvoid fragment(){ vec4 c = texture(screen_texture, SCREEN_UV); float g = dot(c.rgb, vec3(0.299,0.587,0.114)); COLOR = vec4(mix(c.rgb, vec3(g), strength), c.a); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)
	# vignette
	var vlayer := CanvasLayer.new()
	var vrect := ColorRect.new()
	vrect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vrect.color = Color(0,0,0,0.35)
	vlayer.add_child(vrect)
	add_child(vlayer)


## Builds the level's enemy director. Created in code rather than pinned into
## every level scene so all five stages share one populator, and so a level can
## opt out with `spawn_enemies = false`.
func _spawn_enemy_director() -> void:
	var director := preload("res://scenes/levels/enemy_director.gd").new()
	director.name = "EnemyDirector"
	director.debug_seed = enemy_seed
	add_child(director)


func show_hint(text: String) -> void:
	if not has_hints:
		return
	hint_label.text = text
	hint_panel.visible = true
	$HintLayer/HintTimer.start()


func _on_hint_timer_timeout() -> void:
	hint_panel.visible = false


func _apply_negative_visuals() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(bbc)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture;\nvoid fragment(){ vec4 c = texture(screen_texture, SCREEN_UV); float g = dot(c.rgb, vec3(0.299,0.587,0.114)); COLOR = vec4(vec3(g), c.a); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)

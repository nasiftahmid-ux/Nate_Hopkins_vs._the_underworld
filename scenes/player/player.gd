extends CharacterBody2D

signal hp_changed(current: float, maximum: float)

const SPEED := 260.0
const JUMP_VELOCITY := -820.0
const GRAVITY := 1600.0
const COMBO_WINDOW := 0.5
const ATTACK_DURATION := 0.18
const SPECIAL_DURATION := 0.35
const ATTACK_REACH := 46.0
const ATK_LIGHT := 8.0
const ATK_HEAVY := 18.0
const ATK_SPECIAL := 40.0
const BASE_COLOR := Color(0.2, 0.6, 1)

var hp := 0.0
var max_hp := 100.0
var facing := 1
var combo_step := 0
var combo_timer := 0.0
var is_attacking := false
var attack_left := 0.0
var hit_delay := 0.0
var hit_damage := 0.0
var special_cooldown := 0.0
var invuln_time := 0.0
var start_pos := Vector2.ZERO
const INVULN_DURATION := 0.6
const KILL_PLANE_Y := 640.0

@onready var body: ColorRect = $Body
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	add_to_group("player")
	start_pos = global_position
	max_hp = GameState.player_max_hp
	hp = clampf(GameState.player_health, 1.0, max_hp) if GameState.player_health > 0.0 else max_hp
	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var input := Input.get_axis("move_left", "move_right")
	if is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	elif input != 0.0:
		velocity.x = input * SPEED
		facing = signf(input)
		body.scale.x = facing
	else:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	special_cooldown = maxf(special_cooldown - delta, 0.0)
	invuln_time = maxf(invuln_time - delta, 0.0)
	body.visible = not int(fmod(Time.get_ticks_msec() / 60.0, 2.0)) if invuln_time > 0.0 else true

	combo_timer -= delta
	if combo_timer <= 0.0 and combo_step != 0:
		combo_step = 0

	if hit_delay > 0.0:
		hit_delay -= delta
		if hit_delay <= 0.0:
			apply_hit()

	if is_attacking:
		attack_left -= delta
		if attack_left <= 0.0:
			is_attacking = false
			body.color = BASE_COLOR
	elif not is_attacking:
		if Input.is_action_just_pressed("attack"):
			try_attack(false, false)
		elif Input.is_action_just_pressed("heavy_attack"):
			try_attack(true, false)
		elif Input.is_action_just_pressed("special") and special_cooldown <= 0.0:
			try_attack(false, true)

	move_and_slide()

	if global_position.y > KILL_PLANE_Y:
		die()


func try_attack(heavy: bool, special: bool) -> void:
	is_attacking = true
	attack_left = SPECIAL_DURATION if special else ATTACK_DURATION
	if special:
		special_cooldown = 2.0
		combo_step = 0
		hit_damage = ATK_SPECIAL
		body.color = Color(1, 0.45, 0.9)
	elif heavy:
		combo_step = 0
		hit_damage = ATK_HEAVY
		body.color = Color(1, 0.9, 0.3)
	else:
		combo_step = (combo_step + 1) % 4
		combo_timer = COMBO_WINDOW
		hit_damage = ATK_LIGHT + (combo_step % 3) * 4.0
		body.color = Color(1, 0.95, 0.6)
	hitbox.position.x = facing * ATTACK_REACH
	hit_delay = 0.03


func apply_hit() -> void:
	for target in hitbox.get_overlapping_bodies():
		if target.is_in_group("enemy") and target.has_method("take_hit"):
			target.take_hit(hit_damage, facing)


func take_damage(amount: float) -> void:
	if invuln_time > 0.0:
		return
	invuln_time = INVULN_DURATION
	hp = maxf(hp - amount, 0.0)
	GameState.player_health = hp
	hp_changed.emit(hp, max_hp)
	body.color = Color(1, 0.3, 0.3)
	if hp <= 0.0:
		die()
	else:
		get_tree().create_timer(0.12).timeout.connect(reset_color)


func reset_color() -> void:
	if not is_attacking:
		body.color = BASE_COLOR


func die() -> void:
	if not is_physics_processing():
		return
	set_physics_process(false)
	body.color = Color(0.4, 0.4, 0.4)
	is_attacking = false
	await get_tree().create_timer(1.0).timeout
	var death_panel := preload("res://scenes/ui/death_panel.tscn").instantiate()
	get_tree().current_scene.add_child(death_panel)
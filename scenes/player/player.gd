extends CharacterBody2D

signal hp_changed(current: float, maximum: float)

const SPEED := 260.0
const JUMP_VELOCITY := -820.0
const GRAVITY := 1600.0
const COMBO_WINDOW := 0.5
const ATTACK_DURATION := 0.18
const SPECIAL_DURATION := 0.35
const AERIAL_DURATION := 0.3
const ATTACK_REACH := 46.0
const ATK_LIGHT := 8.0
const ATK_HEAVY := 18.0
const ATK_FINISHER := 20.0
const ATK_SLAM := 22.0
const ATK_SPECIAL := 40.0

var hp := 0.0
var max_hp := 100.0
var facing := 1
var combo_step := 0
var combo_timer := 0.0
var is_attacking := false
var is_blocking := false
var attack_anim := "attack_punch"
var attack_left := 0.0
var hit_delay := 0.0
var hit_damage := 0.0
var special_cooldown := 0.0
var invuln_time := 0.0
var start_pos := Vector2.ZERO
const INVULN_DURATION := 0.6
const KILL_PLANE_Y := 640.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	add_to_group("player")
	sprite.play("idle")
	start_pos = global_position
	max_hp = GameState.player_max_hp
	hp = clampf(GameState.player_health, 1.0, max_hp) if GameState.player_health > 0.0 else max_hp
	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var input := Input.get_axis("move_left", "move_right")
	is_blocking = Input.is_action_pressed("block") and not is_attacking
	if is_blocking:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	elif is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	elif input != 0.0:
		velocity.x = input * SPEED
		facing = signf(input)
		sprite.flip_h = facing < 0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_blocking:
		velocity.y = JUMP_VELOCITY

	special_cooldown = maxf(special_cooldown - delta, 0.0)
	invuln_time = maxf(invuln_time - delta, 0.0)
	sprite.visible = not int(fmod(Time.get_ticks_msec() / 60.0, 2.0)) if invuln_time > 0.0 else true

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
			sprite.modulate = Color.WHITE
	elif not is_attacking and not is_blocking:
		if Input.is_action_just_pressed("attack"):
			try_attack(false, false, not is_on_floor())
		elif Input.is_action_just_pressed("heavy_attack"):
			try_attack(true, false)
		elif Input.is_action_just_pressed("special") and special_cooldown <= 0.0:
			try_attack(false, true)

	_update_animation(input)

	move_and_slide()

	if global_position.y > KILL_PLANE_Y:
		die()


func try_attack(heavy: bool, special: bool, aerial: bool = false) -> void:
	if is_attacking:
		return
	is_attacking = true
	attack_left = SPECIAL_DURATION if special else ATTACK_DURATION
	if special:
		special_cooldown = 2.0
		combo_step = 0
		hit_damage = ATK_SPECIAL
		attack_anim = "attack_uppercut"
	elif heavy:
		combo_step = 0
		hit_damage = ATK_HEAVY
		attack_anim = "attack_kick"
	elif aerial:
		combo_step = 0
		attack_left = AERIAL_DURATION
		hit_damage = ATK_SLAM
		attack_anim = "jump"
		velocity.y = 400.0
	else:
		combo_step = (combo_step + 1) % 4
		combo_timer = COMBO_WINDOW
		match combo_step:
			1:
				hit_damage = ATK_LIGHT
				attack_anim = "attack_punch"
			2:
				hit_damage = ATK_HEAVY - 6.0
				attack_anim = "attack_kick"
			_:
				hit_damage = ATK_FINISHER if combo_step == 3 else ATK_LIGHT
				attack_anim = "attack_uppercut" if combo_step == 3 else "attack_punch"
	hitbox.position.x = facing * ATTACK_REACH
	hit_delay = 0.03


func _update_animation(input: float) -> void:
	if is_blocking:
		if sprite.sprite_frames.has_animation("block") and sprite.animation != "block":
			sprite.play("block")
	elif is_attacking:
		if sprite.animation != attack_anim:
			sprite.play(attack_anim)
	elif not is_on_floor():
		if sprite.animation != "jump":
			sprite.play("jump")
	elif input != 0.0:
		if sprite.animation != "run":
			sprite.play("run")
	else:
		if sprite.animation != "idle":
			sprite.play("idle")


func apply_hit() -> void:
	for target in hitbox.get_overlapping_bodies():
		if target.is_in_group("enemy") and target.has_method("take_hit"):
			target.take_hit(hit_damage, facing)


func take_damage(amount: float, blockable: bool = true) -> void:
	if invuln_time > 0.0:
		return
	if is_blocking and blockable:
		sprite.modulate = Color(0.7, 0.9, 1.0)
		invuln_time = 0.25
		sprite.visible = true
		get_tree().create_timer(0.12).timeout.connect(reset_color)
		return
	invuln_time = INVULN_DURATION
	hp = maxf(hp - amount, 0.0)
	GameState.player_health = hp
	hp_changed.emit(hp, max_hp)
	sprite.modulate = Color(1, 0.3, 0.3)
	if hp <= 0.0:
		die()
	else:
		get_tree().create_timer(0.12).timeout.connect(reset_color)


func reset_color() -> void:
	if not is_attacking and not is_blocking:
		sprite.modulate = Color.WHITE


func die() -> void:
	if not is_physics_processing():
		return
	set_physics_process(false)
	get_tree().paused = true
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	sprite.modulate = Color.WHITE
	is_attacking = false
	hitbox.monitoring = false
	var fall_delay := 0.0
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		if not sprite.sprite_frames.get_animation_loop("death"):
			await sprite.animation_finished
		else:
			fall_delay = sprite.sprite_frames.get_animation_length("death")
			await get_tree().create_timer(fall_delay + 0.6, true).timeout
	else:
		await get_tree().create_timer(1.1, true).timeout
	var death_panel := preload("res://scenes/ui/death_panel.tscn").instantiate()
	get_tree().current_scene.add_child(death_panel)

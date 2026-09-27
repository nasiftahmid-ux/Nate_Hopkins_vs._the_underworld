extends CharacterBody2D

enum BossKind { BROKEN, SWEETHEART }
enum State {
	CHASE, MELEE, SLAM_WINDUP, SLAM_AIR, SLAM_LAND, CHARGE_WINDUP, CHARGE, SPIT, TELEPORT, RAIN,
	LUNGE_WINDUP, LUNGE, SPIKES, BARRAGE, SPIRAL, EXECUTE_WINDUP, EXECUTE, PHANTOMS, SHIFT,
}

const GRAVITY := 1600.0
const MELEE_MOVE_RANGE := 56.0
const MELEE_REACH := 76.0
const SLAM_RADIUS := 130.0
const TEAR_SCENE := preload("res://scenes/bosses/boss_tear.tscn")
const SPIKE_SCENE := preload("res://scenes/bosses/boss_spike.tscn")
const PHANTOM_SCRIPT := preload("res://scenes/bosses/boss_phantom.gd")

const ARENA_LEFT := 60.0
const ARENA_RIGHT := 840.0
const ARENA_TOP := -260.0
const ARENA_FLOOR := 440.0

const PHASE2_RATIO := 0.66
const PHASE3_RATIO := 0.33
const DEATH_RATIO := 0.01
const SECOND_WIND_RATIO := 0.12
const SECOND_WIND_HEAL := 0.25
const VULNERABLE_MULT := 1.8

const HP_BASE := 900.0
const HP_PER_EX := 500.0
const PHASE_DAMAGE := [0.0, 0.0, 5.0, 12.0]
const PHASE_CHASE := [0.0, 0.0, 20.0, 48.0]
const PHASE_COOLDOWN := [1.0, 1.0, 0.82, 0.55]
const PHASE_CHAIN := [0.0, 0.0, 0.45, 0.7]
const CHAIN_CAP := [0, 0, 2, 3]
const NO_GRAVITY := [State.CHARGE, State.EXECUTE, State.TELEPORT, State.SHIFT]

const BROKEN_BASE_COLOR := Color(0.95, 0.3, 0.5)
const SWEET_BASE_COLOR := Color(0.75, 0.4, 0.95)
const ENRAGED_COLOR := Color(1.0, 0.2, 0.2)
const VULNERABLE_COLOR := Color(1.0, 0.92, 0.55)
const TITLES := {
	BossKind.BROKEN: ["PHASE I - HUNTING", "PHASE II - THE TOLLING", "PHASE III - BERSERK"],
	BossKind.SWEETHEART: ["PHASE I - THE SEDUCTION", "PHASE II - A MILLION NEEDLES", "PHASE III - BERSERK"],
}

var boss_kind := BossKind.BROKEN
var hp := HP_BASE
var max_hp := HP_BASE
var base_chase := 70.0
var chase_speed := 70.0
var base_damage := 16.0
var damage := 16.0
var alive := true
var enraged := false
var phase := 1
var invulnerable := false
var second_wind_used := false
var vulnerable_time := 0.0
var chain_pending := false
var chain_count := 0
var base_name := "THE ONE YOU HURT"

var attack_cooldown := 1.2
var teleport_cooldown := 0.0

var state := State.CHASE
var state_time := 0.0
var hit_flash := 0.0
var last_attack := State.CHASE

var melee_done := false
var spit_done := false
var rain_done := false
var tele_moved := false
var charge_hit := false
var slam_landed := false
var lunge_hits := 0
var execute_hit := false
var burst_done := false
var landing_x := 0.0
var lunge_x := 0.0
var execute_x := 0.0
var charge_dir := 1.0
var charge_speed := 520.0
var spit_timer := 0.0
var spiral_angle := 0.0

@onready var body: ColorRect = $Body
@onready var name_label: Label = $NameLabel
@onready var telegraph: ColorRect = $Telegraph

var boss_bar: ProgressBar
var boss_name_label: Label
var title_label: Label

var _player: Node2D
var _camera: Camera2D
var _shake_tween: Tween


func _get_player() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player is PhysicsBody2D:
			add_collision_exception_with(_player)
	return _player


func _get_camera() -> Camera2D:
	if not is_instance_valid(_camera):
		_camera = get_tree().current_scene.get_node_or_null("Player/Camera2D") as Camera2D
	return _camera


func _ready() -> void:
	add_to_group("enemy")
	hp = HP_BASE + GameState.defeated_exes * HP_PER_EX
	max_hp = hp
	boss_kind = BossKind.BROKEN if GameState.defeated_exes == 0 else BossKind.SWEETHEART
	if boss_kind == BossKind.BROKEN:
		base_name = "THE ONE YOU HURT"
		base_chase = 72.0
		base_damage = 17.0
	else:
		base_name = "FIRST LOVE"
		base_chase = 96.0
		base_damage = 15.0
	_apply_phase_stats()
	_restore_body_color()
	var hud := get_parent().get_node_or_null("BossHUD")
	if hud:
		boss_bar = hud.get_node_or_null("BossBar")
		boss_name_label = hud.get_node_or_null("BossNameLabel")
		if boss_bar:
			boss_bar.max_value = max_hp
			boss_bar.value = hp
	title_label = get_parent().get_node_or_null("Title")
	_set_title()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if boss_bar:
		boss_bar.value = hp
	state_time += delta
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	teleport_cooldown = maxf(teleport_cooldown - delta, 0.0)
	vulnerable_time = maxf(vulnerable_time - delta, 0.0)
	var player := _get_player()

	if not is_on_floor() and body.visible and not (state in NO_GRAVITY):
		velocity.y += GRAVITY * delta

	match state:
		State.CHASE:
			_state_chase(delta, player)
		State.MELEE:
			_state_melee(player)
		State.SLAM_WINDUP:
			_state_slam_windup(delta, player)
		State.SLAM_AIR:
			_state_slam_air(delta)
		State.SLAM_LAND:
			_state_slam_land(player)
		State.CHARGE_WINDUP:
			_state_charge_windup(delta, player)
		State.CHARGE:
			_state_charge(delta, player)
		State.SPIT:
			_state_spit(delta, player)
		State.TELEPORT:
			_state_teleport(delta, player)
		State.RAIN:
			_state_rain(delta)
		State.LUNGE_WINDUP:
			_state_lunge_windup(delta, player)
		State.LUNGE:
			_state_lunge(delta, player)
		State.SPIKES:
			_state_spikes(delta, player)
		State.BARRAGE:
			_state_barrage(delta, player)
		State.SPIRAL:
			_state_spiral(delta, player)
		State.EXECUTE_WINDUP:
			_state_execute_windup(delta, player)
		State.EXECUTE:
			_state_execute(delta, player)
		State.PHANTOMS:
			_state_phantoms(delta, player)
		State.SHIFT:
			_state_shift(delta)

	if player and state in [State.CHASE, State.MELEE, State.CHARGE_WINDUP, State.SPIT, State.RAIN,
			State.SLAM_WINDUP, State.LUNGE_WINDUP, State.BARRAGE, State.SPIKES, State.EXECUTE_WINDUP]:
		if absf(player.global_position.x - global_position.x) > 1.0:
			body.scale.x = signf(player.global_position.x - global_position.x)

	move_and_slide()

	if global_position.y > ARENA_FLOOR + 40.0 or global_position.y < ARENA_TOP:
		global_position.y = ARENA_FLOOR - 40.0
		velocity.y = 0.0
	global_position.x = clampf(global_position.x, ARENA_LEFT - 40.0, ARENA_RIGHT + 40.0)

	if hit_flash > 0.0:
		hit_flash = maxf(hit_flash - delta, 0.0)
		body.color = Color(1.0, 0.95, 0.95)


func _state_chase(delta: float, player: Node2D) -> void:
	_restore_body_color()
	telegraph.visible = false
	var vx := 0.0
	var dist := INF
	if player:
		dist = global_position.distance_to(player.global_position)
		var dir := signf(player.global_position.x - global_position.x)
		if absf(player.global_position.x - global_position.x) > MELEE_MOVE_RANGE:
			vx = dir * chase_speed
	velocity.x = move_toward(velocity.x, vx, 400.0 * delta)
	if attack_cooldown <= 0.0 and player:
		_choose_attack(dist)


func _build_pool(dist: float) -> Array[State]:
	var pool: Array[State] = []
	var close := dist <= MELEE_MOVE_RANGE + 30.0
	var mid := dist <= 340.0
	if boss_kind == BossKind.BROKEN:
		if close:
			pool.append(State.MELEE)
			pool.append(State.MELEE)
		pool.append(State.SPIT)
		pool.append(State.CHARGE_WINDUP)
		if mid:
			pool.append(State.SLAM_WINDUP)
		if phase == 1:
			return pool
		pool.append(State.LUNGE_WINDUP)
		pool.append(State.SPIKES)
		pool.append(State.BARRAGE)
		if phase == 2:
			return pool
		pool.append(State.LUNGE_WINDUP)
		pool.append(State.SPIRAL)
		pool.append(State.EXECUTE_WINDUP)
		pool.append(State.PHANTOMS)
		pool.append(State.MELEE)
		return pool
	if close:
		pool.append(State.MELEE)
	pool.append(State.SPIT)
	pool.append(State.TELEPORT)
	if mid:
		pool.append(State.SLAM_WINDUP)
		pool.append(State.CHARGE_WINDUP)
	if phase == 1:
		return pool
	pool.append(State.LUNGE_WINDUP)
	pool.append(State.SPIKES)
	pool.append(State.BARRAGE)
	pool.append(State.RAIN)
	if phase == 2:
		return pool
	pool.append(State.LUNGE_WINDUP)
	pool.append(State.SPIRAL)
	pool.append(State.EXECUTE_WINDUP)
	pool.append(State.PHANTOMS)
	pool.append(State.MELEE)
	pool.append(State.TELEPORT)
	return pool


func _pick_move(pool: Array[State]) -> State:
	var choice: State = pool.pick_random()
	for i in range(3):
		if choice != last_attack or pool.size() == 1:
			break
		choice = pool.pick_random()
	last_attack = choice
	return choice


func _choose_attack(dist: float) -> void:
	chain_pending = false
	set_state(_pick_move(_build_pool(dist)))


func _state_melee(player: Node2D) -> void:
	velocity.x = 0.0
	if state_time < 0.26:
		body.color = Color(1.0, 1.0, 0.4)
	elif state_time < 0.56:
		if not melee_done:
			melee_done = true
			if player and _player_in_melee_reach(player):
				player.take_damage(damage, false)
				_shake(5.0, 0.18)
	else:
		_end_attack(1.1)


func _state_slam_windup(delta: float, player: Node2D) -> void:
	velocity.x = 0.0
	body.color = Color(1.0, 0.55, 0.2)
	telegraph.visible = true
	telegraph.position = Vector2(-16, -12)
	telegraph.size = Vector2(32 + state_time * 240.0, 10)
	if state_time < 0.45 - float(phase - 1) * 0.07:
		return
	telegraph.position = Vector2(-8, -12)
	telegraph.size = Vector2(16, 10)
	landing_x = player.global_position.x if player else global_position.x
	velocity.y = -1300.0
	set_state(State.SLAM_AIR)


func _state_slam_air(delta: float) -> void:
	telegraph.visible = false
	body.color = Color(1.0, 0.7, 0.4)
	var diff := landing_x - global_position.x
	var target := signf(diff) * 180.0
	velocity.x = move_toward(velocity.x, target, 600.0 * delta)
	if absf(diff) < 12.0:
		velocity.x = 0.0
	if is_on_floor():
		set_state(State.SLAM_LAND)


func _state_slam_land(player: Node2D) -> void:
	velocity.x = 0.0
	body.color = Color(1.0, 0.4, 0.2)
	if state_time < 0.18:
		return
	if state_time < 0.5:
		if not slam_landed:
			slam_landed = true
			_spawn_shockwave()
			_shake(9.0, 0.25)
			if player and absf(player.global_position.x - global_position.x) < SLAM_RADIUS \
				and absf(player.global_position.y - global_position.y) < 130.0:
				player.take_damage(damage, false)
	else:
		_end_attack(1.2)


func _state_charge_windup(delta: float, player: Node2D) -> void:
	velocity.x = 0.0
	body.color = Color(1.0, 0.3, 0.8)
	if player:
		var dir := signf(player.global_position.x - global_position.x)
		if dir != 0.0:
			charge_dir = dir
			body.scale.x = dir
	telegraph.visible = true
	telegraph.position = Vector2(6.0 if charge_dir > 0.0 else -226.0, -12)
	telegraph.size = Vector2(220.0, 6)
	if state_time < 0.5 - float(phase - 1) * 0.08:
		return
	telegraph.visible = false
	set_state(State.CHARGE)


func _state_charge(_delta: float, player: Node2D) -> void:
	velocity.x = charge_dir * charge_speed
	velocity.y = 0.0
	body.color = Color(1.0, 0.6, 0.9)
	if player and absf(player.global_position.x - global_position.x) < 42.0 \
		and absf(player.global_position.y - global_position.y) < 120.0 and not charge_hit:
		charge_hit = true
		player.take_damage(damage, false)
		_shake(7.0, 0.2)
	if state_time > 0.8 or is_on_wall():
		_end_attack(1.0)


func _state_spit(delta: float, player: Node2D) -> void:
	velocity.x = 0.0
	body.color = Color(0.9, 0.4, 1.0)
	if state_time < 0.35:
		return
	if not spit_done:
		spit_done = true
		spit_timer = 0.0
		if player:
			_fire_spit(player)
	elif state_time > 0.45:
		_end_attack(1.0)


func _state_teleport(delta: float, player: Node2D) -> void:
	velocity.x = 0.0
	velocity.y = 0.0
	if state_time < 0.25:
		_restore_body_color()
		body.color = body.color.lightened(0.5)
		body.modulate.a = 0.4 + 0.6 * fmod(Time.get_ticks_msec() / 120.0, 2.0)
		return
	if state_time < 0.3:
		body.visible = false
		body.modulate.a = 1.0
		collision_layer = 0
		collision_mask = 0
		return
	if state_time < 0.7:
		if not tele_moved:
			tele_moved = true
			if player:
				var side := -signf(player.global_position.x - global_position.x)
				if side == 0.0:
					side = 1.0
				global_position = player.global_position + Vector2(side * 250.0, 0.0)
				global_position.x = clampf(global_position.x, ARENA_LEFT, ARENA_RIGHT)
			teleport_cooldown = 4.0
		return
	collision_layer = 1
	collision_mask = 1
	body.visible = true
	_restore_body_color()
	if phase >= 2 and randf() < 0.7:
		set_state(State.BARRAGE)
	else:
		_end_attack(0.4)


func _state_rain(_delta: float) -> void:
	velocity.x = 0.0
	body.color = Color(0.5, 0.4, 1.0)
	if state_time < 0.5:
		return
	if not rain_done:
		rain_done = true
		_do_rain()
	elif state_time > 0.7:
		_end_attack(1.2)


func _state_lunge_windup(delta: float, player: Node2D) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	body.color = Color(1.0, 0.45, 0.25)
	if state_time < 0.1:
		if player:
			charge_dir = signf(player.global_position.x - global_position.x)
			if charge_dir == 0.0:
				charge_dir = 1.0
			body.scale.x = charge_dir
		lunge_x = global_position.x + charge_dir * 260.0
		telegraph.visible = true
		telegraph.position = Vector2(6.0 if charge_dir > 0.0 else -266.0, -30)
		telegraph.size = Vector2(260.0, 8)
		return
	if state_time < 0.42:
		return
	telegraph.visible = false
	set_state(State.LUNGE)


func _state_lunge(delta: float, player: Node2D) -> void:
	velocity.x = charge_dir * 960.0
	body.color = Color(1.0, 0.65, 0.35)
	if player and lunge_hits < _lunge_hit_count() \
		and absf(player.global_position.x - global_position.x) < 62.0 \
		and absf(player.global_position.y - global_position.y) < 130.0:
		lunge_hits += 1
		player.take_damage(damage, false)
		_shake(8.0, 0.2)
	if state_time > 0.45 or is_on_wall():
		velocity.x = 0.0
		_end_attack(0.9)


func _lunge_hit_count() -> int:
	return 2 if phase == 3 else 1


func _state_spikes(delta: float, player: Node2D) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	body.color = Color(1.0, 0.8, 0.3)
	if state_time < 0.3:
		return
	if not burst_done:
		burst_done = true
		_spawn_spike_field(player)
	elif state_time > 0.75:
		_end_attack(1.0)


func _spawn_spike_field(player: Node2D) -> void:
	var count := 5 if phase == 2 else 7
	var center := player.global_position.x if player else global_position.x
	center = clampf(center, ARENA_LEFT + 40.0, ARENA_RIGHT - 40.0)
	var spacing := 62.0
	for i in range(count):
		var x := center + (float(i) - float(count - 1) * 0.5) * spacing + randf_range(-14.0, 14.0)
		x = clampf(x, ARENA_LEFT, ARENA_RIGHT)
		var spike := SPIKE_SCENE.instantiate()
		spike.global_position = Vector2(x, global_position.y)
		spike.damage = damage
		spike.delay = 0.6 + absf(i - (count - 1) * 0.5) * 0.05
		spike.modulate = body.color
		get_tree().current_scene.add_child(spike)
	_shake(6.0, 0.25)


func _state_barrage(delta: float, player: Node2D) -> void:
	body.color = Color(0.95, 0.55, 1.0)
	if state_time < 0.25:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	var vx := 0.0
	if player:
		vx = signf(player.global_position.x - global_position.x) * chase_speed * 0.45
	velocity.x = move_toward(velocity.x, vx, 700.0 * delta)
	spit_timer -= delta
	if spit_timer <= 0.0:
		spit_timer = 0.13
		if player:
			var origin := global_position + Vector2(0, -60)
			var aim := (player.global_position - origin).normalized()
			_spawn_tear(origin, aim.rotated(randf_range(-0.12, 0.12)) * 300.0, damage * 0.45)
	if state_time > 1.05:
		_end_attack(0.9)


func _state_spiral(delta: float, player: Node2D) -> void:
	if state_time < 0.4:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		body.color = Color(0.6, 0.35, 1.0)
		telegraph.visible = true
		telegraph.position = Vector2(-90, -90)
		telegraph.size = Vector2(180, 8)
		if state_time > 0.12:
			telegraph.visible = false
		return
	telegraph.visible = false
	body.color = Color(0.75, 0.45, 1.0)
	var vx := 0.0
	if player:
		vx = signf(player.global_position.x - global_position.x) * chase_speed * 0.3
	velocity.x = move_toward(velocity.x, vx, 400.0 * delta)
	spiral_angle += delta * 6.4
	spit_timer -= delta
	if spit_timer <= 0.0:
		spit_timer = 0.1
		var origin := global_position + Vector2(0, -60)
		var to_player := Vector2.from_angle((player.global_position - origin).angle()) if player else Vector2.UP
		for arm: int in [0, 1]:
			var ang := spiral_angle + float(arm) * PI + to_player.angle()
			_spawn_tear(origin, Vector2.from_angle(ang) * 190.0, damage * 0.4)
	if state_time > 2.1:
		velocity.x = 0.0
		vulnerable_time = 0.9
		_end_attack(1.1)


func _state_execute_windup(delta: float, player: Node2D) -> void:
	velocity.x = 0.0
	body.color = Color(1.0, 0.25, 0.25)
	if state_time < 0.12 and player:
		execute_x = clampf(player.global_position.x, ARENA_LEFT + 60.0, ARENA_RIGHT - 60.0)
		telegraph.visible = true
		telegraph.color = Color(1.0, 0.2, 0.2, 0.8)
		telegraph.position = Vector2(execute_x - global_position.x - 80.0, -6)
		telegraph.size = Vector2(160, 10)
		return
	if state_time < 0.8:
		return
	telegraph.visible = false
	_shake(6.0, 0.2)
	set_state(State.EXECUTE)


func _state_execute(delta: float, player: Node2D) -> void:
	body.color = Color(1.0, 0.35, 0.3)
	velocity.x = signf(execute_x - global_position.x) * 900.0
	if state_time < 0.18:
		velocity.y = -760.0
		return
	if player and not execute_hit and absf(player.global_position.x - execute_x) < 130.0 \
		and absf(player.global_position.y - global_position.y) < 150.0:
		execute_hit = true
		player.take_damage(damage * 1.7, false)
		_shake(16.0, 0.4)
		_burst_tears(10, 260.0)
	if absf(global_position.x - execute_x) < 24.0 or state_time > 1.2 or is_on_wall():
		velocity.x = 0.0
		vulnerable_time = 1.0
		_end_attack(1.1)


func _state_phantoms(delta: float, player: Node2D) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	body.color = Color(0.55, 0.3, 0.7)
	if state_time < 0.35:
		return
	if not burst_done:
		burst_done = true
		_spawn_phantoms()
	elif state_time > 0.8:
		_end_attack(1.0)


func _spawn_phantoms() -> void:
	for i in range(2):
		var phantom := Node2D.new()
		phantom.set_script(PHANTOM_SCRIPT)
		phantom.set("base_color", body.color)
		phantom.set("fire_damage", damage * 0.4)
		phantom.global_position = Vector2(clampf(global_position.x + (60.0 + 70.0 * float(i)) * (1.0 if i == 0 else -1.0), ARENA_LEFT, ARENA_RIGHT), global_position.y)
		get_tree().current_scene.add_child(phantom)
	_shake(8.0, 0.3)


func _state_shift(_delta: float) -> void:
	velocity.x = 0.0
	telegraph.visible = false
	var pulse := absf(sin(state_time * 16.0))
	body.color = (ENRAGED_COLOR if phase == 3 else _base_color()).lerp(Color(1, 1, 1), pulse * 0.7)
	if state_time < 1.3:
		return
	invulnerable = false
	_burst_tears(12 + phase * 2, 300.0)
	_shake(14.0, 0.5)
	_end_attack(0.6)


func set_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	match new_state:
		State.MELEE:
			melee_done = false
		State.SPIT:
			spit_done = false
		State.RAIN:
			rain_done = false
		State.TELEPORT:
			tele_moved = false
		State.CHARGE_WINDUP:
			charge_dir = -body.scale.x if body.scale.x != 0.0 else 1.0
		State.CHARGE:
			charge_hit = false
			charge_speed = (520.0 if boss_kind == BossKind.BROKEN else 640.0) * (1.0 + 0.18 * float(phase - 1))
		State.SLAM_WINDUP:
			slam_landed = false
			telegraph.visible = true
		State.SLAM_LAND:
			slam_landed = false
		State.LUNGE:
			lunge_hits = 0
		State.SPIKES, State.PHANTOMS:
			burst_done = false
		State.BARRAGE, State.SPIRAL:
			spit_timer = 0.0
		State.EXECUTE:
			execute_hit = false


func _end_attack(cooldown: float) -> void:
	attack_cooldown = cooldown * PHASE_COOLDOWN[phase]
	chain_pending = chain_count < CHAIN_CAP[phase] and randf() < PHASE_CHAIN[phase]
	if chain_pending:
		chain_count += 1
		attack_cooldown = 0.18
	else:
		chain_count = 0
	body.visible = true
	body.modulate.a = 1.0
	collision_layer = 1
	collision_mask = 1
	telegraph.visible = false
	_restore_body_color()
	set_state(State.CHASE)


func _fire_spit(player: Node2D) -> void:
	var origin := global_position + Vector2(0, -60)
	var shots := 5 if phase >= 3 else 3
	if boss_kind == BossKind.SWEETHEART:
		var base_deg := rad_to_deg((player.global_position - global_position).angle())
		for i in range(0, shots, 2):
			var dir := Vector2.from_angle(deg_to_rad(base_deg + i * 16.0 - float(shots / 2) * 16.0))
			_spawn_tear(origin, dir * 235.0, 8.0)
	else:
		var to_player := (player.global_position - global_position).normalized()
		_spawn_tear(origin, to_player * 255.0, 8.0)
		_spawn_tear(origin + Vector2(0, -14), to_player.rotated(0.22) * 235.0, 8.0)
		_spawn_tear(origin + Vector2(0, -14), to_player.rotated(-0.22) * 235.0, 8.0)


func _spawn_tear(at: Vector2, dir: Vector2, dmg: float) -> void:
	var tear := TEAR_SCENE.instantiate()
	tear.global_position = at
	tear.vel = dir
	tear.damage = dmg
	get_tree().current_scene.add_child(tear)


func _burst_tears(count: int, speed: float) -> void:
	var origin := global_position + Vector2(0, -60)
	for i in range(count):
		var ang := TAU * float(i) / float(count) + randf_range(-0.1, 0.1)
		_spawn_tear(origin, Vector2.from_angle(ang) * speed, damage * 0.35)


func _do_rain() -> void:
	var count := 9 if phase >= 3 else 6
	var marks: Array[ColorRect] = []
	for i in range(count):
		var x := randf_range(ARENA_LEFT, ARENA_RIGHT)
		var m := ColorRect.new()
		m.color = Color(1.0, 0.35, 0.5, 0.55)
		m.size = Vector2(18, 10)
		m.position = Vector2(x - 9.0, global_position.y - 60.0)
		get_tree().current_scene.add_child(m)
		marks.append(m)
	var tw := create_tween()
	tw.tween_interval(0.65)
	for mark in marks:
		tw.parallel().tween_property(mark, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		for m in marks:
			m.queue_free()
	)
	for i in range(count):
		var x := randf_range(ARENA_LEFT, ARENA_RIGHT)
		var tear := TEAR_SCENE.instantiate()
		tear.global_position = Vector2(x, global_position.y - 560.0)
		tear.vel = Vector2(0, 40)
		tear.damage = 7.0
		tear.accelerates = true
		tear.max_speed = 330.0 + 60.0 * float(phase - 1)
		get_tree().current_scene.add_child(tear)


func _spawn_shockwave() -> void:
	var sw := ColorRect.new()
	sw.color = Color(1.0, 0.75, 0.3, 0.85) if boss_kind == BossKind.BROKEN else Color(1.0, 0.45, 0.85, 0.85)
	sw.size = Vector2(18, 16)
	sw.position = global_position + Vector2(-9, -72)
	sw.pivot_offset = Vector2(9, 8)
	get_parent().add_child(sw)
	var tw := create_tween()
	tw.tween_property(sw, "scale", Vector2(16.0, 1.4), 0.3)
	tw.parallel().tween_property(sw, "modulate:a", 0.0, 0.3)
	tw.tween_callback(sw.queue_free)


func _player_in_melee_reach(player: Node2D) -> bool:
	return absf(player.global_position.x - global_position.x) < MELEE_REACH \
		and absf(player.global_position.y - global_position.y) < 120.0


func _base_color() -> Color:
	return ENRAGED_COLOR if enraged else (BROKEN_BASE_COLOR if boss_kind == BossKind.BROKEN else SWEET_BASE_COLOR)


func _restore_body_color() -> void:
	body.color = VULNERABLE_COLOR if vulnerable_time > 0.0 else _base_color()


func _set_title() -> void:
	if title_label:
		title_label.text = TITLES[boss_kind][phase - 1]


func _update_names() -> void:
	var text := base_name
	if second_wind_used:
		text += " [SECOND WIND]"
	elif phase == 3:
		text += " [ENRAGED]"
	name_label.text = text
	if boss_name_label:
		boss_name_label.text = text
	if boss_bar:
		boss_bar.self_modulate = Color(1, 0.5, 0.5) if phase == 3 else Color(1, 1, 1)


func _shake(amount: float, time: float) -> void:
	var cam := _get_camera()
	if not cam:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps := 6
	for i in range(steps):
		var falloff := 1.0 - float(i) / float(steps)
		_shake_tween.tween_property(cam, "offset",
			Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount * falloff, time / float(steps))
	_shake_tween.tween_property(cam, "offset", Vector2.ZERO, 0.06)


func _clear_hazards() -> void:
	for hazard in get_tree().get_nodes_in_group("boss_hazard"):
		if hazard != self:
			hazard.queue_free()


func take_hit(dmg: float, dir: float) -> void:
	if not alive or invulnerable:
		return
	var dealt := dmg * (VULNERABLE_MULT if vulnerable_time > 0.0 else 1.0)
	hp -= dealt
	velocity.x = dir * 140.0
	velocity.y = -110.0
	hit_flash = 0.12
	_check_second_wind()
	_check_phase()
	if hp <= max_hp * DEATH_RATIO:
		hp = 0.0
		die()


func _check_second_wind() -> void:
	if second_wind_used or phase < 3 or hp / max_hp > SECOND_WIND_RATIO or hp <= 0.0:
		return
	second_wind_used = true
	hp = maxf(hp, max_hp * SECOND_WIND_HEAL)
	damage += 6.0
	chase_speed += 26.0
	_update_names()
	_set_title()
	_burst_tears(16, 320.0)
	_shake(18.0, 0.6)
	invulnerable = true
	set_state(State.SHIFT)


func _check_phase() -> void:
	var ratio := hp / max_hp
	var new_phase := 1
	if ratio <= PHASE3_RATIO:
		new_phase = 3
	elif ratio <= PHASE2_RATIO:
		new_phase = 2
	if new_phase > phase:
		phase = new_phase
		_apply_phase_stats()
		_begin_shift()


func _apply_phase_stats() -> void:
	damage = base_damage + PHASE_DAMAGE[phase]
	chase_speed = base_chase + PHASE_CHASE[phase]
	enraged = phase == 3
	_update_names()
	_set_title()


func _begin_shift() -> void:
	invulnerable = true
	vulnerable_time = 0.0
	chain_pending = false
	chain_count = 0
	_clear_hazards()
	_restore_body_color()
	set_state(State.SHIFT)


func die() -> void:
	if not alive:
		return
	alive = false
	invulnerable = true
	GameState.add_money(100)
	GameState.add_exp(200)
	_clear_hazards()
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	telegraph.visible = false
	name_label.text = "DEFEATED"
	if title_label:
		title_label.text = "NOW SING FOR YOUR SOUL" if GameState.defeated_exes + 1 >= 2 else "ONE HEART DOWN"
	if boss_bar:
		boss_bar.value = 0
	await get_tree().create_timer(1.4).timeout
	GameState.defeated_exes += 1
	if GameState.defeated_exes >= 2:
		GameState.dialogue_lines = [
			{"speaker": "Aphrodite", "text": "Impressive, mortal. Two broken hearts, both beaten to a pulp..."},
			{"speaker": "Aphrodite", "text": "But love is never won with fists. Love is a SONG, Nate Hopkins."},
			{"speaker": "???", "text": "Proof you deserve another chance... must be sung beautifully."},
			{"speaker": "Nate", "text": "Seriously? A dating game taught me how to fight. Now I have to learn to sing too?"},
			{"speaker": "Aphrodite", "text": "Sing, and the Underworld will set you free. Miss the beat, and you begin again."},
		]
		GameState.rhythm_window = 1.0
		GameState.rhythm_notes = 30
		GameState.rhythm_followup_lines = [
			{"speaker": "Nate", "text": "Hazel... I clawed my way out of the actual Underworld for this."},
			{"speaker": "Hazel", "text": "...That's the weirdest pickup line I've ever heard."},
			{"speaker": "Hazel", "text": "But I guess anyone who fights through Hell deserves a first date. Dinner?"},
			{"speaker": "Narrator", "text": "Nate became a master of the Underworld dating circuit. 10/10 no notes."},
		]
		GameState.rhythm_followup_scene = "res://scenes/ui/main.tscn"
		GameState.scene_after_dialogue = "res://scenes/bosses/final_rhythm.tscn"
	else:
		GameState.dialogue_lines = [
			{"speaker": "Aphrodite", "text": "One heart down, one to go. But don't celebrate yet, Nate Hopkins."},
			{"speaker": "???", "text": "You really don't remember me? My heart was yours first. And you broke it first."},
			{"speaker": "???", "text": "You've learned to fight. Now prove you can keep a beat."},
			{"speaker": "Nate", "text": "A rhythm game? In the Underworld? Who designed this place?"},
		]
		GameState.rhythm_window = 1.0
		GameState.rhythm_notes = 20
		GameState.rhythm_followup_lines = []
		GameState.rhythm_followup_scene = "res://scenes/levels/level5.tscn"
		GameState.scene_after_dialogue = "res://scenes/bosses/final_rhythm.tscn"
	get_tree().change_scene_to_file("res://scenes/dialogue/dialogue.tscn")

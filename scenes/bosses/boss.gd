extends CharacterBody2D

enum BossKind { BROKEN, SWEETHEART }
enum State { CHASE, MELEE, SLAM_WINDUP, SLAM_AIR, SLAM_LAND, CHARGE_WINDUP, CHARGE, SPIT, TELEPORT, RAIN }

const GRAVITY := 1600.0
const MELEE_MOVE_RANGE := 56.0
const MELEE_REACH := 76.0
const SLAM_RADIUS := 130.0
const CHARGE_ACCEL := 2600.0
const TEAR_SCENE := preload("res://scenes/bosses/boss_tear.tscn")

const BROKEN_BASE_COLOR := Color(0.95, 0.3, 0.5)
const SWEET_BASE_COLOR := Color(0.75, 0.4, 0.95)
const ENRAGED_COLOR := Color(1.0, 0.2, 0.2)

var boss_kind := BossKind.BROKEN
var hp := 300.0
var max_hp := 300.0
var chase_speed := 70.0
var damage := 14.0
var alive := true
var enraged := false
var phase := 1

var attack_cooldown := 1.2
var teleport_cooldown := 0.0

var state := State.CHASE
var state_time := 0.0
var hit_flash := 0.0

var melee_done := false
var spit_done := false
var rain_done := false
var tele_moved := false
var charge_hit := false
var slam_landed := false
var landing_x := 0.0
var charge_dir := 1.0
var charge_speed := 520.0

@onready var body: ColorRect = $Body
@onready var name_label: Label = $NameLabel
@onready var telegraph: ColorRect = $Telegraph

var boss_bar: ProgressBar
var boss_name_label: Label


func _ready() -> void:
	add_to_group("enemy")
	hp = 280.0 + GameState.defeated_exes * 160.0
	max_hp = hp
	boss_kind = BossKind.BROKEN if GameState.defeated_exes == 0 else BossKind.SWEETHEART
	if boss_kind == BossKind.BROKEN:
		name_label.text = "THE ONE YOU HURT"
		chase_speed = 70.0
		damage = 14.0
	else:
		name_label.text = "FIRST LOVE"
		chase_speed = 95.0
		damage = 12.0
	_restore_body_color()
	var hud := get_parent().get_node_or_null("BossHUD")
	if hud:
		boss_bar = hud.get_node_or_null("BossBar")
		boss_name_label = hud.get_node_or_null("BossNameLabel")
		if boss_bar:
			boss_bar.max_value = max_hp
			boss_bar.value = hp
		if boss_name_label:
			boss_name_label.text = name_label.text


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if boss_bar:
		boss_bar.value = hp
	state_time += delta
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	teleport_cooldown = maxf(teleport_cooldown - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player")

	if state == State.CHASE or state == State.MELEE or state == State.SLAM_WINDUP \
		or state == State.SLAM_AIR or state == State.SLAM_LAND or state == State.SPIT \
		or state == State.RAIN or state == State.CHARGE_WINDUP or state == State.TELEPORT:
		if not is_on_floor() and body.visible:
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

	if player and state in [State.CHASE, State.MELEE, State.CHARGE_WINDUP, State.SPIT, State.RAIN, State.SLAM_WINDUP]:
		if absf(player.global_position.x - global_position.x) > 1.0:
			body.scale.x = signf(player.global_position.x - global_position.x)

	move_and_slide()

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
		_choose_attack(player, dist)


func _choose_attack(player: Node2D, dist: float) -> void:
	var r := randf()
	if boss_kind == BossKind.BROKEN:
		if dist <= MELEE_MOVE_RANGE + 24.0:
			set_state(State.MELEE)
		elif phase >= 3:
			if r < 0.35:
				set_state(State.CHARGE_WINDUP)
			elif r < 0.7:
				set_state(State.SPIT)
			else:
				set_state(State.SLAM_WINDUP)
		elif phase >= 2:
			if r < 0.5:
				set_state(State.SLAM_WINDUP)
			else:
				attack_cooldown = 0.3
		else:
			set_state(State.MELEE)
	else:
		if dist <= MELEE_MOVE_RANGE + 24.0 and r < 0.5:
			set_state(State.MELEE)
		else:
			var want_teleport := r >= 0.82 if phase == 1 else (r >= 0.78 if phase == 2 else r >= 0.7)
			if want_teleport and teleport_cooldown <= 0.0:
				set_state(State.TELEPORT)
			elif phase >= 3:
				if r < 0.3:
					set_state(State.SPIT)
				elif r < 0.5:
					set_state(State.RAIN)
				elif r < 0.78:
					set_state(State.CHARGE_WINDUP)
				else:
					set_state(State.SPIT)
			elif phase >= 2:
				if r < 0.4:
					set_state(State.SPIT)
				elif r < 0.62:
					set_state(State.CHARGE_WINDUP)
				else:
					set_state(State.SPIT)
			else:
				set_state(State.SPIT)


func _state_melee(player: Node2D) -> void:
	velocity.x = 0.0
	if state_time < 0.26:
		body.color = Color(1.0, 1.0, 0.4)
	elif state_time < 0.56:
		if not melee_done:
			melee_done = true
			if player and _player_in_melee_reach(player):
				player.take_damage(damage, false)
	else:
		_end_attack(1.1)


func _state_slam_windup(delta: float, player: Node2D) -> void:
	velocity.x = 0.0
	body.color = Color(1.0, 0.55, 0.2)
	telegraph.visible = true
	telegraph.position = Vector2(-16, -12)
	telegraph.size = Vector2(32 + state_time * 240.0, 10)
	if state_time < 0.45:
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
	if state_time < 0.5:
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
	if state_time > 0.8 or is_on_wall():
		_end_attack(1.0)


func _state_spit(delta: float, player: Node2D) -> void:
	velocity.x = 0.0
	body.color = Color(0.9, 0.4, 1.0)
	if state_time < 0.35:
		return
	if not spit_done:
		spit_done = true
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
				global_position.x = clampf(global_position.x, 60.0, 840.0)
			teleport_cooldown = 4.0
		return
	collision_layer = 1
	collision_mask = 1
	body.visible = true
	_restore_body_color()
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
			charge_speed = 520.0 if boss_kind == BossKind.BROKEN else 640.0
		State.SLAM_WINDUP:
			slam_landed = false
			telegraph.visible = true
		State.SLAM_LAND:
			slam_landed = false


func _end_attack(cooldown: float) -> void:
	attack_cooldown = cooldown
	body.visible = true
	body.modulate.a = 1.0
	collision_layer = 1
	collision_mask = 1
	telegraph.visible = false
	_restore_body_color()
	set_state(State.CHASE)


func _fire_spit(player: Node2D) -> void:
	var origin := global_position + Vector2(0, -60)
	if boss_kind == BossKind.SWEETHEART:
		var base_deg := rad_to_deg((player.global_position - global_position).angle())
		for i in range(-2, 3):
			var dir := Vector2.from_angle(deg_to_rad(base_deg + i * 16.0))
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


func _do_rain() -> void:
	var marks: Array[ColorRect] = []
	for i in range(6):
		var x := randf_range(60.0, 840.0)
		var m := ColorRect.new()
		m.color = Color(1.0, 0.35, 0.5, 0.55)
		m.size = Vector2(18, 10)
		m.position = Vector2(x - 9.0, global_position.y - 60.0)
		get_tree().current_scene.add_child(m)
		marks.append(m)
	var tw := create_tween()
	tw.tween_interval(0.65)
	tw.tween_property(marks[0], "modulate:a", 0.0, 0.3)
	for i in range(1, marks.size()):
		var idx := i
		tw.parallel().tween_property(marks[idx], "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		for m in marks:
			m.queue_free()
	)
	for i in range(6):
		var x := randf_range(60.0, 840.0)
		var tear := TEAR_SCENE.instantiate()
		tear.global_position = Vector2(x, global_position.y - 560.0)
		tear.vel = Vector2(0, 40)
		tear.damage = 7.0
		tear.accelerates = true
		tear.max_speed = 330.0
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


func _restore_body_color() -> void:
	body.color = ENRAGED_COLOR if enraged else (BROKEN_BASE_COLOR if boss_kind == BossKind.BROKEN else SWEET_BASE_COLOR)


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	hp -= dmg
	velocity.x = dir * 140.0
	velocity.y = -110.0
	hit_flash = 0.12
	_check_phase()
	if hp <= 0.0:
		die()


func _check_phase() -> void:
	var ratio := hp / max_hp
	var new_phase := 1
	if ratio <= 0.45:
		new_phase = 3
	elif ratio <= 0.65:
		new_phase = 2
	if new_phase > phase:
		phase = new_phase
		if phase == 3 and not enraged:
			enraged = true
			chase_speed += 45.0
			damage += 4.0
			name_label.text += " [ENRAGED]"
			if boss_name_label:
				boss_name_label.text = name_label.text
			if boss_bar:
				boss_bar.self_modulate = Color(1, 0.5, 0.5)
		_restore_body_color()
		if state == State.CHASE:
			set_state(State.SLAM_WINDUP)


func die() -> void:
	if not alive:
		return
	alive = false
	GameState.add_money(100)
	GameState.add_exp(200)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	telegraph.visible = false
	name_label.text = "DEFEATED"
	body.color = Color(0.3, 0.3, 0.3)
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

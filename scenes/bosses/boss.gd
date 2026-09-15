extends CharacterBody2D

var hp := 300.0
var max_hp := 300.0
var speed := 70.0
var damage := 14.0
const GRAVITY := 1600.0

var alive := true
var attack_cooldown := 1.5
var enraged := false

@onready var body: ColorRect = $Body
@onready var name_label: Label = $NameLabel

var boss_bar: ProgressBar
var boss_name_label: Label


func _ready() -> void:
	add_to_group("enemy")
	hp = 280.0 + GameState.defeated_exes * 160.0
	max_hp = hp
	if GameState.defeated_exes == 0:
		name_label.text = "THE ONE YOU HURT"
	else:
		name_label.text = "FIRST LOVE"
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
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	attack_cooldown -= delta
	var player := get_tree().get_first_node_in_group("player")
	var vx := 0.0
	if player:
		var dir := signf(player.global_position.x - global_position.x)
		if absf(player.global_position.x - global_position.x) > 56.0:
			vx = dir * speed
		if dir != 0.0:
			body.scale.x = dir
		if global_position.distance_to(player.global_position) < 56.0 and attack_cooldown <= 0.0:
			attack_cooldown = 1.0
			if player.has_method("take_damage"):
				player.take_damage(damage)
	velocity.x = move_toward(velocity.x, vx, 400.0 * delta)
	move_and_slide()


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	hp -= dmg
	velocity.x = dir * 140.0
	velocity.y = -110.0
	if hp <= max_hp * 0.45 and not enraged:
		enraged = true
		speed = 115.0
		damage = 18.0
		body.color = Color(1.0, 0.2, 0.2)
		name_label.text += " [ENRAGED]"
		if boss_bar:
			boss_bar.self_modulate = Color(1, 0.5, 0.5)
		if boss_name_label:
			boss_name_label.text = name_label.text
	if hp <= 0.0:
		die()


func die() -> void:
	if not alive:
		return
	alive = false
	GameState.add_money(100)
	GameState.add_exp(200)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	name_label.text = "DEFEATED"
	body.color = Color(0.3, 0.3, 0.3)
	if boss_bar:
		boss_bar.value = 0
	await get_tree().create_timer(1.4).timeout
	GameState.defeated_exes += 1
	if GameState.defeated_exes >= 2:
		GameState.dialogue_lines = [
			{"speaker": "Nate", "text": "Hazel... I clawed my way out of the actual Underworld for this."},
			{"speaker": "Hazel", "text": "...That's the weirdest pickup line I've ever heard."},
			{"speaker": "Hazel", "text": "But I guess anyone who fights through Hell deserves a first date. Dinner?"},
			{"speaker": "Narrator", "text": "Nate became a master of the Underworld dating circuit. 10/10 no notes."},
		]
		GameState.scene_after_dialogue = "res://scenes/ui/main.tscn"
	else:
		GameState.dialogue_lines = [
			{"speaker": "???", "text": "So you're crawling back up, are you?"},
			{"speaker": "Nate", "text": "Who's there?"},
			{"speaker": "???", "text": "You really don't remember me? My heart was yours first. And you broke it first."},
			{"speaker": "???", "text": "Let's see if you've learned anything, Nate Jacobs."},
		]
		GameState.scene_after_dialogue = "res://scenes/levels/level5.tscn"
	get_tree().change_scene_to_file("res://scenes/dialogue/dialogue.tscn")
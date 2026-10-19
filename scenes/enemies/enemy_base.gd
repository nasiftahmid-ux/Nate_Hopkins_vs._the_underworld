extends CharacterBody2D
class_name EnemyBase
# Shared behavior for all ground enemies: hp, hit flash, death rewards and coin drop.

@export var max_hp := 30.0
@export var exp_reward := 20
@export var money_reward := 0
@export var hit_color := Color(1.0, 0.85, 0.4)
@export var hit_flash_time := 0.1
@export var death_delay := 0.6
@export var knockback_x := 220.0
@export var knockback_y := -180.0
## Logical Sfx names. Subclasses set these in `_ready()`; empty means silent.
@export var attack_sound := ""
@export var death_sound := ""
## A peaceful enemy still walks and can be hit, but never attacks the player.
@export var peaceful := false

## How many coins a kill's payout is broken into, and what that payout is.
## Splitting it means a kill scatters several coins that each have to be run
## down on their own before they time out.
const COIN_DROP := 5
const COIN_SPLIT := 3

## Reaction window for a timed parry: the player's block only counts if Q was
## pressed within this many seconds of the hit landing.
const PARRY_WINDOW := 0.5
## How long an enemy holds off attacking after the player parries it, so a
## successful block actually buys breathing room.
const BLOCK_RECOVERY := 1.5
## How long an enemy is staggered by the player's uppercut. Shorter than the
## boss's stun: against a regular enemy this is a punish, not a phase.
const STUN_DURATION := 1.0
## Seconds between footsteps while walking. Matches Nate's cadence exactly, so
## every walker in the game paces the same way.
const STEP_INTERVAL := 0.3
## Y below which an enemy that fell out of the level is removed. A fall counts
## as a kill for clearing the stage, but pays nothing: the coins would drop into
## the void with the enemy.
const KILL_PLANE_Y := 640.0

var hp: float
var alive := true
## Seconds left in an uppercut stagger; while it runs the enemy skips its AI.
var stun_time := 0.0
## Footstep cadence clock, reset whenever the enemy is not actually walking.
var _step_timer := 0.0

@onready var body: ColorRect = $Body

var _player: Node2D


func _ready() -> void:
	hp = max_hp
	add_to_group("enemy")


func _get_player() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	return _player


## Called by the player when this enemy's hit is parried. Pushes any pending
## attack back so the block is rewarded with a pause. Enemies that gate on a
## different timer (e.g. a ranged fire timer) can override this.
func on_blocked() -> void:
	if "attack_cooldown" in self:
		set("attack_cooldown", maxf(float(get("attack_cooldown")), BLOCK_RECOVERY))


## Called by the player when an uppercut connects. Staggers this enemy for
## `duration` seconds: it stops walking, attacking and dodging, and holds its
## hurt pose so the window is readable. Already-dead enemies ignore it.
func on_uppercut(duration: float = STUN_DURATION) -> void:
	if not alive:
		return
	stun_time = maxf(stun_time, duration)


## Ticks the stagger clock and holds the enemy in place. Returns true while the
## enemy is staggered, in which case the caller skips its AI for that frame.
## Gravity is applied by the caller before this runs, so a staggered enemy
## still falls out of a jump instead of hanging in the air.
func _stun_tick(delta: float) -> bool:
	if stun_time <= 0.0:
		return false
	stun_time -= delta
	# Let any knockback from the hit slide and settle rather than freezing it.
	velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	move_and_slide()
	return true


## Plays a footstep at Nate's cadence while the enemy is actually walking on
## the ground. Call it with the enemy's *intended* movement (the speed its AI
## asked for), not its velocity, so a knockback from a hit never counts as a
## step. Silent while airborne, idle or staggered.
func _update_footsteps(delta: float, moving: bool) -> void:
	if not moving or not is_on_floor():
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		Sfx.play("step", -18.0, randf_range(0.94, 1.06))
		_step_timer = STEP_INTERVAL


## Plays the subclass's attack cue, if it has one. Call this wherever the enemy
## commits to a swing, shot, or lunge.
func play_attack_sound() -> void:
	if attack_sound.is_empty():
		return
	Sfx.play(attack_sound, -3.0, randf_range(0.95, 1.06))


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	hp -= dmg
	velocity.x = dir * knockback_x
	velocity.y = knockback_y
	body.color = hit_color
	get_tree().create_timer(hit_flash_time).timeout.connect(_reset_color)
	if hp <= 0.0:
		die()


func _reset_color() -> void:
	body.color = _base_color()


func _base_color() -> Color:
	return Color(0.85, 0.2, 0.25, 1)


## Watches for the enemy being knocked or shoved off the bottom of the level.
## Runs on every enemy every frame, but the check is a single float compare, and
## no subclass defines `_process`, so nothing here is overridden.
func _process(_delta: float) -> void:
	if alive and global_position.y > KILL_PLANE_Y:
		_fall_out()


## Removes an enemy that fell out of the level. It counts as cleared (the door
## checks `alive`), but pays no exp or coins and plays no death sound: the player
## never saw it land, and any payout would scatter into the void.
func _fall_out() -> void:
	if not alive:
		return
	alive = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	queue_free()


func die() -> void:
	if not alive:
		return
	alive = false
	if not death_sound.is_empty():
		Sfx.play(death_sound, -3.0, randf_range(0.94, 1.06))
	GameState.add_exp(exp_reward)
	if money_reward > 0:
		GameState.add_money(money_reward)
	_spawn_coin()
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	body.color = Color(0.35, 0.35, 0.35)
	await get_tree().create_timer(death_delay).timeout
	queue_free()


func _spawn_coin() -> void:
	_spawn_coins(COIN_DROP, COIN_SPLIT)


## Bursts a kill's payout as several coins instead of one tidy pickup. The total
## is unchanged, so the run's theoretical income still holds; what changes is how
## much of it the player actually manages to chase down before they evaporate.
func _spawn_coins(total: int, pieces: int) -> void:
	if total <= 0:
		return
	var count := maxi(1, mini(pieces, total))
	var scene := preload("res://scenes/items/coin.tscn")
	var each := total / count
	var remainder := total % count
	for i in range(count):
		var coin: Node2D = scene.instantiate()
		# Hand the leftover coins to the first few pieces so the split is exact.
		coin.value = each + (1 if i < remainder else 0)
		coin.global_position = global_position + Vector2(randf_range(-6, 6), -20)
		coin.rotation = randf_range(-PI, PI)
		get_tree().current_scene.add_child(coin)
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

## --- Awareness -------------------------------------------------------------
## Every enemy starts out unaware: it idles or patrols around `home` and only
## engages once it actually sees the player. A packmate that spots the player
## shares the alert with the rest of its pack.
enum Awareness { UNAWARE, ALERTED, COMBAT, RETURNING }

@export_group("Awareness")
## How far the enemy can spot the player across open ground.
@export var detection_radius := 280.0
## Vertical cutoff: a platform enemy does not spot a player far above or below.
@export var max_detect_height := 190.0
## Forward cone for spotting, in degrees. 360 disables the cone entirely.
@export var fov_degrees := 165.0
## How far an alert is shared with packmates of the same pack.
@export var alert_share_radius := 360.0
## Seconds without sight before an engaged enemy gives up and heads home.
@export var lose_interest_time := 4.0
## How far an idle enemy wanders from `home` before turning back.
@export var patrol_radius := 60.0
## Idle walking speed, as a fraction of the enemy's combat speed.
@export var patrol_speed_scale := 0.45
## Seconds between line-of-sight checks. Detection is deliberately polled rather
## than run every frame: a handful of raycasts per second per enemy is plenty.
@export var detect_interval := 0.15

## Which pack this enemy belongs to (assigned by the level's enemy director).
## A value of -1 means packless, in which case alerts are shared by proximity.
var pack_id := -1
## Where the enemy idles and where it returns to once it loses the player.
var home := Vector2.ZERO
var awareness := Awareness.UNAWARE

## How long the "!" alert cue hangs above an enemy that just noticed the player.
const ALERT_CUE_TIME := 0.4

var _detect_timer := 0.0
var _lost_timer := 0.0
var _alerted_timer := 0.0
var _patrol_target_x := 0.0
var _patrol_pause := 0.0
var _last_seen := Vector2.ZERO
var _ai_rng := RandomNumberGenerator.new()

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
	# Idle wherever the level author dropped us unless the director re-homes us.
	home = global_position
	_patrol_target_x = home.x
	# Deterministic fallback, so a level with no director still behaves the same
	# from run to run. The director replaces this with the level's own seed.
	_ai_rng.seed = hash(name)


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


## --- Awareness -------------------------------------------------------------


## Seeds this enemy's idle/patrol randomness. The level's enemy director calls
## this with a deterministic value so a fixed `debug_seed` reproduces the exact
## same patrol layout run to run.
func set_ai_seed(seed_value: int) -> void:
	_ai_rng.seed = seed_value


## Direction the enemy is currently facing, used to gate its vision cone.
## Subclasses that track facing override this; returning 0 means "no cone", so
## an enemy with no facing at all still notices the player in every direction.
func awareness_facing() -> float:
	return 0.0


## True while this enemy is actively engaging the player. Peaceful enemies are
## never in combat, so they idle, notice and look, but never close in or attack.
func _in_combat() -> bool:
	return awareness == Awareness.COMBAT and alive


## Advances the awareness state machine. Subclasses call this once per frame
## (after gravity, before their own AI) and then branch on `awareness`.
func _update_awareness(delta: float) -> void:
	if not alive:
		return
	if _alerted_timer > 0.0:
		_alerted_timer -= delta
	_detect_timer -= delta
	if _detect_timer > 0.0:
		return
	_detect_timer = detect_interval

	var sees := _can_see_player()
	match awareness:
		Awareness.UNAWARE:
			if sees:
				_become_alerted()
		Awareness.ALERTED:
			if sees:
				if not peaceful:
					_enter_combat()
				_lost_timer = 0.0
			else:
				_lost_timer += detect_interval
				if _lost_timer >= lose_interest_time:
					_start_returning()
		Awareness.COMBAT:
			if sees:
				_lost_timer = 0.0
			else:
				_lost_timer += detect_interval
				if _lost_timer >= lose_interest_time:
					_start_returning()
		Awareness.RETURNING:
			if sees:
				if peaceful:
					_become_alerted()
				else:
					_enter_combat()
			elif absf(global_position.x - home.x) < 10.0 and is_on_floor():
				awareness = Awareness.UNAWARE
				_patrol_target_x = home.x
				_patrol_pause = _ai_rng.randf_range(0.3, 1.0)


func _become_alerted() -> void:
	if awareness == Awareness.COMBAT:
		return
	awareness = Awareness.ALERTED
	_lost_timer = 0.0
	_alerted_timer = ALERT_CUE_TIME
	play_alert_cue()
	_share_alert()


func _enter_combat() -> void:
	if peaceful or not alive or awareness == Awareness.COMBAT:
		return
	awareness = Awareness.COMBAT
	_lost_timer = 0.0
	if _alerted_timer <= 0.0:
		play_alert_cue()
	_share_alert()


func _start_returning() -> void:
	awareness = Awareness.RETURNING
	_lost_timer = 0.0


## Called on a packmate when another member of the pack spots the player.
## Deliberately does not re-share: an alert propagates one hop from whoever
## actually saw the player, so a crowd of enemies cannot echo a sighting around
## the level forever.
func notify_alerted(_source: Node2D) -> void:
	if not alive or awareness == Awareness.COMBAT:
		return
	if awareness == Awareness.UNAWARE or awareness == Awareness.RETURNING:
		awareness = Awareness.ALERTED
		_lost_timer = 0.0
		_alerted_timer = ALERT_CUE_TIME
		play_alert_cue()


## Spreads this enemy's alert to nearby packmates. This is a shout, not a
## glance: it goes around corners and through the player, so the only gates are
## the pack it belongs to and how far the cry carries.
func _share_alert() -> void:
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not (other is EnemyBase) or not is_instance_valid(other):
			continue
		var mate := other as EnemyBase
		if not mate.alive:
			continue
		# Packless enemies (no director, or deliberately solitary) alert anyone
		# in earshot; a pack stays its own unit.
		if pack_id != -1 and mate.pack_id != pack_id:
			continue
		if global_position.distance_to(mate.global_position) > alert_share_radius:
			continue
		if absf(mate.global_position.y - global_position.y) > max_detect_height * 1.5:
			continue
		mate.notify_alerted(self)


## True if this enemy can currently see the player: inside detection range and
## height, inside the facing cone, and with an unobstructed line between them.
func _can_see_player() -> bool:
	var player := _get_player()
	if player == null or not is_instance_valid(player):
		return false
	var to := player.global_position - global_position
	var dist := to.length()
	if dist > detection_radius or absf(to.y) > max_detect_height:
		return false
	if fov_degrees < 360.0 and dist > 1.0:
		var facing := awareness_facing()
		if absf(facing) > 0.01:
			var forward := Vector2(signf(facing), 0.0)
			if forward.dot(to / dist) < cos(deg_to_rad(fov_degrees * 0.5)):
				return false
	if not _line_clear(global_position, player.global_position, player):
		return false
	_last_seen = player.global_position
	return true


## Raycasts the level (collision layer 1) between two points, ignoring both the
## enemy and the target, so walls and floor actually block sight.
func _line_clear(from: Vector2, to: Vector2, other: Node2D) -> bool:
	var space := get_world_2d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	if other != null and other is CollisionObject2D:
		exclude.append(other.get_rid())
	var query := PhysicsRayQueryParameters2D.create(from, to, 1, exclude)
	return space.intersect_ray(query).is_empty()


## Shouts or pops a brief "!" above the enemy. Uses a floating label rather than
## tinting the sprite so it cannot fight a subclass that owns its own modulate
## (the Sorrow Knight repaints itself every frame for its telegraph).
func play_alert_cue() -> void:
	var label := Label.new()
	label.text = "!"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-4, -74)
	label.z_index = 100
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", -94.0, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)


## Walk direction (px/s) for an unaware enemy: amble toward a point inside
## `patrol_radius` of `home`, pause, pick a new point, repeat. Turns back at a
## ledge instead of pacing straight off it.
func _idle_velocity(delta: float, speed: float) -> float:
	if patrol_radius <= 0.0:
		return 0.0
	if _patrol_pause > 0.0:
		_patrol_pause -= delta
		return 0.0
	var dx := _patrol_target_x - global_position.x
	if absf(dx) < 6.0:
		_patrol_pause = _ai_rng.randf_range(0.6, 1.8)
		_patrol_target_x = home.x + _ai_rng.randf_range(-patrol_radius, patrol_radius)
		return 0.0
	var dir := signf(dx)
	if not _floor_ahead_exists(dir):
		# Ledge: give up this way and pick a fresh point back the other side.
		_patrol_pause = _ai_rng.randf_range(0.4, 1.0)
		_patrol_target_x = home.x - _ai_rng.randf_range(0.0, patrol_radius)
		return 0.0
	return dir * speed * patrol_speed_scale


## Walk direction (px/s) for an enemy heading home after it lost the player.
func _return_velocity(speed: float) -> float:
	var dx := home.x - global_position.x
	if absf(dx) < 10.0:
		return 0.0
	var dir := signf(dx)
	if not _floor_ahead_exists(dir):
		return 0.0
	return dir * speed


## Probes a step ahead for ground, so an idle or returning enemy stops at a
## ledge rather than pacing into a pit.
func _floor_ahead_exists(dir: float) -> bool:
	if not is_on_floor():
		return true
	var from := global_position + Vector2(dir * 20.0, 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 60.0), 1, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Which way the player is, for enemies that hold still and watch while alerted.
func _aware_player_dir() -> float:
	var player := _get_player()
	if player == null or not is_instance_valid(player):
		return 0.0
	return signf(player.global_position.x - global_position.x)

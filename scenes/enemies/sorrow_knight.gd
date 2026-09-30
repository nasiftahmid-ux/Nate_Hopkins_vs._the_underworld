extends EnemyBase

const GRAVITY := 1600.0

## --- combat tuning ---------------------------------------------------------
const BLOCK_RANGE := 84.0
## Where the swing actually connects. Deliberately smaller than BLOCK_RANGE so
## there is a band where the knight guards but has not committed to a swing.
const ATTACK_RANGE := 56.0
const CLOSE_RANGE := 48.0
const ATTACK_COOLDOWN := 2.0

## --- telegraph timing ------------------------------------------------------
## The windup is the entire point: it is the window the player gets to read the
## tell and decide whether to block, back off, or punish the recovery.
const WINDUP_TIME := 0.28
## How long the swing itself is held on the impact frame. Long enough to read
## as an impact, short enough not to feel like input lag.
const ACTIVE_TIME := 0.07
## Committed and helpless. This is where the reward for reading the tell lives.
const RECOVERY_TIME := 0.45

## --- telegraph colours -----------------------------------------------------
const BASE_PURPLE := Color(0.55, 0.3, 0.65, 1)
const BLOCK_GREEN := Color(0.35, 0.8, 0.55, 1)
## Mid-windup: the knight has committed and is about to swing.
const WARN_AMBER := Color(1.0, 0.62, 0.15, 1)
## The last instant of the windup, and the impact frame itself.
const WARN_HOT := Color(1.0, 0.93, 0.35, 1)
const IMPACT_WHITE := Color(1.0, 1.0, 0.88, 1)
## Punched-out, spent, and waiting to be punished for it.
const RECOVERY_GREY := Color(0.42, 0.4, 0.48, 1)
const ARC_COLOR := Color(1.0, 0.82, 0.28, 1)

## How wide the swing arc is drawn, in degrees either side of facing.
const ARC_HALF_ANGLE := 55.0
const ARC_SEGMENTS := 12

enum State { NORMAL, WINDUP, ACTIVE, RECOVERY }

var speed := 42.0
var damage := 12.0
var attack_cooldown := 0.0
var blocking := false
var block_timer := 0.0

var _state := State.NORMAL
var _state_timer := 0.0
var _facing := 1
## Counts down the white hit flash. While it runs the telegraph is not allowed
## to repaint the body, or the "you hit it" feedback would be invisible.
var _hit_flash_left := 0.0

@onready var arc: Polygon2D = $Telegraph


func _ready() -> void:
	max_hp = 120.0
	exp_reward = 60
	money_reward = 20
	hit_color = Color(1.0, 0.8, 0.4)
	hit_flash_time = 0.12
	death_delay = 0.8
	knockback_x = 100.0
	knockback_y = -80.0
	super._ready()
	_build_arc()
	body.color = BASE_PURPLE
	body.pivot_offset = body.size * 0.5


## The swing is drawn as a real fan of ground, not a tint on the knight. Modern
## action games telegraph the *space* an attack will cover, because knowing the
## range is what lets a player step out of it.
func _build_arc() -> void:
	var points := PackedVector2Array()
	for i in range(ARC_SEGMENTS + 1):
		var t := float(i) / float(ARC_SEGMENTS)
		var angle := deg_to_rad(lerpf(-ARC_HALF_ANGLE, ARC_HALF_ANGLE, t))
		points.append(Vector2(cos(angle), sin(angle)) * ATTACK_RANGE)
	points.append(Vector2.ZERO)
	arc.polygon = points
	arc.color = ARC_COLOR
	arc.visible = false


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	attack_cooldown -= delta
	_hit_flash_left = maxf(_hit_flash_left - delta, 0.0)

	var player := _get_player()
	var dir := 0.0
	var dist := 0.0
	if player and is_instance_valid(player):
		dir = signf(player.global_position.x - global_position.x)
		dist = global_position.distance_to(player.global_position)
		if dir != 0.0:
			_facing = 1 if dir > 0.0 else -1

	_advance_attack(delta, player, dir, dist)

	# Movement and blocking are only available in the neutral state. A committed
	# knight is planted: letting it slide or start blocking mid-telegraph would
	# let the tell vanish after the player had already reacted to it.
	var vx := 0.0
	if player and is_instance_valid(player):
		if blocking:
			block_timer -= delta
			if block_timer <= 0.0:
				blocking = false
		elif _can_act() and dist < BLOCK_RANGE and player.get("is_attacking") == true:
			blocking = true
			block_timer = 0.7
			velocity.x = 0.0
		if absf(player.global_position.x - global_position.x) > CLOSE_RANGE and not blocking and _can_act():
			vx = dir * speed

	velocity.x = move_toward(velocity.x, vx, 300.0 * delta)
	move_and_slide()
	_update_visual()


## Runs the windup -> impact -> recovery state machine. Damage is applied once,
## on the impact frame, and only if the player is *still* inside the arc. Checking
## range at that moment instead of at windup start is what makes backing away
## from a telegraph actually work.
func _advance_attack(delta: float, player: Node2D, dir: float, dist: float) -> void:
	match _state:
		State.WINDUP:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.ACTIVE
				_state_timer = ACTIVE_TIME
				# A small lunge sells the swing. It decays with the normal
				# move_toward above, so the knight cannot chain it into a slide.
				velocity.x = dir * 90.0
				if player and is_instance_valid(player) and dist <= ATTACK_RANGE:
					if player.has_method("take_damage"):
						player.take_damage(damage, true, global_position)
		State.ACTIVE:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.RECOVERY
				_state_timer = RECOVERY_TIME
		State.RECOVERY:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.NORMAL
		_:
			if _can_act() and dist > 0.0 and dist <= ATTACK_RANGE and attack_cooldown <= 0.0:
				_state = State.WINDUP
				_state_timer = WINDUP_TIME
				attack_cooldown = ATTACK_COOLDOWN


func _can_act() -> bool:
	return _state == State.NORMAL and not blocking


## Drives the whole visual read: anticipation while winding up, a squash and a
## white flash on the impact frame, then a grey slump while it is punishable.
func _update_visual() -> void:
	var pulse := 0.0
	match _state:
		State.WINDUP:
			var t := _progress()
			# Anticipation: coil backward and stretch tall before the strike,
			# the same squash-and-stretch rule the player's own attacks use.
			_set_scale(Vector2(1.0 - 0.10 * t, 1.0 + 0.12 * t))
			# The flash speeds up as the strike approaches, so the timing of the
			# hit is legible from the rhythm of the pulse alone.
			pulse = 0.5 + 0.5 * sin(t * PI * (4.0 + 12.0 * t))
			_set_colour(BASE_PURPLE.lerp(WARN_AMBER, t).lerp(WARN_HOT, pulse * 0.6 * t))
			_set_arc(0.12 + 0.34 * t, 0.55 + 0.45 * pulse)
		State.ACTIVE:
			_set_scale(Vector2(1.25, 0.78))
			_set_colour(IMPACT_WHITE)
			_set_arc(0.85, 1.0)
		State.RECOVERY:
			var spent := _progress()
			_set_scale(Vector2(1.0 + 0.12 * spent, 1.0 - 0.12 * spent))
			_set_colour(IMPACT_WHITE.lerp(RECOVERY_GREY, spent))
			_set_arc(0.0, 0.0)
		_:
			_set_scale(Vector2.ONE)
			_set_colour(BLOCK_GREEN if blocking else BASE_PURPLE)
			_set_arc(0.0, 0.0)


func _progress() -> float:
	var total := WINDUP_TIME if _state == State.WINDUP else RECOVERY_TIME
	return clampf(1.0 - _state_timer / total, 0.0, 1.0)


## Scale is written by the telegraph every frame, so facing is reapplied here
## rather than set once, otherwise the squash would flip the knight around.
func _set_scale(s: Vector2) -> void:
	body.scale = Vector2(absf(s.x) * float(_facing), s.y)
	arc.scale.x = float(_facing)


func _set_colour(c: Color) -> void:
	# A hit flash outranks the telegraph: if the knight is struck while winding
	# up, seeing the white hit is more useful than seeing the tell.
	if _hit_flash_left <= 0.0:
		body.color = c


func _set_arc(alpha: float, boost: float) -> void:
	arc.visible = alpha > 0.0
	if arc.visible:
		arc.color = Color(ARC_COLOR, alpha)
		arc.modulate = Color(1.0, 1.0, 1.0, boost)


func take_hit(dmg: float, dir: float) -> void:
	if not alive:
		return
	_hit_flash_left = hit_flash_time
	if blocking:
		hp -= dmg * 0.15
		velocity.x = dir * 20.0
		body.color = Color(0.9, 0.95, 0.5)
		get_tree().create_timer(hit_flash_time).timeout.connect(_block_reset_color)
		if hp <= 0.0:
			die()
		return
	super.take_hit(dmg, dir)


func _block_reset_color() -> void:
	if not blocking:
		return
	body.color = Color(0.35, 0.8, 0.55, 1)


func _base_color() -> Color:
	return BASE_PURPLE

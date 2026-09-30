extends Area2D
## A dropped coin. Coins are deliberately hard to fully collect: they burst out
## of the kill in a spray, bounce off the scenery, and are gone after
## `LIFETIME` seconds. This is the coin sink's pressure valve — a sloppy fight
## costs you money you can never get back, which is what makes the shop's
## "one purchase, choose carefully" rule actually bite.

## How long a coin survives before it evaporates.
const LIFETIME := 5.0
## Seconds at the end of its life that it blinks, so a coin about to vanish
## reads as urgent rather than just quietly disappearing.
const BLINK_TIME := 1.2

const GRAVITY := 1500.0
## Upward kick applied to the whole spray, so coins arc out of the corpse
## instead of dropping at the player's feet.
const POP_SPEED := Vector2(0, -330)
## Random horizontal and vertical spread layered on top of the pop.
const SPREAD_X := 210.0
const SPREAD_Y := 150.0
## Horizontal speed retained after a bounce, and the threshold under which a
## settled coin stops sliding so it can be walked over.
const BOUNCE_DAMP := 0.42
const REST_SPEED := 12.0
## How far above the surface a coin comes to rest. Matches the half-height of
## the coin's collision circle.
const GROUND_OFFSET := 10.0
## Below this height there is no floor to land on any more.
const KILL_Y := 700.0

@export var value := 5
@export var lifetime := LIFETIME

var bob := 0.0
var velocity := Vector2.ZERO
var age := 0.0
var resting := false
var _blink := 0.0
var _quiet := 0


func _ready() -> void:
	# The spray is deliberately one-sided, biased away from the facing of the
	# kill so coins end up scattered across the arena rather than back at the
	# corpse.
	var dir := signf(get_parent().get("facing") as float) if get_parent() and get_parent().get("facing") != null else 0.0
	if dir == 0.0:
		dir = 1.0 if randf() < 0.5 else -1.0
	velocity = Vector2(
		dir * randf_range(SPREAD_X * 0.35, SPREAD_X),
		POP_SPEED.y + randf_range(-SPREAD_Y, SPREAD_Y * 0.35)
	)
	# Spin sells the arc more than the translation alone does.
	rotation = randf_range(-0.6, 0.6)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return

	if not resting:
		velocity.y += GRAVITY * delta
		var ground: RayCast2D = $Ground
		ground.force_raycast_update()
		# Only scenery counts as ground. The ray shares a collision layer with the
		# player, so without this a coin can perch on the player's head and hover
		# there instead of landing. Static bodies are the only things a coin is
		# ever allowed to rest on.
		var landed := ground.is_colliding() and velocity.y > 0.0 \
			and ground.get_collider() is StaticBody2D
		if landed:
			# Land on top of whatever was hit rather than sinking into it.
			global_position.y = ground.get_collision_point().y - GROUND_OFFSET
			velocity.y = -velocity.y * BOUNCE_DAMP
			velocity.x *= BOUNCE_DAMP
			rotation = 0.0
			# Two quiet bounces in a row counts as settled, so a coin never
			# skitters forever on a slope and never freezes mid-bounce.
			if absf(velocity.y) < REST_SPEED:
				velocity.y = 0.0
				_quiet += 1
			else:
				_quiet = 0
			if _quiet >= 2 or absf(velocity.x) < REST_SPEED:
				velocity = Vector2.ZERO
				resting = true
		global_position += velocity * delta
		# A coin thrown into a pit is gone, same as the player.
		if global_position.y > KILL_Y:
			queue_free()
			return
	else:
		# Settled coins bob so they read as pickups, not debris.
		bob += delta * 4.0
		$Vis.position.y = sin(bob) * 3.0

	if age >= lifetime - BLINK_TIME:
		_blink += delta
		modulate.a = 0.35 if int(_blink * 8.0) % 2 == 0 else 1.0


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# A coin grabbed mid-flight is still a coin grabbed.
	GameState.add_money(value)
	queue_free()

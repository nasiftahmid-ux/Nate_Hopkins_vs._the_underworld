extends Camera2D
## Trauma-based directional screen shake.
##
## Callers add *trauma* rather than setting an offset. Trauma decays every frame
## and displacement is `trauma` squared, so hits punch and then fall away
## smoothly instead of ramping linearly. Adding a hit stacks trauma but never
## past `MAX_TRAUMA`, so a flurry of light hits cannot white out the screen the
## way a fixed-amplitude tween does.
##
## Pass a direction to bias the shake along the impact axis: a hit from the side
## mostly displaces the camera horizontally, a slam from above mostly vertically.
## Omit it for an omnidirectional rumble (phase roars, spawns).

const MAX_TRAUMA := 1.0
## Trauma lost per second. A full-trauma hit is audible-feeling for ~0.6s.
const TRAUMA_DECAY := 1.7
## Peak displacement at full trauma, in pixels.
const MAX_OFFSET := Vector2(26.0, 20.0)
const MAX_ROLL := 0.05
## How fast the underlying noise is sampled. Higher = buzzier, lower = heavier.
const NOISE_SPEED := 13.0
## Perpendicular shake is damped to this fraction so a side hit reads sideways.
const PERP_DAMPING := 0.4
## Extra push along the impact direction, as a fraction of MAX_OFFSET.
const DIRECTION_PUSH := 0.5
## Trauma floor for any damage, so a 1-damage tick still registers.
const MIN_DAMAGE_TRAUMA := 0.12
## Trauma ceiling for damage scaled to the player's health pool.
const MAX_DAMAGE_TRAUMA := 0.85
## Fraction of the player's health bar that counts as a full-intensity hit.
const FULL_INTENSITY_RATIO := 0.25
## Offence is deliberately quieter than damage taken: a jab should not register
## as hard as being hit, or the screen never stops moving.
const MIN_OFFENCE_TRAUMA := 0.04
const MAX_OFFENCE_TRAUMA := 0.3
const FULL_OFFENCE_RATIO := 1.0

var trauma := 0.0
var direction := Vector2.ZERO

var _time := 0.0
var _noise := FastNoiseLite.new()
var _direction_sum := Vector2.ZERO
var _direction_weight := 0.0
var _base_rotation := 0.0


func _ready() -> void:
	_base_rotation = rotation
	_noise.seed = 0x5EED
	_noise.frequency = 0.5
	_noise.fractal_octaves = 2


func _process(delta: float) -> void:
	_time += delta
	trauma = maxf(trauma - TRAUMA_DECAY * delta, 0.0)
	if is_zero_approx(trauma):
		trauma = 0.0
		direction = Vector2.ZERO
		_direction_sum = Vector2.ZERO
		_direction_weight = 0.0
		offset = Vector2.ZERO
		rotation = _base_rotation
		return

	# Squared falloff: most of the movement happens right after the hit.
	var shake := trauma * trauma
	offset = _shaped_noise() * MAX_OFFSET * shake
	offset += direction * MAX_OFFSET.x * DIRECTION_PUSH * shake
	rotation = _base_rotation + _noise.get_noise_1d(_time * NOISE_SPEED + 41.7) * MAX_ROLL * shake


## Adds raw trauma. Use for events with no damage number behind them.
func add_trauma(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0.0:
		return
	trauma = minf(trauma + amount, MAX_TRAUMA)
	_accumulate_direction(dir, amount)


## Adds trauma scaled to how hard the player was actually hit, relative to
## their health pool, so a cinder imp tap and a boss execute feel nothing alike.
func add_damage_trauma(damage: float, max_health: float, dir: Vector2 = Vector2.ZERO) -> void:
	if damage <= 0.0:
		return
	var ratio := damage / maxf(max_health, 1.0)
	var intensity := clampf(ratio / FULL_INTENSITY_RATIO, 0.0, 1.0)
	add_trauma(lerpf(MIN_DAMAGE_TRAUMA, MAX_DAMAGE_TRAUMA, intensity), dir)


## Adds trauma for the player's own attacks landing, scaled against the
## strongest attack in the moveset. Kept on a lower curve than damage taken.
func add_offence_trauma(damage: float, max_damage: float, dir: Vector2 = Vector2.ZERO) -> void:
	if damage <= 0.0:
		return
	var intensity := clampf(damage / maxf(max_damage, 1.0), 0.0, FULL_OFFENCE_RATIO)
	add_trauma(lerpf(MIN_OFFENCE_TRAUMA, MAX_OFFENCE_TRAUMA, intensity), dir)


func reset() -> void:
	trauma = 0.0
	direction = Vector2.ZERO
	_direction_sum = Vector2.ZERO
	_direction_weight = 0.0
	offset = Vector2.ZERO
	rotation = _base_rotation


## Directions are averaged weighted by trauma, so a hard hit in one direction
## dominates a light hit coming from the other.
func _accumulate_direction(dir: Vector2, amount: float) -> void:
	if dir.is_zero_approx():
		return
	var unit := dir.normalized()
	_direction_sum += unit * amount
	_direction_weight += amount
	direction = (_direction_sum / _direction_weight).normalized()


## Samples two decorrelated noise channels, then damps the component
## perpendicular to the impact direction.
func _shaped_noise() -> Vector2:
	var sample := Vector2(
		_noise.get_noise_1d(_time * NOISE_SPEED),
		_noise.get_noise_1d(_time * NOISE_SPEED + 19.3)
	)
	if direction.is_zero_approx():
		return sample
	var perpendicular := Vector2(-direction.y, direction.x)
	var along := sample.dot(direction)
	var across := sample.dot(perpendicular)
	return direction * along + perpendicular * (across * PERP_DAMPING)

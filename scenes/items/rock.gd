extends Area2D

const DAMAGE := 25.0
const FALL_SPEED := 900.0
const KILL_Y := 760.0

var _hit := false
var _falling := false
var _delay := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_falling = true


func _physics_process(delta: float) -> void:
	if not _falling:
		_delay -= delta
		if _delay > 0.0:
			return
		_falling = true
	position.y += FALL_SPEED * delta
	rotation += delta * 3.0
	if global_position.y > KILL_Y:
		queue_free()


func start_fall(delay: float) -> void:
	_falling = false
	_delay = delay


func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		_hit = true
		body.take_damage(DAMAGE, false)
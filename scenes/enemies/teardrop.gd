extends Area2D

var vel := Vector2.ZERO
var ttl := 3.0
const DAMAGE := 6.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += vel * delta
	ttl -= delta
	if ttl <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(DAMAGE)
		queue_free()
	elif body is StaticBody2D:
		queue_free()

extends Area2D

var vel := Vector2.ZERO
var ttl := 5.0
var damage := 8.0
var accelerates := false
var max_speed := 240.0

@onready var vis: ColorRect = $Vis


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if accelerates:
		vel = vel.normalized() * minf(vel.length() + 300.0 * delta, max_speed)
	global_position += vel * delta
	var r := 0.6 + 0.4 * fmod(Time.get_ticks_msec() / 200.0, 2.0)
	vis.color = vis.color.darkened(0.12) if r > 1.0 else vis.color.lightened(0.12)
	ttl -= delta
	if ttl <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
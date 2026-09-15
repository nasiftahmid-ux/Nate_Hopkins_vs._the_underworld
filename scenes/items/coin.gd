extends Area2D

var bob := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	bob += delta * 4.0
	$Vis.position.y = sin(bob) * 3.0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameState.add_money(5)
		queue_free()
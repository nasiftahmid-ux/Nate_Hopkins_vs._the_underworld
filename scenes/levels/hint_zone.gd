extends Area2D

@export var hint := ""
var triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if triggered or not body.is_in_group("player"):
		return
	triggered = true
	var level := get_parent()
	if level.has_method("show_hint"):
		level.show_hint(hint)
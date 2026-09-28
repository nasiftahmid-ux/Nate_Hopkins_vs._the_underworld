extends Area2D

@export var next_scene := "res://scenes/bosses/boss_arena.tscn"


func _ready() -> void:
	collision_mask = 1
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		set_deferred("monitoring", false)
		GameState.finish_stage()
		# Route through Aphrodite's shop. The next scene is stashed in GameState
		# rather than navigated to directly, and the shop grants the single
		# purchase this visit allows.
		GameState.shop_next_scene = next_scene
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/shop.tscn")
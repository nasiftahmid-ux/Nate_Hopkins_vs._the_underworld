extends StaticBody2D

const GROUND_TEXTURE := preload("res://assets/level4/ground_strip.png")

func _ready() -> void:
	var col := get_node_or_null("Col") as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		var box := (col.shape as RectangleShape2D).size
		var spr := Sprite2D.new()
		spr.texture = GROUND_TEXTURE
		spr.scale = Vector2(box.x / GROUND_TEXTURE.get_width(), box.y / GROUND_TEXTURE.get_height())
		add_child(spr)
	var vis := get_node_or_null("Vis")
	if vis:
		vis.visible = false
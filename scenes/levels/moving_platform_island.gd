extends "res://scenes/levels/moving_platform.gd"

const ISLAND_TEXTURE := preload("res://assets/level4/floating_island_6.png")

func _ready() -> void:
	super()
	var spr := Sprite2D.new()
	spr.texture = ISLAND_TEXTURE
	var plat_width: float = _platform_half_width * 2.0
	var island_scale: float = plat_width / ISLAND_TEXTURE.get_width()
	spr.scale = Vector2(island_scale, island_scale)
	spr.position.y = -_platform_half_height + ISLAND_TEXTURE.get_height() * island_scale * 0.5
	add_child(spr)
	var vis := get_node_or_null("Vis")
	if vis:
		vis.visible = false
extends Area2D
# The stage exit. It stays locked until every enemy in the stage is dead; an
# enemy killed by Nate and one that fell out of the level both count. While
# locked the door dims and shows how many are left, and bumping it flashes
# "Defeat all enemies!". Only a cleared door pays out the stage and routes
# through Aphrodite's shop.

@export var next_scene := "res://scenes/bosses/boss_arena.tscn"

const UNLOCKED_COLOR := Color(1, 1, 1, 1)
const LOCKED_COLOR := Color(0.45, 0.45, 0.5, 1)

var _done := false
## Cached enemy count so the door only redraws its state when the number changes.
var _last_left := -1

## The door art is a TextureRect in most levels but a ColorRect in level 5, so
## it is typed only as far as both go (CanvasItem) to reach `modulate`.
@onready var _vis: CanvasItem = get_node_or_null("Vis")
@onready var _label: Label = get_node_or_null("Label")


func _ready() -> void:
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_refresh()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	if _enemies_left() != _last_left:
		_refresh()
	# The player may already be standing in the doorway when the last enemy dies,
	# so open without making them step out and back in.
	if _last_left == 0 and _player_inside():
		_go()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _enemies_left() > 0:
		_show_locked_notice()
	else:
		_go()


## Living enemies still in the stage. A killed or fallen enemy flips `alive`
## false the moment it goes down, so it drops out of this count immediately
## rather than lingering through its death animation.
func _enemies_left() -> int:
	var left := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.get("alive") == true:
			left += 1
	return left


func _player_inside() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false


func _refresh() -> void:
	_last_left = _enemies_left()
	if _vis:
		_vis.modulate = LOCKED_COLOR if _last_left > 0 else UNLOCKED_COLOR
	if _label:
		_label.text = "EXIT" if _last_left == 0 else "EXIT (%d LEFT)" % _last_left


func _show_locked_notice() -> void:
	var label := Label.new()
	label.text = "Defeat all enemies!"
	label.z_index = 100
	label.position = Vector2(-72, -84)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", -102.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(label.queue_free)


func _go() -> void:
	if _done:
		return
	_done = true
	set_deferred("monitoring", false)
	GameState.finish_stage()
	# Route through Aphrodite's shop. The next scene is stashed in GameState
	# rather than navigated to directly, and the shop grants the single
	# purchase this visit allows.
	GameState.shop_next_scene = next_scene
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/shop.tscn")

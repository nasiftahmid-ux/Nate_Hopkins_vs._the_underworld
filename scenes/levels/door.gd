extends Area2D
# The stage exit. It stays locked until every enemy in the stage is dead; an
# enemy killed by Nate and one that fell out of the level both count. While
# locked the door dims and shows how many are left, and bumping it flashes
# "Defeat all enemies!". Only a cleared door pays out the stage and routes
# through Aphrodite's shop.

@export var next_scene := "res://scenes/bosses/boss_arena.tscn"
## When false the door opens as soon as the player reaches it, no matter how
## many enemies are still standing. Levels that are about exploration rather than
## clearing turn this off.
@export var requires_clear := true

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
	if not requires_clear:
		return 0
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
	if GameState.negative_mode:
		var target := GameState.return_stage
		var new_clock := float(GameState.CLOCK_CONFIG["start"])
		if GameState.negative_total > 0 and GameState.negative_kills >= GameState.negative_total:
			GameState.player_negative_damage_bonus *= 1.1
			GameState.player_damage_mult *= 1.1
		GameState.negative_mode = false
		GameState.player_max_hp = float(GameState.CLOCK_CONFIG["start"])
		GameState.player_health = new_clock
		GameState.player_damage_mult = 1.0 * GameState.player_negative_damage_bonus
		GameState.return_stage = ""
		GameState.clock_running = false
		GameState.enemy_damage_scale *= 1.25
		GameState.enemy_health_scale *= 1.15
		GameState.negative_kills = 0
		GameState.negative_total = 0
		get_tree().call_deferred("change_scene_to_file", target if target != "" else "res://scenes/levels/level1.tscn")
		return
	GameState.finish_stage()
	GameState.enemy_damage_scale *= 1.25
	GameState.enemy_health_scale *= 1.15
	# Route through Aphrodite's shop, but by way of the blackout curtain so the
	# stage ends on a "LEVEL X COMPLETED" beat. The shop is stashed in GameState
	# rather than navigated to directly, and grants the single purchase allowed.
	GameState.shop_next_scene = next_scene
	var stage := _stage_number()
	var caption := ("LEVEL %d COMPLETED" % stage) if stage > 0 else ""
	var subtitle := "WELCOME TO APHRODITE'S UNDERWORLD SHOP"
	GameState.to_blackout("res://scenes/ui/shop.tscn", caption, subtitle)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/blackout.tscn")


## The stage's number, read from the level scene's file name (level3.tscn -> 3),
## so the caption reads right without every door needing to be configured. The
## door's `owner` is the level root, which still holds the path when a level is
## nested inside another scene (as the tests do).
func _stage_number() -> int:
	var path := owner.scene_file_path if owner else ""
	if path.is_empty():
		path = scene_file_path
	if path.is_empty():
		var current := get_tree().current_scene
		path = current.scene_file_path if current else ""
	var digits := path.get_file().get_basename().trim_prefix("level")
	return int(digits) if digits.is_valid_int() else 0

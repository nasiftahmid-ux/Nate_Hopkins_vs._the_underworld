extends Area2D

var delay := 0.65
var damage := 14.0
var width := 52.0
var erupted := false

@onready var mark: ColorRect = $Mark
@onready var pillar: ColorRect = $Pillar


func _ready() -> void:
	add_to_group("boss_hazard")
	body_entered.connect(_on_body_entered)
	pillar.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_erupt)
	tw.tween_property(pillar, "modulate:a", 1.0, 0.06)
	tw.tween_interval(0.34)
	tw.tween_property(pillar, "modulate:a", 0.0, 0.22)
	tw.tween_callback(queue_free)


func _process(_delta: float) -> void:
	if erupted:
		return
	mark.scale.x = 0.6 + 0.4 * absf(sin(float(Time.get_ticks_msec()) / 90.0))
	mark.modulate.a = 0.45 + 0.35 * absf(sin(float(Time.get_ticks_msec()) / 90.0))


func _erupt() -> void:
	erupted = true
	mark.visible = false
	var player := get_tree().get_first_node_in_group("player")
	if player and _overlaps(player):
		player.take_damage(damage, false)


func _on_body_entered(body: Node2D) -> void:
	if not erupted or not body.is_in_group("player") or not body.has_method("take_damage"):
		return
	if _overlaps(body):
		erupted = false
		body.take_damage(damage, false)


func _overlaps(target: Node2D) -> bool:
	return absf(target.global_position.x - global_position.x) < width * 0.5 \
		and absf(target.global_position.y - global_position.y) < 150.0

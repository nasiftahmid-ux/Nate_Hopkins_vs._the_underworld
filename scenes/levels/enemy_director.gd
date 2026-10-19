extends Node2D
class_name EnemyDirector
# Populates a level at runtime: it gathers the enemies the author placed, sorts
# them into packs by proximity, snaps each one onto real walkable ground and
# hands it a deterministic home to idle around.
#
# It deliberately never duplicates an enemy and never mints new ones: a level
# reload builds a fresh director in the fresh scene, so there is nothing to
# double up. The one thing that *is* random - idle wandering - is driven by a
# single exported seed, so the same build always lays out the same way.

## Seed for all idle/patrol randomness. 0 means "pick one at random"; set a
## non-zero value to make a specific layout reproducible for debugging.
@export var debug_seed := 0
## Enemies within this distance of a pack's centre join that pack. Sized so the
## authored levels, where groups sit a few hundred pixels apart, actually read
## as groups rather than one enemy per pack.
@export var cluster_radius := 340.0
## Vertical band for pack membership, so a ground enemy and a platform enemy
## stacked above it never end up in the same pack.
@export var cluster_y_band := 150.0
## Centre-to-centre spacing a pack is re-laid toward.
@export var member_spacing := 46.0
## How far a pack's members may be spread from its centre.
@export var max_spread := 130.0
## Regrouping is a tidy-up, not a redesign: no enemy is ever dragged further
## than this from where the level author put it.
@export var max_regroup := 60.0
## Enemies are kept at least this far ahead of the player's start position, so
## the opening of a stage is never an ambush on spawn.
@export var player_clear_x := 240.0
## Idle wander radius granted to a pack sitting on the ground.
@export var ground_patrol_radius := 46.0
## Idle wander radius for a pack on a narrow platform, where the floor runs out.
@export var platform_patrol_radius := 24.0
## Y above which resting ground counts as a platform rather than the main floor.
@export var platform_y := 400.0

var _rng := RandomNumberGenerator.new()
## The seed every enemy's idle behaviour is derived from. Random unless the
## author pinned `debug_seed`.
var _layout_seed := 0
var _retries := 0


func _ready() -> void:
	if debug_seed != 0:
		_layout_seed = debug_seed
	else:
		_rng.randomize()
		_layout_seed = _rng.randi()
	# Run immediately: the level builds this node in its own `_ready`, by which
	# point every enemy is in the tree. Doing it now rather than deferred keeps
	# enemies from taking even one physics step on their fallback behaviour,
	# which is what made a pinned seed stop being reproducible.
	organize()


## Gathers and lays out the level's enemies. Safe to call again: it re-derives
## everything from the enemies' current positions.
func organize() -> void:
	var level := get_parent()
	if level == null:
		return
	var members := _collect(level)
	if members.is_empty():
		# Probably pinned into a scene ahead of its enemies, whose `_ready` has
		# not run yet. Give it a frame or two, then give up.
		if _retries < 2:
			_retries += 1
			call_deferred("organize")
		return
	var start_x := _player_start_x(level)
	var packs := _cluster(members)
	for i in packs.size():
		_layout(packs[i], i, start_x)


## Every EnemyBase directly under the level, in the order the author placed them.
func _collect(level: Node) -> Array:
	var members: Array = []
	for child in level.get_children():
		if child is EnemyBase and is_instance_valid(child):
			members.append(child)
	return members


## Groups enemies into packs: walking left to right, each enemy joins the
## nearest pack whose centre it is close enough to, or starts a new one. Keying
## off the pack's centre (rather than its last member) stops a long evenly-spaced
## line of enemies from chaining into a single giant pack.
func _cluster(members: Array) -> Array:
	var sorted := members.duplicate()
	sorted.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var packs: Array = []
	var centres: Array = []
	for enemy in sorted:
		var pos: Vector2 = enemy.global_position
		var best := -1
		var best_dist := cluster_radius
		for i in packs.size():
			var centre: Vector2 = centres[i]
			if absf(pos.y - centre.y) > cluster_y_band:
				continue
			var d: float = absf(pos.x - centre.x)
			if d <= best_dist:
				best = i
				best_dist = d
		if best == -1:
			packs.append([enemy])
			centres.append(pos)
		else:
			var pack: Array = packs[best]
			var centre: Vector2 = centres[best]
			centre = (centre * pack.size() + pos) / float(pack.size() + 1)
			pack.append(enemy)
			centres[best] = centre
	return packs


## Re-lays one pack around its centre and homes each member.
func _layout(pack: Array, pack_index: int, start_x: float) -> void:
	var centre := Vector2.ZERO
	for enemy in pack:
		centre += enemy.global_position
	centre /= float(pack.size())

	# Keep the pack's own order so relative positions survive the tidy-up.
	pack.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var count := pack.size()
	for i in count:
		var enemy: EnemyBase = pack[i]
		var authored := enemy.global_position
		var offset := (float(i) - (count - 1) * 0.5) * member_spacing
		offset = clampf(offset, -max_spread, max_spread)
		var target_x := centre.x + offset
		# Never drag an enemy far from where it was placed, and never leave one
		# parked on top of the player's spawn.
		target_x = clampf(target_x, authored.x - max_regroup, authored.x + max_regroup)
		if not is_inf(start_x):
			target_x = maxf(target_x, start_x + player_clear_x)

		var placed := _snap_to_ground(enemy, target_x)
		enemy.global_position = placed
		enemy.home = placed
		enemy.pack_id = pack_index
		enemy.patrol_radius = platform_patrol_radius if placed.y < platform_y else ground_patrol_radius
		enemy.set_ai_seed(_layout_seed + pack_index * 977 + i * 31)


## Drops the enemy onto whatever it is standing over, using the same collision
## layer the enemies walk on. If the spot has no floor, or the floor there is a
## different surface than the enemy's own (a pit, or a platform above), the
## enemy is left exactly where the author put it.
func _snap_to_ground(enemy: Node2D, target_x: float) -> Vector2:
	var half := _half_height(enemy)
	var from := Vector2(target_x, enemy.global_position.y - 40.0)
	var to := Vector2(target_x, enemy.global_position.y + 900.0)
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, 1, [enemy.get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return enemy.global_position
	var surface_y: float = hit.position.y
	var authored_feet := enemy.global_position.y + half
	if absf(surface_y - authored_feet) > 90.0:
		return enemy.global_position
	return Vector2(target_x, surface_y - half - 1.0)


## Half the enemy's collision height, taken from its body shape, so it can be
## settled with its feet exactly on the floor.
func _half_height(enemy: Node2D) -> float:
	for child in enemy.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or not (shape_node.shape is RectangleShape2D):
			continue
		var rect := shape_node.shape as RectangleShape2D
		return rect.size.y * 0.5 * absf(shape_node.scale.y)
	return 0.0


## Where the player starts this level, used to keep the opening of a stage calm.
func _player_start_x(level: Node) -> float:
	var player := level.get_node_or_null("Player") as Node2D
	if player == null:
		return INF
	return player.global_position.x

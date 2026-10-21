class_name NPC
extends Player

## A computer-driven character. Rolls with the same forces as the player.
## To make one, instance any player_*.tscn and set its root script to this.

enum Mode { IDLE, WANDER, GOAL, FIGHT }

@export_group("AI")
@export var mode := Mode.WANDER
## Where GOAL mode rolls to. A node is followed if it moves.
@export var goal: Node3D
## Used by GOAL mode when no goal node is set.
@export var goal_position := Vector3.ZERO
## WANDER picks random points within this distance of the spawn.
@export var wander_radius := 6.0
## WANDER picks a new point after this long, even if it never arrived.
@export var wander_interval := 4.0
## Close enough to count as arrived.
@export var arrive_distance := 0.75
## Top rolling speed the AI steers towards.
@export var max_speed := 6.0
## FIGHT: with a gun, shoots at opponents inside this distance and hangs back
## at a bit over half of it. Without one, rams them.
@export var fight_range := 30.0
## FIGHT: random miss distance added to each shot.
@export var aim_error := 1.0
## FIGHT: seconds an opponent must stay in clear sight before the first shot.
@export var reaction_time := 0.0

signal finished

## FIGHT: seconds spent sliding sideways to get round whatever blocked the way.
const DETOUR_TIME := 1.0

var gadget_mount: GadgetMount
var has_finished := false
var _wander_target: Vector3
var _wander_timer := 0.0
var _sighted: Player
var _sighted_time := 0.0
var _stuck_time := 0.0
var _detour_time := 0.0
var _detour_side := 1.0


func _ready() -> void:
	super()
	gadget_mount = GadgetMount.new()
	gadget_mount.player = self
	gadget_mount.top_level = true
	add_child(gadget_mount)
	_wander_target = spawn_position


func _physics_process(delta: float) -> void:
	if is_squished:
		return
	match mode:
		Mode.WANDER:
			_wander_timer -= delta
			if _wander_timer <= 0.0 or _flat_distance(_wander_target) < arrive_distance:
				_pick_wander_target()
			roll_towards(_wander_target)
		Mode.GOAL:
			roll_towards(goal.global_position if is_instance_valid(goal) else goal_position)
		Mode.IDLE:
			roll_towards(global_position)
		Mode.FIGHT:
			_fight(delta)


## Called by finish areas. Celebrates and brakes to a stop; the level carries on.
func reach_finish() -> void:
	if has_finished:
		return
	has_finished = true
	mode = Mode.IDLE
	enter_condition(Condition.WIN)
	finished.emit()


## Ignore the player's debug/reset keys.
func _unhandled_input(_event: InputEvent) -> void:
	pass


## Pushes towards a world point, steering out sideways drift so it doesn't orbit.
func roll_towards(target: Vector3) -> void:
	var to_target := target - global_position
	to_target.y = 0.0
	var desired := Vector3.ZERO
	if to_target.length() > arrive_distance:
		desired = to_target.normalized() * max_speed
	var flat_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	apply_central_force((desired - flat_velocity).limit_length(1.0) * speed_force)


## Hangs back and shoots at whoever it can see; rolls in to find a clear shot,
## detouring round cover that's in the way.
func _fight(delta: float) -> void:
	var target := _nearest_opponent()
	if target == null:
		roll_towards(global_position)
		return
	var gun := gadget as Gun
	var distance := _flat_distance(target.global_position)
	var visible_now := can_see(target)
	var in_sight := gun != null and distance < fight_range and visible_now
	if in_sight and distance < fight_range * 0.6:
		roll_towards(global_position)
	elif visible_now:
		roll_towards(target.global_position)
	else:
		roll_towards(_route_to(target.global_position, delta))
	if not in_sight or target != _sighted:
		_sighted = target if in_sight else null
		_sighted_time = 0.0
		return
	_sighted_time += delta
	if _sighted_time >= reaction_time:
		var miss := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * aim_error
		gun.fire_at(target.global_position + miss)


## Heads for `point`. After stalling against something, slides sideways for a
## while to get round it, switching sides if that stalls too.
func _route_to(point: Vector3, delta: float) -> Vector3:
	var stalled := Vector2(linear_velocity.x, linear_velocity.z).length() < max_speed * 0.2
	_stuck_time = _stuck_time + delta if stalled else 0.0
	if _stuck_time > 0.5:
		_stuck_time = 0.0
		_detour_side = -_detour_side if _detour_time > 0.0 else _detour_side
		_detour_time = DETOUR_TIME
	if _detour_time <= 0.0:
		return point
	_detour_time -= delta
	var ahead := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z).normalized()
	return global_position + ahead.cross(Vector3.UP) * _detour_side * 10.0


## True when nothing but open air lies between this NPC and `other`.
func can_see(other: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position, other.global_position)
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or result.collider == other


func _nearest_opponent() -> Player:
	var nearest: Player = null
	for other: Player in get_tree().get_nodes_in_group(&"players"):
		if other == self or other.is_eliminated:
			continue
		if nearest == null or _flat_distance(other.global_position) < _flat_distance(nearest.global_position):
			nearest = other
	return nearest


func _pick_wander_target() -> void:
	var offset := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * wander_radius
	_wander_target = spawn_position + Vector3(offset.x, 0.0, offset.y)
	_wander_timer = wander_interval


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()

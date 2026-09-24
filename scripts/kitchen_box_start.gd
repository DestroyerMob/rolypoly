extends Node3D

## We need a box_start.tscn 

const COMPANIONS := [
	preload("res://packed_scenes/player_onion.tscn"),
	preload("res://packed_scenes/player_tomato.tscn"),
	preload("res://packed_scenes/player_naked_onion.tscn"),
	preload("res://packed_scenes/player_boiled_egg.tscn"),
]
const COMPANION_NAMES := ["Onion", "Tomato", "NakedOnion", "BoiledEgg"]
# Positions are in the box's model space; +Y points out of its opening.
const COMPANION_POSITIONS := [
	Vector3(-0.35, -0.35, -0.6),
	Vector3(-0.65, 0.35, -0.65),
	Vector3(-0.65, -0.35, 0.55),
	Vector3(0.55, -0.35, 0.5),
]

@export var box_start: Node3D  #Renamed to box start for clarity
@export var player_rig: PlayerRig
@export var camera_pivot: Node3D
@export var player_box_position := Vector3(0.05, 0.4, 0.2)
@export_range(0.0, 30.0, 0.5) var launch_speed := 14.0
@export_range(0.5, 3.0, 0.1) var produce_size := 2.2

var _bodies: Array[RigidBody3D] = []


func _ready() -> void:
	#Stage Guards
	if box_start == null:
		push_error("Put the box_start.tscn in the level and assign it in the inspector to the node that runs this script.")
	var player := player_rig.current_player
	_normalize_produce(player)
	player_rig.player_swapped.connect(_normalize_produce)
	player.global_position = box_start.to_global(player_box_position)
	player.spawn_position = player.global_position
	player.continuous_cd = true
	_bodies.append(player)
	camera_pivot.global_position = player.global_position

	for index in COMPANIONS.size():
		var body := COMPANIONS[index].instantiate() as RigidBody3D
		# Keep the artwork and physics, but only the rig's player receives input.
		body.set_script(null)
		body.name = COMPANION_NAMES[index]
		body.continuous_cd = true
		_normalize_produce(body)
		add_child(body)
		body.global_position = box_start.to_global(COMPANION_POSITIONS[index])
		_bodies.append(body)


func _normalize_produce(body: RigidBody3D) -> void:
	var collider := body.get_node("CollisionShape3D") as CollisionShape3D
	var mesh_bounds: Array[AABB] = []
	_collect_mesh_bounds(collider, Transform3D.IDENTITY, mesh_bounds)
	if mesh_bounds.is_empty():
		return
	var bounds := mesh_bounds[0]
	for index in range(1, mesh_bounds.size()):
		bounds = bounds.merge(mesh_bounds[index])
	var factor := produce_size / bounds.size[bounds.size.max_axis_index()]
	var size := bounds.size * factor
	# Normalize visible artwork rather than the differently sized source colliders.
	for child in collider.get_children():
		if child is Node3D:
			child.position = (child.position - bounds.get_center()) * factor
			child.scale *= factor
	collider.position = Vector3.ZERO
	var clearance: float
	if collider.shape is CapsuleShape3D:
		var shape := CapsuleShape3D.new()
		shape.radius = maxf(size.x, size.z) * 0.5
		shape.height = maxf(size.y, shape.radius * 2.0)
		collider.shape = shape
		clearance = shape.height * 0.5
	else:
		var shape := SphereShape3D.new()
		shape.radius = produce_size * 0.5
		collider.shape = shape
		clearance = shape.radius
	if body is Player:
		body.spawn_clearance = clearance
		body.original_visual_scale = body.visual.scale
		body.continuous_cd = true


func _collect_mesh_bounds(node: Node3D, relative: Transform3D, bounds: Array[AABB]) -> void:
	if not node.visible:
		return
	if node is MeshInstance3D and node.mesh != null:
		bounds.append(relative * node.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			_collect_mesh_bounds(child, relative * child.transform, bounds)


func _physics_process(_delta: float) -> void:
	# A single impulse starts the spill; ordinary rigid-body physics takes over.
	var outward := box_start.global_basis.y.normalized()
	var sideways := box_start.global_basis.z.normalized()
	for index in _bodies.size():
		var body := _bodies[index]
		var spread := float(index - 2) * 0.06
		var direction := (outward + sideways * spread).normalized()
		var speed := launch_speed * (1.0 - float(index) * 0.04)
		body.sleeping = false
		body.apply_central_impulse(direction * speed * body.mass)
		body.apply_torque_impulse(Vector3.UP.cross(direction) * body.mass * speed * 0.25)
	set_physics_process(false)

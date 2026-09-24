extends Node3D

@export_range(1.0, 2.0, 0.05) var size_multiplier := 1.1

var _player: Player
var _shape: Shape3D
var _material: PhysicsMaterial
var _lock_rotation: bool
var _linear_damp: float
var _damp_mode: RigidBody3D.DampMode
var _spawn_clearance: float
var _side := 1.0
var _lift := 0.0


func update_attachment(player: Player, _mount: GadgetMount) -> void:
	if player != _player:
		_restore_player()
		_player = player
		_shape = player.collider.shape
		_material = player.physics_material_override
		_lock_rotation = player.lock_rotation
		_linear_damp = player.linear_damp
		_damp_mode = player.linear_damp_mode
		_spawn_clearance = player.spawn_clearance
		var bounds := _shape.get_debug_mesh().get_aabb()
		_side = bounds.size[bounds.size.max_axis_index()] * size_multiplier
		var box := BoxShape3D.new()
		box.size = Vector3.ONE * _side
		player.collider.shape = box
		var ice := PhysicsMaterial.new()
		ice.friction = 0.02
		player.physics_material_override = ice
		player.lock_rotation = true
		player.angular_velocity = Vector3.ZERO
		player.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		player.linear_damp = 0.05
		player.spawn_clearance = _side * 0.5 - player.collider.position.y
		_lift = maxf(0.0, (_side - bounds.size.y) * 0.5)
		player.sleeping = false
	global_transform = Transform3D(Basis.IDENTITY, player.collider.global_position)
	$Model.scale = Vector3.ONE * (_side / 64.0)
	$Model.position = Vector3(0, -_side * 0.5, 0)
	visible = player.visible and not player.is_squished


func integrate_equipment_forces(_body: Player, state: PhysicsDirectBodyState3D) -> void:
	# A real box collider stays upright, including after a launch or character swap.
	var upright := state.transform
	upright.basis = Basis.IDENTITY
	upright.origin.y += _lift
	_lift = 0.0
	state.transform = upright
	state.angular_velocity = Vector3.ZERO


func _exit_tree() -> void:
	_restore_player()


func _restore_player() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_player.collider):
		return
	_player.collider.shape = _shape
	_player.physics_material_override = _material
	_player.lock_rotation = _lock_rotation
	_player.linear_damp = _linear_damp
	_player.linear_damp_mode = _damp_mode
	_player.spawn_clearance = _spawn_clearance
	_player = null

extends Node3D

@export_range(1.0, 2.0, 0.05) var size_multiplier := 1.1
## Lifetime away from hot surfaces; contact heat can melt the cube faster.
@export_range(1.0, 300.0, 1.0) var ambient_melt_seconds := 60.0

var _player: Player
var _shape: Shape3D
var _material: PhysicsMaterial
var _lock_rotation: bool
var _linear_damp: float
var _damp_mode: RigidBody3D.DampMode
var _spawn_clearance: float
var _side := 1.0
var _lift := 0.0
var _mount: GadgetMount
var _ice_shape: BoxShape3D
var _melt_progress := 0.0
var _melted := false


func update_attachment(player: Player, mount: GadgetMount) -> void:
	if _melted:
		return
	_mount = mount
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
		_ice_shape = BoxShape3D.new()
		_ice_shape.size = Vector3.ONE * _side
		player.collider.shape = _ice_shape
		var ice := PhysicsMaterial.new()
		ice.friction = 0.02
		player.physics_material_override = ice
		player.lock_rotation = true
		player.angular_velocity = Vector3.ZERO
		player.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		player.linear_damp = 0.05
		_update_ice_geometry()
		_lift = maxf(0.0, (_ice_shape.size.y - bounds.size.y) * 0.5)
		player.sleeping = false
	global_transform = Transform3D(Basis.IDENTITY, player.collider.global_position)
	visible = player.visible and not player.is_squished


func _physics_process(delta: float) -> void:
	if _melted or not is_instance_valid(_player):
		return
	var melt_rate := 1.0 / maxf(ambient_melt_seconds, 1.0)
	# Only actual body contact accelerates the normal, continuous melting.
	# Ancestors let imported mesh colliders share their packed scene's heat setting.
	for body in _player.get_colliding_bodies():
		var surface: Node = body
		while surface != null:
			if surface.has_method("get_ice_melt_rate"):
				melt_rate = maxf(melt_rate, float(surface.get_ice_melt_rate()))
				break
			surface = surface.get_parent()
	_melt_progress = minf(1.0, _melt_progress + melt_rate * delta)
	_update_ice_geometry()
	if _melt_progress >= 1.0:
		_melted = true
		visible = false
		_finish_melting.call_deferred()


func refresh_equipment() -> void:
	if not is_instance_valid(_player):
		return
	var old_side := _ice_shape.size.y
	_melt_progress = 0.0
	_melted = false
	_update_ice_geometry()
	# Growing the box again must lift it clear of the floor on the next physics step.
	_lift += maxf(0.0, (_ice_shape.size.y - old_side) * 0.5)
	_player.sleeping = false
	visible = _player.visible and not _player.is_squished


func _finish_melting() -> void:
	# A pickup can refresh the cube before this deferred removal runs.
	if _melted and is_instance_valid(_mount):
		_mount.unequip(self)


func _update_ice_geometry() -> void:
	var visual_side := _side * (1.0 - _melt_progress)
	# The ice shrinks all the way down, while collision still protects the character.
	var collision_side := maxf(visual_side, _side / size_multiplier)
	var collision_size := Vector3.ONE * collision_side
	if not _ice_shape.size.is_equal_approx(collision_size):
		_ice_shape.size = collision_size
	_player.spawn_clearance = collision_side * 0.5 - _player.collider.position.y
	$Model.scale = Vector3.ONE * (maxf(visual_side, 0.001) / 64.0)
	# Keep the melting cube's base at the contact surface as its top recedes.
	$Model.position = Vector3(0, -collision_side * 0.5, 0)
	$Model.material_override.set_shader_parameter("melt_progress", _melt_progress)


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

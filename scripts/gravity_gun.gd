extends Node3D

@export var pull_speed := 12.0
@export var grab_range := 60.0
@export var launch_impulse := 30.0

@onready var ray: RayCast3D = $GrabRay
@onready var anchor: Marker3D = $HoldAnchor

var _held: RigidBody3D
var _was_frozen := false
var _fire_requested := false
var _player: Player


func activate(player: Player) -> void:
	_player = player
	_fire_requested = true


func _physics_process(delta: float) -> void:
	if _fire_requested:
		_fire_requested = false
		if is_instance_valid(_held):
			_release(is_instance_valid(_player) and not _player.on_ground)
		else:
			var camera := get_viewport().get_camera_3d()
			if camera == null:
				return
			var center := get_viewport().get_visible_rect().size * 0.5
			ray.global_transform = Transform3D(Basis.IDENTITY, camera.project_ray_origin(center))
			ray.target_position = camera.project_ray_normal(center) * grab_range
			ray.clear_exceptions()
			if is_instance_valid(_player):
				ray.add_exception(_player)
			ray.force_raycast_update()
			var body := ray.get_collider() as RigidBody3D
			if body != null and body.is_in_group(&"vegetable") and not body is Player:
				_held = body
				_was_frozen = body.freeze
				body.freeze = true
				body.linear_velocity = Vector3.ZERO
				body.angular_velocity = Vector3.ZERO
	if is_instance_valid(_held):
		_held.global_position = _held.global_position.lerp(
			anchor.global_position, 1.0 - exp(-pull_speed * delta))


func _release(launch := false) -> void:
	if is_instance_valid(_held):
		_held.freeze = _was_frozen
		_held.sleeping = false
		if launch and not _held.freeze:
			var camera := get_viewport().get_camera_3d()
			if camera != null:
				var center := get_viewport().get_visible_rect().size * 0.5
				var direction := camera.project_ray_normal(center)
				_held.apply_central_impulse(direction * launch_impulse)
	_held = null


func _exit_tree() -> void:
	_release()

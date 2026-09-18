class_name SwingingLadleObstacle
extends Node3D

signal reached_left_peak
signal reached_right_peak

@export_category("Swinging Movement")
@export var active := true
@export_range(0.0, 70.0, 0.5) var swing_angle_degrees := 34.0
@export_range(0.8, 10.0, 0.1) var swing_period := 3.4
@export_range(-180.0, 180.0, 1.0) var phase_degrees := 0.0

@onready var swinging_part: AnimatableBody3D = $SwingingPart
@onready var model: Node3D = $SwingingPart/Model

var _elapsed := 0.0
var _neutral_transform := Transform3D.IDENTITY
var _last_swing_direction := 0


func _ready() -> void:
	_neutral_transform = swinging_part.transform
	_elapsed = deg_to_rad(phase_degrees) * swing_period / TAU
	_create_bowl_collision()
	_apply_swing_transform()
	swinging_part.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not active or swing_period <= 0.0:
		return

	_elapsed += delta
	_apply_swing_transform()


func _apply_swing_transform() -> void:
	var phase := TAU * _elapsed / maxf(swing_period, 0.001)
	var angle := deg_to_rad(swing_angle_degrees) * sin(phase)
	var angular_direction := signi(int(cos(phase) * 1000.0))

	var next_transform := _neutral_transform
	# Rotate around the vertical axis: the flat spoon sweeps across the floor.
	next_transform.basis = _neutral_transform.basis * Basis(Vector3.UP, angle)
	swinging_part.transform = next_transform

	if angular_direction != 0 and angular_direction != _last_swing_direction:
		if angular_direction > 0:
			reached_left_peak.emit()
		else:
			reached_right_peak.emit()
		_last_swing_direction = angular_direction


func reset_immediately() -> void:
	_elapsed = deg_to_rad(phase_degrees) * swing_period / TAU
	_last_swing_direction = 0
	_apply_swing_transform()
	swinging_part.reset_physics_interpolation()


func _create_bowl_collision() -> void:
	var bowl_mesh := model.find_child("Ladle_Bowl", true, false) as MeshInstance3D
	if bowl_mesh == null or bowl_mesh.mesh == null:
		push_warning("Ladle_Bowl mesh was not found; physical bowl collision was not created.")
		return

	var collision := CollisionShape3D.new()
	collision.name = "GeneratedBowlCollision"
	var bowl_shape := bowl_mesh.mesh.create_trimesh_shape()
	if bowl_shape is ConcavePolygonShape3D:
		bowl_shape.backface_collision = true
	collision.shape = bowl_shape
	swinging_part.add_child(collision)
	collision.global_transform = bowl_mesh.global_transform

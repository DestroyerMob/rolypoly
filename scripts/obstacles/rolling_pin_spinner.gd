class_name RollingPinSpinnerObstacle
extends Node3D

signal completed_revolution

enum SpinDirection {
	FORWARD = 1,
	REVERSED = -1,
}

@export_category("Continuous Rotation")
@export var active := true
@export_range(0.0, 720.0, 1.0) var rotation_speed_degrees := 55.0
@export var spin_direction: SpinDirection = SpinDirection.FORWARD

@onready var moving_part: AnimatableBody3D = $MovingPart

var _neutral_transform := Transform3D.IDENTITY
var _angle := 0.0


func _ready() -> void:
	_neutral_transform = moving_part.transform
	reset_immediately()


func _physics_process(delta: float) -> void:
	if not active or rotation_speed_degrees <= 0.0:
		return
	var previous_angle := _angle
	_angle = fposmod(
		_angle + deg_to_rad(rotation_speed_degrees) * float(spin_direction) * delta,
		TAU
	)
	if float(spin_direction) > 0.0 and _angle < previous_angle:
		completed_revolution.emit()
	elif float(spin_direction) < 0.0 and _angle > previous_angle:
		completed_revolution.emit()

	var next_transform := _neutral_transform
	# The demo mounts the long axis along world Z, so rotate around local Z.
	next_transform.basis = _neutral_transform.basis * Basis(Vector3.BACK, _angle)
	moving_part.transform = next_transform


func surface_speed(roller_radius := 1.0) -> float:
	return deg_to_rad(rotation_speed_degrees) * roller_radius


func reset_immediately() -> void:
	_angle = 0.0
	moving_part.transform = _neutral_transform
	moving_part.reset_physics_interpolation()

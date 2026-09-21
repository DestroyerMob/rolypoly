class_name RollingPinObstacle
extends Node3D

signal reached_end(direction: int)

@export_category("Rolling Movement")
@export var active := true
@export_range(0.0, 20.0, 0.1) var travel_distance := 4.0
@export_range(0.1, 12.0, 0.1) var travel_speed := 2.4
@export_range(0.0, 3.0, 0.05) var pause_at_ends := 0.3
@export_range(0.1, 3.0, 0.01) var roller_radius := 0.56
@export_enum("Forward:1", "Backward:-1") var starting_direction := 1

@onready var moving_part: AnimatableBody3D = $MovingPart

var _direction := 1
var _pause_remaining := 0.0


func _ready() -> void:
	_direction = 1 if starting_direction >= 0 else -1
	moving_part.transform = Transform3D(
		Basis.IDENTITY,
		Vector3(0.0, 0.58, -travel_distance * 0.5)
	)
	moving_part.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not active or travel_distance <= 0.0:
		return

	if _pause_remaining > 0.0:
		_pause_remaining = maxf(_pause_remaining - delta, 0.0)
		return

	var target_z := travel_distance * 0.5 * _direction
	var previous_z := moving_part.position.z
	var next_z := move_toward(previous_z, target_z, travel_speed * delta)
	var travelled := next_z - previous_z

	var next_transform := moving_part.transform
	next_transform.origin.z = next_z
	next_transform.basis = next_transform.basis.rotated(
		Vector3.RIGHT,
		-travelled / maxf(roller_radius, 0.01)
	)
	moving_part.transform = next_transform

	if is_equal_approx(next_z, target_z):
		reached_end.emit(_direction)
		_direction *= -1
		_pause_remaining = pause_at_ends


func reset_immediately() -> void:
	_direction = 1 if starting_direction >= 0 else -1
	_pause_remaining = 0.0
	moving_part.transform = Transform3D(
		Basis.IDENTITY,
		Vector3(0.0, 0.58, -travel_distance * 0.5)
	)
	moving_part.reset_physics_interpolation()

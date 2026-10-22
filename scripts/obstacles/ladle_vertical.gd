class_name VerticalLadleObstacle
extends Node3D

signal reached_peak(direction: int)

@export_category("Vertical Swing")
@export var active := true
@export_range(0.0, 75.0, 0.5) var swing_angle_degrees := 38.0
@export_range(0.8, 10.0, 0.1) var swing_period := 3.2
@export_range(-180.0, 180.0, 1.0) var phase_degrees := 0.0

@onready var swinging_part: AnimatableBody3D = $SwingingPart
@onready var model: Node3D = $SwingingPart/Model

var _neutral_transform := Transform3D.IDENTITY
var _elapsed := 0.0
var _last_direction := 0


func _ready() -> void:
	_neutral_transform = swinging_part.transform
	_create_bowl_collision()
	reset_immediately()


func _physics_process(delta: float) -> void:
	if not active or swing_period <= 0.0:
		return
	_elapsed = fmod(_elapsed + delta, swing_period)
	_apply_swing()


func reset_immediately() -> void:
	_elapsed = fposmod(deg_to_rad(phase_degrees) * swing_period / TAU, swing_period)
	_last_direction = 0
	_apply_swing()
	swinging_part.reset_physics_interpolation()


func _apply_swing() -> void:
	var phase := TAU * _elapsed / maxf(swing_period, 0.001)
	var angle := deg_to_rad(swing_angle_degrees) * sin(phase)
	var next_transform := _neutral_transform
	# The handle hangs down local Y. Rotate about X so the pendulum swings
	# front-to-back, perpendicular to the previous left-to-right direction.
	next_transform.basis = _neutral_transform.basis * Basis(Vector3.RIGHT, angle)
	swinging_part.transform = next_transform

	var direction := 1 if cos(phase) >= 0.0 else -1
	if _last_direction != 0 and direction != _last_direction:
		reached_peak.emit(direction)
	_last_direction = direction


func _create_bowl_collision() -> void:
	var bowl := model.find_child("LadleVertical_Bowl", true, false) as MeshInstance3D
	if bowl == null or bowl.mesh == null:
		push_warning("Vertical ladle bowl mesh was not found.")
		return
	var collision := CollisionShape3D.new()
	collision.name = "GeneratedBowlCollision"
	collision.shape = bowl.mesh.create_convex_shape()
	swinging_part.add_child(collision)
	collision.global_transform = bowl.global_transform

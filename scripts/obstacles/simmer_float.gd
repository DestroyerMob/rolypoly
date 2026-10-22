extends Node3D

@export var bob_height := 0.025
@export var bob_speed := 1.6
@export var tilt := 0.1
@export var drift_radius := 0.04
@export var spin_speed := 0.25

var _base_position: Vector3
var _time := 0.0

func _ready() -> void:
	_base_position = position
	_time = randf() * TAU
	rotation.y = randf() * TAU

func _process(delta: float) -> void:
	_time += delta
	position = _base_position + Vector3(
		cos(_time * 0.5) * drift_radius,
		sin(_time * bob_speed) * bob_height,
		sin(_time * 0.4) * drift_radius
	)
	rotation = Vector3(
		sin(_time * 1.1) * tilt,
		rotation.y + delta * spin_speed,
		cos(_time * 0.9) * tilt
	)

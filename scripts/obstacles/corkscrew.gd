extends Node3D

## Rotation around the corkscrew's vertical axis, per activation.
@export var rotation_amount_degrees := 360.0
## Vertical travel per activation: positive goes up, negative goes down.
@export var height_change := -1.0
## Time in seconds for both movements to finish together.
@export_range(0.01, 60.0, 0.01, "or_greater") var duration := 1.5

@onready var moving_part: AnimatableBody3D = $Body
@onready var occupancy: Area3D = $Body/Occupancy
var _motion: Tween
var _rest_transform: Transform3D
var _progress := 0.0
var _angle := 0.0
var _travel := 0.0
var _activated := false


func _ready() -> void:
	_rest_transform = moving_part.transform
	$Body/Trigger.body_entered.connect(_on_body_entered)
	occupancy.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		trigger()


func trigger() -> void:
	if _activated:
		return
	_activated = true
	if is_zero_approx(_progress):
		_angle = deg_to_rad(rotation_amount_degrees)
		_travel = height_change
	_animate_to(1.0)


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		_return_if_empty.call_deferred()


func _return_if_empty() -> void:
	if not _activated:
		return
	for body in occupancy.get_overlapping_bodies():
		if body is Player:
			return
	_activated = false
	_animate_to(0.0)


func _animate_to(target: float) -> void:
	if _motion:
		_motion.kill()
	_motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion.tween_method(_apply_motion, _progress, target, maxf(duration, 0.01))


func _apply_motion(progress: float) -> void:
	_progress = progress
	var next := _rest_transform
	next.origin.y += _travel * progress
	next.basis = _rest_transform.basis.rotated(Vector3.UP, _angle * progress)
	moving_part.transform = next

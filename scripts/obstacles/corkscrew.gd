extends Node3D

## Rotation around the corkscrew's vertical axis, per activation.
@export var rotation_amount_degrees := 360.0
## Vertical travel per activation: positive goes up, negative goes down.
@export var height_change := -1.0
## Time in seconds for both movements to finish together.
@export_range(0.01, 60.0, 0.01, "or_greater") var duration := 1.5

@onready var moving_part: AnimatableBody3D = $Body
var _motion: Tween


func _ready() -> void:
	$Body/Trigger.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		trigger()


func trigger() -> void:
	if _motion and _motion.is_running():
		return
	_motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion.tween_method(
		_apply_motion.bind(moving_part.transform, deg_to_rad(rotation_amount_degrees), height_change),
		0.0, 1.0, maxf(duration, 0.01)
	)


func _apply_motion(progress: float, start: Transform3D, angle: float, travel: float) -> void:
	var next := start
	next.origin.y += travel * progress
	next.basis = start.basis.rotated(Vector3.UP, angle * progress)
	moving_part.transform = next

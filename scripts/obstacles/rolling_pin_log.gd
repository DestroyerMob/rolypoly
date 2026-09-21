class_name SpinningLogObstacle
extends Node3D

## A log that spins in place. The Ninja Warrior rolling log.
## It does not travel. For a pin that rolls along a path, use RollingPinObstacle.
##
## The marble is pushed sideways by the surface moving underneath it, so the
## challenge is holding a line while the ground slides. Friction on the log's
## physics material is what makes that feel fair, not the spin speed.
##
## PRESETS. Starting points, tune by eye from here.
## [codeblock]
##   Setting             GENTLE      NASTY       TAUNTING
##   ------------------  ----------  ----------  ------------------------
##   Spin Speed          60          180         120
##   Reverse Interval    0           0           2.0
##   Reverse Ramp        0.3         0.3         0.5
##   Proto material      MI_SURF     MI_RDIR     MI_RDIR
##   Function code       SURF        RDIR        RDIR
## [/codeblock]
##
## The AnimatableBody3D must have sync_to_physics ON, or the log spins
## visually and pushes nothing.

signal reversed(new_direction: int)

enum SpinAxis {
	LENGTH_X,  ## Spins about local X. Use when the log lies along X.
	LENGTH_Z,  ## Spins about local Z. Use when the log lies along Z.
	VERTICAL,  ## Spins about local Y. A turntable rather than a log.
	CUSTOM,    ## Uses custom_axis.
}

enum SpinDirection {
	FORWARD = 1,
	REVERSED = -1,
}

@export_category("Spin")
@export var active := true

## Which way the log lies. Pick the axis it is long along.
@export var spin_axis: SpinAxis = SpinAxis.LENGTH_X

## Only used when Spin Axis is CUSTOM.
@export var custom_axis := Vector3.RIGHT

## Mirrors the spin. Use this, not a negative speed, so two logs side by side
## can counter-rotate with the same tuning numbers.
@export var spin_direction: SpinDirection = SpinDirection.FORWARD

## Degrees per second. 60 is a gentle nudge, 180 will throw the marble off.
@export_range(0.0, 720.0, 1.0) var spin_speed_degrees := 90.0

@export_category("Reversal")
## Seconds between direction flips. 0 means it never reverses.
## A log that reverses is far more interesting than one that does not,
## because the player has to read it rather than just commit.
@export_range(0.0, 20.0, 0.1) var reverse_interval := 0.0

## Seconds to ease through the flip. 0 snaps, which feels wrong and can
## fling the marble. Keep it above 0.2.
@export_range(0.0, 2.0, 0.05) var reverse_ramp := 0.3

@onready var spinning_part: AnimatableBody3D = $MovingPart

var _neutral_transform := Transform3D.IDENTITY
var _axis := Vector3.RIGHT
var _angle := 0.0
var _direction := 1.0
var _target_direction := 1.0
var _reverse_timer := 0.0


func _ready() -> void:
	_neutral_transform = spinning_part.transform
	_axis = _resolve_axis()
	reset_immediately()


func _physics_process(delta: float) -> void:
	if not active or spin_speed_degrees <= 0.0:
		return

	_tick_reversal(delta)

	# Accumulate the angle and rebuild the basis from neutral each frame.
	# Repeatedly calling basis.rotated() accumulates float error and eventually
	# skews the body, which shows up as a log that slowly goes out of round.
	_angle = fposmod(_angle + deg_to_rad(spin_speed_degrees) * _direction * delta, TAU)

	var next_transform := _neutral_transform
	next_transform.basis = _neutral_transform.basis * Basis(_axis, _angle)
	spinning_part.transform = next_transform


## Returns the surface speed in metres per second for a log of this radius.
## Useful for tuning against the marble's own speed.
func surface_speed(radius: float) -> float:
	return deg_to_rad(spin_speed_degrees) * radius


func reset_immediately() -> void:
	_angle = 0.0
	_direction = float(spin_direction)
	_target_direction = _direction
	_reverse_timer = reverse_interval
	spinning_part.transform = _neutral_transform
	spinning_part.reset_physics_interpolation()


# --- internals ---------------------------------------------------------------

func _resolve_axis() -> Vector3:
	match spin_axis:
		SpinAxis.LENGTH_X:
			return Vector3.RIGHT
		SpinAxis.LENGTH_Z:
			return Vector3.BACK
		SpinAxis.VERTICAL:
			return Vector3.UP
		_:
			return custom_axis.normalized() if custom_axis.length() > 0.001 else Vector3.RIGHT


func _tick_reversal(delta: float) -> void:
	if reverse_interval <= 0.0:
		_direction = float(spin_direction)
		return

	_reverse_timer -= delta
	if _reverse_timer <= 0.0:
		_reverse_timer = reverse_interval
		_target_direction = -_target_direction
		reversed.emit(signi(int(_target_direction)))

	if reverse_ramp <= 0.0:
		_direction = _target_direction
	else:
		_direction = move_toward(_direction, _target_direction, delta * 2.0 / reverse_ramp)

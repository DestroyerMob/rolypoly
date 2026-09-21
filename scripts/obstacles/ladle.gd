class_name SwingingLadleObstacle
extends Node3D

## A ladle that swings about a chosen axis.
##
## All three behaviours are the same equation, angle = A * sin(2*PI*t/T).
## Only the axis of rotation differs. Mode picks the axis, Mount Rotation picks
## how the bowl faces, Bowl Collision picks whether it can carry the marble.
##
## PRESETS. Starting points, tune by eye from here.
## [codeblock]
##   Setting          SWEEP            GATE             SCOOP
##   ---------------  ---------------  ---------------  ----------------------
##   Mode             SWEEP            GATE             SCOOP
##   Mount Rotation   (0, 0, 0)        (0, 0, 180)      (0, 0, 180) + yaw
##   Swing Angle      30 to 45         50 to 70         60 to 90
##   Period           3.0 to 4.0       2.0 to 3.0       4.0 to 6.0
##   Swing Offset     0                0 to 30          0
##   Bowl Collision   CONVEX           CONVEX           CONCAVE
##   Proto material   MI_RDIR          MI_HAZA          MI_MOVE
##   Function code    RDIR             HAZA or GATE     MOVE
##   Swing Direction  FORWARD          FORWARD          FORWARD or REVERSED
## [/codeblock]
##
## SCOOP requires CONCAVE collision to hold the marble, which is the most
## expensive shape here. One or two per level, not twenty.
## The AnimatableBody3D must have sync_to_physics ON or nothing gets pushed.

signal reached_left_peak
signal reached_right_peak

enum SwingMode {
	SWEEP,   ## Local Y. Flat spoon sweeps the floor and knocks the marble sideways. RDIR.
	GATE,    ## Local X. Pendulum across a corridor. Blocks passage on a rhythm. HAZA.
	SCOOP,   ## Local Z. Pendulum that lifts. The bowl carries the marble upward. MOVE.
	CUSTOM,  ## Uses custom_axis.
}

enum BowlCollision {
	NONE,     ## Visual only. No collision on the bowl.
	CONVEX,   ## Cheap solid blocker. Cannot hold the marble. Use for SWEEP and GATE.
	CONCAVE,  ## Hollow bowl. Can scoop and carry. Expensive. Use only for SCOOP.
}

enum SwingDirection {
	FORWARD = 1,   ## Rotates the standard way about the mode's axis.
	REVERSED = -1, ## Mirrors the entire arc, including Swing Offset.
}


@export_category("Swing")
@export var active := true

## Picks the rotation axis, and with it the gameplay role.
## SWEEP knocks sideways, GATE blocks a corridor, SCOOP lifts and carries.
@export var mode: SwingMode = SwingMode.SWEEP
## Only used when Mode is CUSTOM.
@export var custom_axis := Vector3.UP
## Half the arc, in degrees, measured from the rest pose.
## SWEEP 30 to 45, GATE 50 to 70, SCOOP 60 to 90.
@export_range(0.0, 360, 0.5) var swing_angle_degrees := 34.0
## Seconds for one full back and forth.
## SWEEP 3.0 to 4.0, GATE 2.0 to 3.0, SCOOP 4.0 to 6.0 so the player can ride it.
@export_range(0.2, 10.0, 0.1) var swing_period := 3.4
## Where in the cycle this ladle starts. Offset several ladles to stagger them.
@export_range(-180.0, 180.0, 1.0) var phase_degrees := 0.0
## Shifts the centre of the arc. 0 swings symmetrically about the rest pose.
## Useful for a GATE that should swing from vertical rather than through it.
@export_range(-90.0, 90.0, 1.0) var swing_offset_degrees := 0.0
## Mirrors the arc. Use this, not Phase, when you want two ladles side by side
## rotating opposite ways. Phase staggers them in time, Direction mirrors them
## in space, and the two are independent.
@export var swing_direction: SwingDirection = SwingDirection.FORWARD

@export_category("Mounting")
## Rotates the model inside the swinging part so the bowl faces correctly.
## SWEEP (0, 0, 0). GATE (0, 0, 180) so the handle hangs from the top.
## SCOOP (0, 0, 180) plus a yaw so the bowl opens along the arc.
@export var mount_rotation_degrees := Vector3.ZERO

@export_category("Collision")
## CONVEX for SWEEP and GATE. CONCAVE only for SCOOP, it is the expensive one.
@export var bowl_collision: BowlCollision = BowlCollision.CONVEX

## Optional. Leave empty to fall back to finding a child named "Ladle_Bowl".
@export var bowl_mesh_path: NodePath

@onready var swinging_part: AnimatableBody3D = $SwingingPart
@onready var model: Node3D = $SwingingPart/Model

var _elapsed := 0.0
var _neutral_transform := Transform3D.IDENTITY
var _axis := Vector3.UP
var _last_swing_direction := 0


func _ready() -> void:
	_neutral_transform = swinging_part.transform
	model.rotation_degrees = mount_rotation_degrees
	_axis = _resolve_axis() * float(swing_direction)
	_build_bowl_collision()
	reset_immediately()


func _physics_process(delta: float) -> void:
	if not active or swing_period <= 0.0:
		return
	# Wrapped so _elapsed never grows large enough to lose float precision.
	_elapsed = fmod(_elapsed + delta, swing_period)
	_apply_swing_transform()


## Puts the ladle back at its starting phase without a visual smear.
func reset_immediately() -> void:
	_elapsed = fposmod(deg_to_rad(phase_degrees) * swing_period / TAU, swing_period)
	_last_swing_direction = _direction_at(_current_phase())
	_apply_swing_transform()
	swinging_part.reset_physics_interpolation()


# --- internals ---------------------------------------------------------------

func _resolve_axis() -> Vector3:
	match mode:
		SwingMode.SWEEP:
			return Vector3.UP
		SwingMode.GATE:
			return Vector3.RIGHT
		SwingMode.SCOOP:
			return Vector3.BACK
		_:
			return custom_axis.normalized() if custom_axis.length() > 0.001 else Vector3.UP


func _current_phase() -> float:
	return TAU * _elapsed / maxf(swing_period, 0.001)


func _direction_at(phase: float) -> int:
	return 1 if cos(phase) >= 0.0 else -1

func _apply_swing_transform() -> void:
	var phase := _current_phase()
	var angle := deg_to_rad(swing_offset_degrees + swing_angle_degrees * sin(phase))
	var next_transform := _neutral_transform
	next_transform.basis = _neutral_transform.basis * Basis(_axis, angle)
	swinging_part.transform = next_transform
	var direction := _direction_at(phase)
	if direction != _last_swing_direction:
		if direction > 0:
			reached_left_peak.emit()
		else:
			reached_right_peak.emit()
		_last_swing_direction = direction


func _build_bowl_collision() -> void:
	if bowl_collision == BowlCollision.NONE:
		return

	var bowl := get_node_or_null(bowl_mesh_path) as MeshInstance3D
	if bowl == null:
		bowl = model.find_child("Ladle_Bowl", true, false) as MeshInstance3D
	if bowl == null or bowl.mesh == null:
		push_warning("SwingingLadleObstacle: no bowl mesh found, collision not created.")
		return

	var shape: Shape3D
	if bowl_collision == BowlCollision.CONCAVE:
		var concave := bowl.mesh.create_trimesh_shape()
		concave.backface_collision = true
		shape = concave
	else:
		shape = bowl.mesh.create_convex_shape()

	var collision := CollisionShape3D.new()
	collision.name = "GeneratedBowlCollision"
	collision.shape = shape
	swinging_part.add_child(collision)
	collision.global_transform = bowl.global_transform

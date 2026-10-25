class_name CameraPivot
extends Node3D

@export var player_rig: PlayerRig

@export_group("Camera_Feel")
@export var stick_sensitivity := 3.0
@export var mouse_sensitivity := 0.003
@export var follow_speed := 10.0
@export var follow_offset := Vector3.ZERO
@export var min_pitch_degrees := -80.0
@export var max_pitch_degrees := 60.0
@export var orbit_max_pitch_degrees := -5.0
@export var capture_mouse := true 
@export var initial_yaw_degrees := 0.0
@export_range(0.0, 30.0, 0.1) var initial_follow_distance := 0.0

@export_group("Camera_Survey")
## How much further out the camera pulls while the survey button is held.
@export var survey_multiplier := 1.8
## Higher is snappier. Around 4 gives a readable half second pull.
@export var survey_blend_speed := 4.0

@export_group("Camera_Aim")
## How fast the camera swings onto the goal when aiming starts.
@export var aim_turn_speed := 6.0
## Tilts the aim down slightly so the marble stays in view, not just the goal.
@export var aim_pitch_bias_degrees := -10.0
## How far the player can look down from the aim line while aiming.
@export_range(0.0, 45.0, 0.5) var aim_pitch_down_degrees := 3.0
## How far the player can look up from the aim line while aiming.
@export_range(0.0, 45.0, 0.5) var aim_pitch_up_degrees := 8.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D



var player: Player
var _yaw := 0.0
var _pitch := deg_to_rad(-25.0)
var _base_length := 0.0
var _aim_target: Node3D
var _aim_clamp := 0.0
var _aim_yaw := 0.0
var _aim_pitch := 0.0

func _ready() -> void:
	if player_rig == null:
		push_error("%s has no player_rig assigned." % name)
		return
	#Rig found so we can assign camera pivot 
	_base_length = spring_arm.spring_length
	if initial_follow_distance > 0.0:
		spring_arm.spring_length = minf(initial_follow_distance, _base_length)
	_yaw = deg_to_rad(initial_yaw_degrees)
	rotation.y = _yaw
	spring_arm.rotation.x = _pitch
	$SpringArm3D/Camera3D.position.z = spring_arm.spring_length
	player_rig.player_swapped.connect(_on_player_swapped)
	player = player_rig.current_player
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	#Occlusion Fixes: Do not let spring arm occlude camera.
	if player != null: 
		# Exclude springarm from collision check
		spring_arm.add_excluded_object(player.get_rid())
		
## Locks the view onto target, letting the player nudge it by clamp_degrees.
func begin_aim(target: Node3D, clamp_degrees: float) -> void:
	_aim_target = target
	_aim_clamp = deg_to_rad(clamp_degrees)
	#Job 1: Start the centre where the camera already is, so the swing eases
	#       in rather than snapping.
	_aim_yaw = _yaw
	_aim_pitch = _pitch


## Hands control back. _yaw and _pitch already hold the current view, so free
## look continues from here with no snap.
func end_aim() -> void:
	_aim_target = null


func is_aiming() -> bool:
	return _aim_target != null and is_instance_valid(_aim_target)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# Stick look
	var look := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	_yaw -= look.x * stick_sensitivity * delta
	_pitch -= look.y * stick_sensitivity * delta
	_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	if is_aiming():
		_update_aim(delta)
	# Survey zoom and blend
	var target_length := _base_length
	if Input.is_action_pressed(&"camera_survey"):
		target_length *= survey_multiplier
	var blend := clampf(survey_blend_speed * delta, 0.0, 1.0)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_length, blend)
	
	# Follow the marble's POSITION only, never its rotation
	if player != null:
		var t := clampf(follow_speed * delta, 0.0, 1.0)
		global_position = global_position.lerp(player.global_position + follow_offset, t)

	# Yaw on the pivot, pitch on the arm. Never both on one node.
	rotation = Vector3(0.0, _yaw, 0.0)
	var orbit_pitch := minf(_pitch, deg_to_rad(orbit_max_pitch_degrees))
	spring_arm.rotation = Vector3(orbit_pitch, 0.0, 0.0)
	_camera.rotation.x = _pitch - orbit_pitch

func _update_aim(delta: float) -> void:
	#Job 1: Read the player's nudge BEFORE moving the centre. This frame's
	#       mouse and stick input are already folded into _yaw and _pitch.
	var nudge_yaw := clampf(wrapf(_yaw - _aim_yaw, -PI, PI), -_aim_clamp, _aim_clamp)
	var nudge_pitch := clampf(_pitch - _aim_pitch,-deg_to_rad(aim_pitch_down_degrees), deg_to_rad(aim_pitch_up_degrees))

	#Job 2: Angles that would put the goal dead ahead. -Z is forward in
	#       Godot, hence the negated atan2 for yaw.
	var to_goal := _aim_target.global_position - global_position
	var flat := Vector2(to_goal.x, to_goal.z).length()
	var goal_yaw := atan2(-to_goal.x, -to_goal.z)
	var goal_pitch := atan2(to_goal.y, flat) + deg_to_rad(aim_pitch_bias_degrees)

	#Job 3: Ease the centre onto the goal. lerp_angle takes the short way
	#       round, so a goal behind you never spins the long way.
	var t := clampf(aim_turn_speed * delta, 0.0, 1.0)
	_aim_yaw = lerp_angle(_aim_yaw, goal_yaw, t)
	_aim_pitch = lerpf(_aim_pitch, goal_pitch, t)

	#Job 4: The view is the centre plus the clamped nudge, still inside the
	#       rig's normal pitch limits.
	_yaw = _aim_yaw + nudge_yaw
	_pitch = clampf(_aim_pitch + nudge_pitch,deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))

func _on_player_swapped(new_player: Player) -> void:
	#Occlude Fix: Rerun occlusion fix of spring arm
	if player != null:
		spring_arm.remove_excluded_object(player.get_rid())
	#Job 1: Assign new_player to current player variable for camera
	player = new_player
	#Job 2: Exclude spring arm from collision check
	spring_arm.add_excluded_object(player.get_rid()) 

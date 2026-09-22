class_name CameraPivot
extends Node3D

@export var player_rig: PlayerRig

@export_group("Camera_Feel")
@export var stick_sensitivity := 3.0
@export var mouse_sensitivity := 0.003
@export var follow_speed := 10.0
@export var min_pitch_degrees := -50.0
@export var max_pitch_degrees := -5.0
@export var capture_mouse := true
@export var initial_yaw_degrees := 0.0
## Zero uses the normal follow distance; a shorter distance blends out at startup.
@export_range(0.0, 30.0, 0.1) var initial_follow_distance := 0.0

@export_group("Camera_Survey")
## How much further out the camera pulls while the survey button is held.
@export var survey_multiplier := 1.8
## Higher is snappier. Around 4 gives a readable half second pull.
@export var survey_blend_speed := 4.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var player: Player
var _yaw := 0.0
var _pitch := deg_to_rad(-25.0)
var _base_length := 0.0

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
	# Start at the intended distance before the spring arm's first physics tick.
	$SpringArm3D/Camera3D.position.z = spring_arm.spring_length
	player_rig.player_swapped.connect(_on_player_swapped)
	player = player_rig.current_player
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	#Occlusion Fixes: Do not let spring arm occlude camera.
	if player != null: 
		# Exclude springarm from collision check
		spring_arm.add_excluded_object(player.get_rid())

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
	
	# Survey zoom and blend
	var target_length := _base_length
	if Input.is_action_pressed(&"camera_survey"):
		target_length *= survey_multiplier
	var blend := clampf(survey_blend_speed * delta, 0.0, 1.0)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_length, blend)
	
	# Follow the marble's POSITION only, never its rotation
	if player != null:
		var t := clampf(follow_speed * delta, 0.0, 1.0)
		global_position = global_position.lerp(player.global_position, t)

	# Yaw on the pivot, pitch on the arm. Never both on one node.
	rotation = Vector3(0.0, _yaw, 0.0)
	spring_arm.rotation = Vector3(_pitch, 0.0, 0.0)


func _on_player_swapped(new_player: Player) -> void:
	#Occlude Fix: Rerun occlusion fix of spring arm
	if player != null:
		spring_arm.remove_excluded_object(player.get_rid())
	#Job 1: Assign new_player to current player variable for camera
	player = new_player
	#Job 2: Exclude spring arm from collision check
	spring_arm.add_excluded_object(player.get_rid()) 

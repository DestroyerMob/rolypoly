extends Node3D

@export_category("Follow View")
@export_range(10.0, 80.0, 1.0) var minimum_pitch_degrees := 18.0
@export_range(10.0, 85.0, 1.0) var maximum_pitch_degrees := 72.0
@export_range(1.0, 15.0, 0.5) var wheel_pitch_step_degrees := 5.0
@export_range(0.05, 1.0, 0.05) var mouse_pitch_sensitivity := 0.22
@export_range(10.0, 90.0, 1.0) var keyboard_pitch_speed := 42.0

@onready var player: Player = $"../Player"
var start_offset: Vector3
var _follow_distance := 1.0
var _horizontal_direction := Vector3.BACK
var _pitch_radians := deg_to_rad(45.0)

func _ready() -> void:
	start_offset = global_position - player.global_position
	_follow_distance = maxf(start_offset.length(), 0.1)
	var horizontal := Vector3(start_offset.x, 0.0, start_offset.z)
	if horizontal.length_squared() > 0.0001:
		_horizontal_direction = horizontal.normalized()
	_pitch_radians = atan2(start_offset.y, maxf(horizontal.length(), 0.001))
	_set_pitch_degrees(rad_to_deg(_pitch_radians))
	follow_player()

func _physics_process(delta: float) -> void:
	var keyboard_input := (
		float(Input.is_physical_key_pressed(KEY_X))
		- float(Input.is_physical_key_pressed(KEY_Z))
	)
	if not is_zero_approx(keyboard_input):
		_set_pitch_degrees(rad_to_deg(_pitch_radians) + keyboard_input * keyboard_pitch_speed * delta)
	follow_player()


func _unhandled_input(event: InputEvent) -> void:
	# LevelBuilder disables follow physics while using its free camera.
	if not is_physics_processing():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_pitch_degrees(rad_to_deg(_pitch_radians) + wheel_pitch_step_degrees)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_pitch_degrees(rad_to_deg(_pitch_radians) - wheel_pitch_step_degrees)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_set_pitch_degrees(rad_to_deg(_pitch_radians) - event.relative.y * mouse_pitch_sensitivity)
		get_viewport().set_input_as_handled()

func follow_player() -> void:
	global_position = player.global_position + start_offset
	look_at(player.global_position, Vector3.UP)


func _set_pitch_degrees(value: float) -> void:
	var minimum := minf(minimum_pitch_degrees, maximum_pitch_degrees)
	var maximum := maxf(minimum_pitch_degrees, maximum_pitch_degrees)
	_pitch_radians = deg_to_rad(clampf(value, minimum, maximum))
	var horizontal_distance := cos(_pitch_radians) * _follow_distance
	start_offset = (
		_horizontal_direction * horizontal_distance
		+ Vector3.UP * sin(_pitch_radians) * _follow_distance
	)

func restore_follow_view() -> void:
	follow_player()

func move_free(delta: float, speed: float) -> void:
	var movement := Input.get_vector("left", "right", "forward", "backward")
	var vertical := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	var direction := global_basis * Vector3(movement.x, 0, movement.y) + Vector3.UP * vertical
	global_position += direction.limit_length() * speed * delta

func look_free(mouse_motion: Vector2) -> void:
	rotation.y -= mouse_motion.x * 0.003
	rotation.x = clampf(rotation.x - mouse_motion.y * 0.003, -1.5, 1.5)

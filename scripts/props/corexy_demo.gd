extends Node3D

@onready var camera: Camera3D = $Camera3D
@export var start_above_dicer := true
var _passages := 0
var _focus := Vector3(0, 1.0, 0)
var _distance := 17.0
var _yaw := 0.65
var _pitch := 0.55


func _ready() -> void:
	_update_camera()
	$CoreXY.player_passed_through.connect(_on_player_passed_through)
	if start_above_dicer:
		_drop_into_dicer.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_P:
		$CoreXY.active = not $CoreXY.active
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		_drop_into_dicer()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch + event.relative.y * 0.006, 0.12, 1.45)
		_update_camera()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(5.0, _distance - 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(30.0, _distance + 1.0)
		else:
			return
		_update_camera()
		get_viewport().set_input_as_handled()


func _update_camera() -> void:
	camera.position = _focus + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	camera.look_at(_focus)


func _drop_into_dicer() -> void:
	var dicer: Node3D = $CoreXY/Carriage/AttachmentSocket/RazorDicer
	var destination := Transform3D(Basis.IDENTITY, dicer.global_position + Vector3.UP * 1.4)
	$Player.teleport_to(destination, $CoreXY.get_travel_velocity() + Vector3.DOWN)


func _on_player_passed_through(_player: Player) -> void:
	_passages += 1
	$HUD/PassageStatus.text = "Blade passages: %d — player sent below the dicer" % _passages
	print("Dicer passage %d: player sent through the outlet." % _passages)

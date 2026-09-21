extends Node3D

var _camera_tween: Tween
var _main_camera_transform: Transform3D
var _transitioning := false

@onready var _main_controls: Array[Control] = [$MainTitle, $MenuButtonsCenter, $LevelGridCenter]
@onready var _settings_controls: Array[Control] = [$SettingsTitle, $SettingsButtonsCenter]


func _ready() -> void:
	_main_camera_transform = $Camera3D.global_transform
	for control in _settings_controls:
		control.hide()
		control.modulate.a = 0.0
	$MenuButtonsCenter/MenuButtons/SettingsButton.pressed.connect(_show_settings.bind(true))
	$SettingsButtonsCenter/MenuButtons/Back.pressed.connect(_show_settings.bind(false))


func _show_settings(show_settings: bool) -> void:
	if _transitioning:
		return
	_transitioning = true
	var outgoing := _main_controls if show_settings else _settings_controls
	var incoming := _settings_controls if show_settings else _main_controls
	var destination: Transform3D = $SettingsAnchor.global_transform if show_settings else _main_camera_transform
	_camera_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_method(
		_move_camera.bind($Camera3D.global_transform, destination),
		0.0, 1.0, 0.8
	)
	for control in outgoing:
		_camera_tween.tween_property(control, "modulate:a", 0.0, 0.2)
		_camera_tween.tween_callback(control.hide).set_delay(0.2)
	for control in incoming:
		_camera_tween.tween_callback(control.show).set_delay(0.6)
		_camera_tween.tween_property(control, "modulate:a", 1.0, 0.2).set_delay(0.6)
	_camera_tween.finished.connect(func(): _transitioning = false)


func _move_camera(weight: float, start: Transform3D, destination: Transform3D) -> void:
	$Camera3D.global_transform = start.interpolate_with(destination, weight)

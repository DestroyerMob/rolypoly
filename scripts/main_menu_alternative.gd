extends Node3D

const Store = preload("res://scripts/level_editor/level_store.gd")
const KITCHEN_GYM := "res://scenes/gym_pieces.tscn"

var _camera_tween: Tween
var _main_camera_transform: Transform3D
var _transitioning := false
var _settings_shown := false
var _levels_shown := false
var _opening_scene := false
var _level_set: Array[String] = []

@onready var _main_controls: Array[Control] = [$MainTitle, $MenuButtonsCenter]
@onready var _settings_controls: Array[Control] = [$SettingsTitle, $SettingsButtonsCenter]
@onready var _volume_slider: HSlider = $SettingsButtonsCenter/MenuButtons/VolumePanel/Content/VolumeSlider
@onready var _volume_value: Label = $SettingsButtonsCenter/MenuButtons/VolumePanel/Content/Heading/Value
@onready var _play_button: Button = $MenuButtonsCenter/MenuButtons/PlayButton
@onready var _level_grid: Control = $LevelGridCenter
@onready var _message: AcceptDialog = $MenuMessage


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var browser: Variant = preload("res://scripts/level_editor/level_browser.gd").install(self, $MenuButtonsCenter/MenuButtons)
	browser.set_changed.connect(_refresh_level_slots)
	_main_camera_transform = $Camera3D.global_transform
	_level_grid.hide()
	for control in _settings_controls:
		control.hide()
		control.modulate.a = 0.0
	_play_button.pressed.connect(_show_levels.bind(true))
	$LevelGridCenter/LevelVBox/BackButton.pressed.connect(_show_levels.bind(false))
	$"MenuButtonsCenter/MenuButtons/Kitchen Gym".pressed.connect(_open_scene.bind(KITCHEN_GYM))
	$MenuButtonsCenter/MenuButtons/AchievementsButton.pressed.connect(_show_achievements)
	$MenuButtonsCenter/MenuButtons/SettingsButton.pressed.connect(_show_settings.bind(true))
	$MenuButtonsCenter/MenuButtons/QuitButton.pressed.connect(_quit)
	$SettingsButtonsCenter/MenuButtons/Back.pressed.connect(_show_settings.bind(false))
	for child in $LevelGridCenter/LevelVBox/LevelGrid.get_children():
		var button := child as LevelButton
		if button != null:
			button.pressed.connect(_on_level_pressed.bind(button.level_number))
	_refresh_level_slots()
	_volume_slider.set_value_no_signal($MenuMusic.volume_percent)
	_volume_value.text = "Muted" if _volume_slider.value == 0.0 else "%d%%" % _volume_slider.value
	_volume_slider.value_changed.connect(_on_music_volume_changed)
	_play_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if _settings_shown:
			_show_settings(false)
		elif _levels_shown:
			_show_levels(false)
		get_viewport().set_input_as_handled()


func _show_levels(show_levels: bool) -> void:
	if _transitioning or _settings_shown or _opening_scene:
		return
	_levels_shown = show_levels
	_level_grid.visible = show_levels
	if show_levels:
		_refresh_level_slots()
		$LevelGridCenter/LevelVBox/BackButton.grab_focus()
		for child in $LevelGridCenter/LevelVBox/LevelGrid.get_children():
			if child is LevelButton and not child.disabled:
				child.grab_focus()
				break
	else:
		_play_button.grab_focus()


func _refresh_level_slots() -> void:
	_level_set = Store.level_set()
	for child in $LevelGridCenter/LevelVBox/LevelGrid.get_children():
		var button := child as LevelButton
		if button == null:
			continue
		button.unlocked = button.level_number <= _level_set.size()
		button.tooltip_text = ""
		if button.unlocked:
			var level := Store.read_level(_level_set[button.level_number - 1])
			button.tooltip_text = level.document.name if level.has("document") else level.error


func _on_level_pressed(level_number: int) -> void:
	if _transitioning or _opening_scene or level_number > _level_set.size():
		return
	var filename := _level_set[level_number - 1]
	var level := Store.read_level(filename)
	var problem: String = level.get("error", "")
	if problem.is_empty():
		problem = Store.playable_error(level.document)
	if not problem.is_empty():
		_message.title = "Could not open level"
		_message.dialog_text = problem
		_message.popup_centered()
		return
	_opening_scene = true
	var result := Store.launch(get_tree(), level.document, filename, false)
	if result != OK:
		_opening_scene = false
		_message.title = "Could not open level"
		_message.dialog_text = "Please try again. (%s)" % error_string(result)
		_message.popup_centered()


func _open_scene(path: String) -> void:
	if _transitioning or _opening_scene:
		return
	_opening_scene = true
	_change_scene.call_deferred(path)


func _change_scene(path: String) -> void:
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		_opening_scene = false
		_message.title = "Could not open level"
		_message.dialog_text = "Please try again. (%s)" % error_string(result)
		_message.popup_centered()


func _show_achievements() -> void:
	if _transitioning:
		return
	_message.title = "Achievements"
	_message.dialog_text = "Achievements are not available yet."
	_message.popup_centered()


func _quit() -> void:
	if not _transitioning:
		get_tree().quit()


func _on_music_volume_changed(value: float) -> void:
	_volume_value.text = "Muted" if value == 0.0 else "%d%%" % value
	$MenuMusic.set_volume_percent(value)


func _show_settings(show_settings: bool) -> void:
	if _transitioning or _opening_scene:
		return
	_transitioning = true
	_settings_shown = show_settings
	var main_controls: Array[Control] = _main_controls.duplicate()
	if _levels_shown:
		main_controls.append(_level_grid)
	var outgoing := main_controls if show_settings else _settings_controls
	var incoming := _settings_controls if show_settings else main_controls
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
	_camera_tween.finished.connect(func():
		_transitioning = false
		if show_settings:
			_volume_slider.grab_focus()
		else:
			$MenuButtonsCenter/MenuButtons/SettingsButton.grab_focus()
	)


func _move_camera(weight: float, start: Transform3D, destination: Transform3D) -> void:
	$Camera3D.global_transform = start.interpolate_with(destination, weight)

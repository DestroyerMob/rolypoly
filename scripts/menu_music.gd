extends AudioStreamPlayer

const SETTINGS_PATH := "user://menu_audio.cfg"

var volume_percent := 100.0
var _mix_volume := 1.0
var _settings := ConfigFile.new()


func _ready() -> void:
	_mix_volume = volume_linear
	_settings.load(SETTINGS_PATH)
	volume_percent = clampf(float(_settings.get_value("audio", "music_volume", 100.0)), 0.0, 100.0)
	volume_linear = _mix_volume * volume_percent / 100.0
	$SaveDelay.timeout.connect(_save_volume)


func set_volume_percent(percent: float) -> void:
	volume_percent = clampf(percent, 0.0, 100.0)
	volume_linear = _mix_volume * volume_percent / 100.0
	$SaveDelay.start()


func _save_volume() -> void:
	_settings.set_value("audio", "music_volume", volume_percent)
	var error := _settings.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save music volume: %s" % error_string(error))


func _exit_tree() -> void:
	if not $SaveDelay.is_stopped():
		_save_volume()

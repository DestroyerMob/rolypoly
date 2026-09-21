extends Control

@onready var play_button: Button = $MenuButtonsCenter/MenuButtons/PlayButton
@onready var achievements_button: Button = $MenuButtonsCenter/MenuButtons/AchievementsButton
@onready var settings_button: Button = $MenuButtonsCenter/MenuButtons/SettingsButton
@onready var quit_button: Button = $MenuButtonsCenter/MenuButtons/QuitButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hole_one.tscn")

func _on_achievements_pressed() -> void:
	print("Achievements not implemented yet")

func _on_settings_pressed() -> void:
	print("Settings not implemented yet")

func _on_quit_pressed() -> void:
	get_tree().quit()

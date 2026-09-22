extends Control

const LEVEL_SCENES := {
	1: "res://scenes/hole_one.tscn",
	2: "res://scenes/hole_two.tscn",
}
const SLIDE_TIME := 0.6
const REVEAL_TIME := 0.5
const REVEAL_DELAY := 0.25
const TITLE_BUTTON_GAP := 24.0
const GRID_SLIDE_OFFSET := Vector2(120, 0)
const KITCHEN_GYM := preload("res://scenes/gym_pieces.tscn")
 
@onready var main_title: Control = $MainTitle
@onready var menu_center: Control = $MenuButtonsCenter
@onready var menu_buttons: Control = $MenuButtonsCenter/MenuButtons
@onready var veg_container: Control = $VegViewportContainer
@onready var level_grid_center: Control = $LevelGridCenter
@onready var level_grid: GridContainer = $LevelGridCenter/LevelVBox/LevelGrid
@onready var play_button: Button = $MenuButtonsCenter/MenuButtons/PlayButton
@onready var achievements_button: Button = $MenuButtonsCenter/MenuButtons/AchievementsButton
@onready var settings_button: Button = $MenuButtonsCenter/MenuButtons/SettingsButton
@onready var quit_button: Button = $MenuButtonsCenter/MenuButtons/QuitButton
#IROH TO REMOVE FOR PRODUCTION
@onready var kitchen_gym_button: Button = $"MenuButtonsCenter/MenuButtons/Kitchen Gym"

var _levels_shown := false
var _final_title_pos: Vector2
var _final_menu_pos: Vector2
var _final_grid_pos: Vector2

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	kitchen_gym_button.pressed.connect(_on_kitchen_gym_pressed)

	for child in level_grid.get_children():
		var level_button := child as LevelButton
		if level_button:
			level_button.pressed.connect(_on_level_pressed.bind(level_button.level_number))

	# Hide for one frame so containers can lay out before the intro positions are set.
	modulate.a = 0.0
	await get_tree().process_frame
	_final_title_pos = main_title.position
	_final_menu_pos = menu_center.position
	_final_grid_pos = level_grid_center.position
	_place_intro_layout()
	modulate.a = 1.0

func _place_intro_layout() -> void:
	level_grid_center.hide()
	veg_container.hide()

	var group_height := main_title.size.y + TITLE_BUTTON_GAP + menu_buttons.size.y
	var top := (size.y - group_height) / 2.0
	main_title.position = Vector2((size.x - main_title.size.x) / 2.0, top)

	var buttons_mid_y := top + main_title.size.y + TITLE_BUTTON_GAP + menu_buttons.size.y / 2.0
	menu_center.position = Vector2(
		(size.x - menu_center.size.x) / 2.0,
		buttons_mid_y - menu_center.size.y / 2.0
	)

func _on_play_pressed() -> void:
	if _levels_shown:
		return
	_levels_shown = true

	level_grid_center.modulate.a = 0.0
	veg_container.modulate.a = 0.0
	level_grid_center.position = _final_grid_pos + GRID_SLIDE_OFFSET
	level_grid_center.show()
	veg_container.show()

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(main_title, "position", _final_title_pos, SLIDE_TIME)
	tween.tween_property(menu_center, "position", _final_menu_pos, SLIDE_TIME)
	tween.tween_property(level_grid_center, "position", _final_grid_pos, REVEAL_TIME).set_delay(REVEAL_DELAY)
	tween.tween_property(level_grid_center, "modulate:a", 1.0, REVEAL_TIME).set_delay(REVEAL_DELAY)
	tween.tween_property(veg_container, "modulate:a", 1.0, REVEAL_TIME).set_delay(REVEAL_DELAY)

func _on_level_pressed(level_number: int) -> void:
	var path: String = LEVEL_SCENES.get(level_number, "")
	if path.is_empty():
		print("Level %d is not available yet" % level_number)
		return
	get_tree().change_scene_to_file(path)

func _on_achievements_pressed() -> void:
	print("Achievements not implemented yet")

func _on_settings_pressed() -> void:
	print("Settings not implemented yet")

func _on_quit_pressed() -> void:
	get_tree().quit()
	
func _on_kitchen_gym_pressed() ->void:
	get_tree().change_scene_to_packed(KITCHEN_GYM)

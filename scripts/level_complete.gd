class_name LevelComplete
extends CanvasLayer

## The end-of-level card: a title banner, up to three stars, and Retry / Next Level / Home.

signal retry_pressed
signal next_pressed
signal home_pressed

@export var level_title := "Level Complete"
@export_range(0, 3) var stars := 3
@export_file("*.tscn") var next_level_scene := ""
@export_file("*.tscn") var home_scene := "res://scenes/main_menu_alternative.tscn"
@export var pause_game := true
@export var show_mouse := true
@export var start_hidden := true

@onready var _card: Control = %Card
@onready var _title: Label = %Title
@onready var _stars: Control = %Stars
@onready var _retry: Button = %RetryButton
@onready var _next: Button = %NextButton
@onready var _home: Button = %HomeButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_retry.pressed.connect(_on_retry)
	_next.pressed.connect(_on_next)
	_home.pressed.connect(_on_home)
	_refresh()
	visible = not start_hidden


## Shows the card. Pass a title or star count to override what is set in the Inspector.
func show_result(result_title := "", star_count := -1) -> void:
	if not result_title.is_empty():
		level_title = result_title
	if star_count >= 0:
		stars = star_count
	_refresh()
	visible = true
	if pause_game:
		get_tree().paused = true
	if show_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_intro()


## For connecting to a finish area's level_completed signal, which passes the player.
func show_on_finish(_player: Node = null) -> void:
	show_result()


func _refresh() -> void:
	_title.text = level_title
	for index in _stars.get_child_count():
		_stars.get_child(index).set("lit", index < stars)
	_next.visible = not next_level_scene.is_empty() or not next_pressed.get_connections().is_empty()


func _play_intro() -> void:
	await get_tree().process_frame
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * 0.8
	_card.modulate.a = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	tween.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, 0.2)
	for index in _stars.get_child_count():
		var star: Control = _stars.get_child(index)
		star.scale = Vector2.ZERO
		tween.tween_property(star, "scale", Vector2.ONE, 0.35).set_delay(0.3 + index * 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_retry() -> void:
	retry_pressed.emit()
	if retry_pressed.get_connections().is_empty():
		_resume()
		get_tree().reload_current_scene()


func _on_next() -> void:
	next_pressed.emit()
	if next_pressed.get_connections().is_empty() and not next_level_scene.is_empty():
		_resume()
		get_tree().change_scene_to_file(next_level_scene)


func _on_home() -> void:
	home_pressed.emit()
	if home_pressed.get_connections().is_empty():
		_resume()
		get_tree().change_scene_to_file(home_scene)


func _resume() -> void:
	get_tree().paused = false

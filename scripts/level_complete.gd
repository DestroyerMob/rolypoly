class_name LevelComplete
extends CanvasLayer

## The end-of-level card: a title banner, up to three stars, and Retry / Next Level / Home.

const Store = preload("res://scripts/level_editor/level_store.gd")
const Progress = preload("res://scripts/level_progress.gd")

signal retry_pressed
signal next_pressed
signal home_pressed

@export var level_title := "Level Complete"
## The line under the stars.
@export var subtitle := "Level Complete!"
@export_range(0, 3) var stars := 0
@export_file("*.tscn") var home_scene := "res://scenes/main_menu_alternative.tscn"
@export var pause_game := true
@export var show_mouse := true
@export var start_hidden := true
## The level's entry in the level list, when that isn't the current scene's file: a
## level-editor level is played inside custom_level.tscn, so it passes its filename.
var level_entry := ""
## Hide Next Level, e.g. after losing.
var next_allowed := true

@onready var _card: Control = %Card
@onready var _title: Label = %Title
@onready var _subtitle: Label = $Center/Card/Content/SubtitleRow/Subtitle/Label
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
func show_result(result_title := "", star_count := -1, player: Node = null) -> void:
	if not result_title.is_empty():
		level_title = result_title
	if star_count >= 0:
		stars = star_count
	else:
		stars = _earned_stars(player)
	_refresh()
	Progress.record(_entry(), stars)
	visible = true
	if pause_game:
		get_tree().paused = true
	if show_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_intro()


## For connecting to a finish area's level_completed signal, which passes the player.
func show_on_finish(player: Node = null) -> void:
	show_result("", -1, player)


## Adds up the stars of every StarGoal in the level that was earned, capped at 3. A level with
## no goals keeps the `stars` set in the Inspector.
func _earned_stars(player: Node) -> int:
	var goals := get_tree().get_nodes_in_group(&"star_goal")
	if goals.is_empty():
		return stars
	var total := 0
	for goal in goals:
		total += goal.earned_stars(player)
	return mini(total, 3)


func _refresh() -> void:
	_title.text = level_title
	_subtitle.text = subtitle
	for index in _stars.get_child_count():
		_stars.get_child(index).set("lit", index < stars)
	_next.visible = next_allowed and (not _next_entry().is_empty() or not next_pressed.get_connections().is_empty())


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
	var entry := _next_entry()
	if next_pressed.get_connections().is_empty() and not entry.is_empty():
		_open_entry(entry)


func _on_home() -> void:
	home_pressed.emit()
	if home_pressed.get_connections().is_empty():
		_resume()
		# The main menu opens straight onto the level grid.
		get_tree().set_meta(&"show_level_grid", true)
		get_tree().change_scene_to_file(home_scene)


## The level after this one in the Play menu's level list, or "" if this is the last
## or isn't in the list.
func _next_entry() -> String:
	var order := Store.level_set()
	var index := order.find(_entry())
	return order[index + 1] if index >= 0 and index + 1 < order.size() else ""


func _entry() -> String:
	if not level_entry.is_empty():
		return level_entry
	var current := get_tree().current_scene
	return current.scene_file_path if current != null else ""


func _open_entry(entry: String) -> void:
	if Store.is_scene(entry):
		_resume()
		get_tree().change_scene_to_file(entry)
		return
	var level := Store.read_level(entry)
	if level.has("error") or not Store.playable_error(level.document).is_empty():
		push_warning("Could not open the next level (%s): %s" % [entry, level.get("error", Store.playable_error(level.document))])
		return
	_resume()
	Store.launch(get_tree(), level.document, entry, false)


func _resume() -> void:
	get_tree().paused = false

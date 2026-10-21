class_name LevelButton
extends Button

@export var level_number: int = 1
@export_range(0, 3) var stars_earned: int = 0
@export var unlocked: bool = true:
	set(value):
		unlocked = value
		if is_node_ready():
			_update_lock()

@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var stars: HBoxContainer = $VBoxContainer/Stars
@onready var lock_icon: TextureRect = $VBoxContainer/Lock
@onready var star_labels: Array[Label] = [
	$VBoxContainer/Stars/Star1,
	$VBoxContainer/Stars/Star2,
	$VBoxContainer/Stars/Star3,
]

func _ready() -> void:
	level_label.text = str(level_number)
	_update_lock()
	_update_stars()

func _update_lock() -> void:
	disabled = not unlocked
	stars.visible = unlocked
	lock_icon.visible = not unlocked
	level_label.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.48, 0.45, 0.43))

func _update_stars() -> void:
	for i in star_labels.size():
		star_labels[i].modulate = Color(1, 0.84, 0) if i < stars_earned else Color(0.72, 0.8, 0.72, 0.8)

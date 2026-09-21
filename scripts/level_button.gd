extends Button

@export var level_number: int = 1
@export_range(0, 3) var stars_earned: int = 0

@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var star_labels: Array[Label] = [
	$VBoxContainer/Stars/Star1,
	$VBoxContainer/Stars/Star2,
	$VBoxContainer/Stars/Star3,
]

func _ready() -> void:
	level_label.text = str(level_number)
	_update_stars()

func _update_stars() -> void:
	for i in star_labels.size():
		star_labels[i].modulate = Color(1, 0.84, 0) if i < stars_earned else Color(0.45, 0.45, 0.45)

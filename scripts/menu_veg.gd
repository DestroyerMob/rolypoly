extends Node3D

@export var sway_angle := 0.35
@export var sway_speed := 1.2
@export var bob_height := 0.12
@export var bob_speed := 2.0
@export var phase := 0.0

var _time := 0.0
var _base_y := 0.0

func _ready() -> void:
	_base_y = position.y
	_time = phase

func _process(delta: float) -> void:
	_time += delta
	rotation.y = sin(_time * sway_speed) * sway_angle
	position.y = _base_y + sin(_time * bob_speed) * bob_height

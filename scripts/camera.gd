extends Node3D

@onready var player: Player = $"../Player"
var start_position: Vector3

func _ready() -> void:
	start_position = global_position

func _physics_process(delta: float) -> void:
	global_position = start_position + player.global_position

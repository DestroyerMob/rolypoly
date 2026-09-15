extends Node3D

@onready var player: Player = $"../Player"
var start_offset: Vector3

func _ready() -> void:
	start_offset = global_position - player.global_position

func _physics_process(delta: float) -> void:
	global_position = player.global_position + start_offset
	look_at(player.global_position, Vector3.UP)

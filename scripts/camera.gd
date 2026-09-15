extends Node3D

@onready var player: Player = $"../Player"
var start_offset: Vector3

func _ready() -> void:
	start_offset = global_position - player.global_position

func _physics_process(_delta: float) -> void:
	follow_player()

func follow_player() -> void:
	global_position = player.global_position + start_offset
	look_at(player.global_position, Vector3.UP)

func restore_follow_view() -> void:
	follow_player()

func move_free(delta: float, speed: float) -> void:
	var movement := Input.get_vector("left", "right", "forward", "backward")
	var vertical := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	var direction := global_basis * Vector3(movement.x, 0, movement.y) + Vector3.UP * vertical
	global_position += direction.limit_length() * speed * delta

func look_free(mouse_motion: Vector2) -> void:
	rotation.y -= mouse_motion.x * 0.003
	rotation.x = clampf(rotation.x - mouse_motion.y * 0.003, -1.5, 1.5)

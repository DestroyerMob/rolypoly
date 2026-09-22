extends Node3D

@onready var player: Player
@export var player_rig: PlayerRig 
var start_offset: Vector3

## Camera needs a player rig to work
func _ready() -> void:
	#Guards
	if player_rig == null:
		push_error("%s has no player_rig assigned." % name)
		return 
	#Signal Connections
	player_rig.player_swapped.connect(_on_player_swapped)
	player = player_rig.current_player
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

func _on_player_swapped(new_player: Player) -> void:
	#Assign new_player to current camera's player and physics process will update it 
	player = new_player
	

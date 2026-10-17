extends Node3D

signal swallowed
@export var sweep_distance := 5.0
@export var cycle_seconds := 8.0
@export var opening_half_size := Vector2(5.4, 4.4)
@export var player: Player
var elapsed := 0.0
var accepted := false
var home := Vector3.ZERO

func _ready() -> void:
	home = position

func _physics_process(delta: float) -> void:
	if accepted:
		return
	elapsed += delta
	position = home + basis.x * sin(elapsed * TAU / cycle_seconds) * sweep_distance
	if not is_instance_valid(player):
		return
	var local := to_local(player.global_position)
	# Test the actual opening, not a large trigger around the whole face.
	# Allow for the scoop radius so brushing the lips cannot finish the level.
	var available := opening_half_size - Vector2.ONE * 2.2
	var inside := pow(local.x / available.x, 2) + pow(local.y / available.y, 2) <= 1.0
	var local_velocity := global_basis.inverse() * player.linear_velocity
	if inside and local.z < 0.65 and local.z > -1.2 and local_velocity.z < -0.5:
		accepted = true
		swallowed.emit()

extends AnimatableBody3D

signal player_passed_through(player: Player)

@export_range(0.1, 10.0, 0.1, "suffix:m/s") var minimum_exit_speed := 2.0
@onready var outlet: Marker3D = $Outlet
var _passing: Dictionary = {}


func _ready() -> void:
	$BladeTrigger.body_entered.connect(_on_blades_entered)
	$BladeTrigger.body_exited.connect(_on_blades_exited)


func _on_blades_entered(body: Node3D) -> void:
	if not body is Player or _passing.has(body.get_instance_id()):
		return
	_passing[body.get_instance_id()] = true
	_transfer_player.call_deferred(body)


func _on_blades_exited(body: Node3D) -> void:
	_passing.erase(body.get_instance_id())


func _transfer_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	var up := global_basis.y.normalized()
	var clearance := player.spawn_clearance
	var collider := player.collider as CollisionShape3D
	if collider != null and collider.shape != null:
		var bounds := collider.shape.get_debug_mesh().get_aabb()
		for corner in range(8):
			var offset := collider.global_transform * bounds.get_endpoint(corner) - player.global_position
			clearance = maxf(clearance, offset.dot(up))
	var destination := player.global_transform
	destination.origin = outlet.global_position - up * clearance
	var velocity := player.linear_velocity
	velocity -= up * (velocity.dot(up) + maxf(minimum_exit_speed, -velocity.dot(up)))
	player.teleport_to(destination, velocity)
	player_passed_through.emit(player)

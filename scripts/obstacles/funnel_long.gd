class_name FunnelLongObstacle
extends Node3D

signal player_entered_tube(player: Player)
signal player_released(player: Player)

@export_category("Destination")
@export_node_path("Node3D") var drop_target_path: NodePath
@export var release_velocity := Vector3(0.0, -1.5, 0.0)

@export_category("Transition")
@export_range(0.0, 1.0, 0.01) var transition_delay := 0.08
@export_range(0.0, 2.0, 0.05) var cooldown := 0.35

@onready var model: Node3D = $Model
@onready var tube_exit: Area3D = $TubeExit
@onready var default_drop_point: Marker3D = $DefaultDropPoint

var _busy := false


func _ready() -> void:
	_create_funnel_collision()
	tube_exit.body_entered.connect(_on_tube_exit_body_entered)


func _on_tube_exit_body_entered(body: Node3D) -> void:
	if _busy or not body is Player:
		return
	_drop_player_at_target(body as Player)


func _drop_player_at_target(player: Player) -> void:
	_busy = true
	player_entered_tube.emit(player)
	player.freeze = true
	player.sleeping = false
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO

	if transition_delay > 0.0:
		await get_tree().create_timer(transition_delay).timeout
	if not is_instance_valid(player):
		_busy = false
		return

	var destination := _get_drop_target()
	player.global_position = destination.global_position
	player.reset_physics_interpolation()
	player.freeze = false
	player.sleeping = false
	player.linear_velocity = release_velocity
	player.angular_velocity = Vector3.ZERO
	player_released.emit(player)

	if cooldown > 0.0:
		await get_tree().create_timer(cooldown).timeout
	_busy = false


func _create_funnel_collision() -> void:
	var body_mesh := model.find_child("FunnelLong_Body", true, false) as MeshInstance3D
	if body_mesh == null or body_mesh.mesh == null:
		push_warning("FunnelLong_Body mesh was not found.")
		return
	var static_body := StaticBody3D.new()
	static_body.name = "GeneratedFunnelCollision"
	body_mesh.get_parent().add_child(static_body)
	static_body.transform = body_mesh.transform
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := body_mesh.mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	static_body.add_child(collision)


func _get_drop_target() -> Node3D:
	if not drop_target_path.is_empty():
		var target := get_node_or_null(drop_target_path) as Node3D
		if target:
			return target
	return default_drop_point

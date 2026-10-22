class_name FunnelObstacle
extends Node3D

signal player_captured(player: Player)
signal player_released(player: Player)

@export_category("Destination")
@export_node_path("Node3D") var drop_target_path: NodePath
@export var release_velocity := Vector3(0.0, -1.5, 0.0)
## Channel links funnel to funnel exit. 0 Uses drop_target_path or the built-in drop point. 1 ore more looks for a funnel exit with the same channel. Used in the level builder.
@export_range(0,20) var channel := 0 

@export_category("Transition")
@export_range(0.0, 1.0, 0.01) var transition_delay := 0.08
@export_range(0.0, 2.0, 0.05) var cooldown := 0.35

@onready var model: Node3D = $Model
@onready var throat_area: Area3D = $ThroatArea
@onready var default_drop_point: Marker3D = $DefaultDropPoint

var _busy := false


func _ready() -> void:
	_create_physical_funnel_collision()
	throat_area.body_entered.connect(_on_throat_area_body_entered)


func _on_throat_area_body_entered(body: Node3D) -> void:
	var player = body
	if _busy or not body is Player:
		return
	player.enter_condition(Player.Condition.DIZZY)
	_drop_player_at_target(body as Player)


func _drop_player_at_target(player: Player) -> void:
	_busy = true
	player_captured.emit(player)
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
	player.exit_condition(Player.Condition.NORMAL)
	if cooldown > 0.0:
		await get_tree().create_timer(cooldown).timeout
	_busy = false


func _create_physical_funnel_collision() -> void:
	var body_mesh := model.find_child("Funnel_Body", true, false) as MeshInstance3D
	if body_mesh == null or body_mesh.mesh == null:
		push_warning("Funnel_Body mesh was not found; physical funnel collision was not created.")
		return

	var static_body := StaticBody3D.new()
	static_body.name = "GeneratedFunnelCollision"
	body_mesh.get_parent().add_child(static_body)
	static_body.transform = body_mesh.transform

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = body_mesh.mesh.create_trimesh_shape()
	static_body.add_child(collision)


func _get_drop_target() -> Node3D:
	#Job 1: Use a channel, as it is the only link a builder level can save within the item properties.
	if channel > 0:
		for exit in get_tree().get_nodes_in_group(&"funnel_exit"):
			if exit is FunnelExit and exit.channel == channel:
				return exit
		push_warning("Funnel channel %d has no matching FunnelExit." % channel)

	#Job 2: Hand-built scenes can still use the NodePath.
	if not drop_target_path.is_empty():
		var target := get_node_or_null(drop_target_path) as Node3D
		if target:
			return target
	return default_drop_point
	

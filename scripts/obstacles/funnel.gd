class_name FunnelObstacle
extends Node3D

signal player_captured(player: Player)
signal player_released(player: Player)

@export_category("Destination")
@export_node_path("Node3D") var drop_target_path: NodePath
@export var release_velocity := Vector3(0.0, -1.5, 0.0)

@export_category("Timing")
@export_range(0.05, 2.0, 0.05) var capture_duration := 0.2
@export_range(0.05, 3.0, 0.05) var funnel_duration := 0.45
@export_range(0.0, 2.0, 0.05) var cooldown := 0.35

@onready var capture_area: Area3D = $CaptureArea
@onready var capture_point: Marker3D = $CapturePoint
@onready var throat_point: Marker3D = $ThroatPoint
@onready var default_drop_point: Marker3D = $DefaultDropPoint

var _busy := false


func _ready() -> void:
	capture_area.body_entered.connect(_on_capture_area_body_entered)


func _on_capture_area_body_entered(body: Node3D) -> void:
	if _busy or not body is Player:
		return
	_transport_player(body as Player)


func _transport_player(player: Player) -> void:
	_busy = true
	player_captured.emit(player)
	player.freeze = true
	player.sleeping = false
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		player,
		"global_position",
		capture_point.global_position,
		capture_duration
	)
	tween.tween_property(
		player,
		"global_position",
		throat_point.global_position,
		funnel_duration
	)
	await tween.finished

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


func _get_drop_target() -> Node3D:
	if not drop_target_path.is_empty():
		var target := get_node_or_null(drop_target_path) as Node3D
		if target:
			return target
	return default_drop_point

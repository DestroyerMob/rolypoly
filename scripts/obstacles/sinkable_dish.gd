class_name SinkableDish
extends AnimatableBody3D

signal started_sinking(player: Player)
signal started_floating

@export_category("Sink Motion")
@export var active := true
@export_range(0.05, 2.0, 0.05) var sink_depth := 1.05
@export_range(0.05, 3.0, 0.05) var sink_speed := 0.36
@export_range(0.05, 4.0, 0.05) var return_speed := 0.78

@export_category("Idle Float")
@export_range(0.0, 0.15, 0.005) var bob_height := 0.025
@export_range(0.1, 5.0, 0.1) var bob_speed := 1.35
@export_range(-180.0, 180.0, 1.0) var phase_degrees := 0.0

@onready var player_sensor: Area3D = $PlayerSensor

var _rest_position := Vector3.ZERO
var _players: Array[Player] = []
var _elapsed := 0.0
var _was_pressed := false


func _ready() -> void:
	_rest_position = position
	_elapsed = deg_to_rad(phase_degrees) / TAU * (TAU / maxf(bob_speed, 0.001))
	player_sensor.body_entered.connect(_on_body_entered)
	player_sensor.body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if not active:
		return

	_prune_players()
	_elapsed += delta
	var pressed := not _players.is_empty()
	var target_y := _rest_position.y - sink_depth if pressed else (
		_rest_position.y + sin(_elapsed * bob_speed) * bob_height
	)
	var motion_speed := sink_speed if pressed else return_speed
	position = Vector3(
		_rest_position.x,
		move_toward(position.y, target_y, motion_speed * delta),
		_rest_position.z
	)

	if _was_pressed and not pressed:
		started_floating.emit()
	_was_pressed = pressed


func reset_immediately() -> void:
	_players.clear()
	position = _rest_position
	_was_pressed = false
	reset_physics_interpolation()


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or _players.has(player):
		return
	_players.append(player)
	if _players.size() == 1:
		started_sinking.emit(player)


func _on_body_exited(body: Node3D) -> void:
	var player := body as Player
	if player:
		_players.erase(player)


func _prune_players() -> void:
	for index in range(_players.size() - 1, -1, -1):
		if not is_instance_valid(_players[index]):
			_players.remove_at(index)

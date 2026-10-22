class_name MasherObstacle
extends Node3D

enum State {
	WAITING,
	DROPPING,
	HOLDING,
	RISING,
	IDLE,
}

@export_category("Movement")
@export var active := true
@export var auto_cycle := true
@export_range(0.1, 10.0, 0.1) var raised_height := 3.0
@export_range(0.0, 2.0, 0.05) var lowered_height := 0.0
@export_range(0.1, 20.0, 0.1) var drop_speed := 5.5
@export_range(0.1, 20.0, 0.1) var rise_speed := 2.5
@export_range(0.0, 10.0, 0.1) var wait_time := 1.5
@export_range(0.0, 5.0, 0.05) var hold_time := 0.45

@export_category("Squish")
@export_range(0.05, 1.0, 0.05) var squish_duration := 0.18
@export_range(0.0, 3.0, 0.05) var respawn_delay := 0.55

@onready var moving_part: AnimatableBody3D = $MovingPart
@onready var squish_zone: Area3D = $MovingPart/SquishZone

var _state := State.WAITING
var _state_time := 0.0
var _has_squished_player := false


func _ready() -> void:
	moving_part.position.y = raised_height
	moving_part.reset_physics_interpolation()
	_state_time = wait_time
	_state = State.WAITING if auto_cycle else State.IDLE
	squish_zone.body_entered.connect(_on_squish_zone_body_entered)


func _physics_process(delta: float) -> void:
	if not active:
		return

	match _state:
		State.WAITING:
			_state_time -= delta
			if _state_time <= 0.0:
				_begin_drop()
		State.DROPPING:
			moving_part.position.y = move_toward(
				moving_part.position.y,
				lowered_height,
				drop_speed * delta
			)
			if is_equal_approx(moving_part.position.y, lowered_height):
				_squish_overlapping_players()
				_state = State.HOLDING
				_state_time = hold_time
		State.HOLDING:
			_state_time -= delta
			if _state_time <= 0.0:
				_state = State.RISING
		State.RISING:
			moving_part.position.y = move_toward(
				moving_part.position.y,
				raised_height,
				rise_speed * delta
			)
			if is_equal_approx(moving_part.position.y, raised_height):
				_has_squished_player = false
				if auto_cycle:
					_state = State.WAITING
					_state_time = wait_time
				else:
					_state = State.IDLE
		State.IDLE:
			pass


func trigger() -> void:
	if active and _state in [State.IDLE, State.WAITING]:
		_begin_drop()


func reset_immediately() -> void:
	_state = State.WAITING if auto_cycle else State.IDLE
	_state_time = wait_time
	_has_squished_player = false
	moving_part.position.y = raised_height


func _begin_drop() -> void:
	_has_squished_player = false
	_state = State.DROPPING


func _on_squish_zone_body_entered(body: Node3D) -> void:
	if _state == State.DROPPING:
		_squish_body(body)


func _squish_overlapping_players() -> void:
	for body in squish_zone.get_overlapping_bodies():
		_squish_body(body)


func _squish_body(body: Node3D) -> void:
	if _has_squished_player or not body.has_method("squish_and_respawn"):
		return

	_has_squished_player = true
	body.call_deferred("squish_and_respawn", squish_duration, respawn_delay)

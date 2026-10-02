extends Node3D

@export_range(0.0, 5.0, 0.1) var drop_delay := 2.0

@onready var weight: RigidBody3D = $HeavyWeight

var _elapsed := 0.0
var _dropped := false
var _log_elapsed := 0.0
var _log_motion := false


func _ready() -> void:
	$Camera3D.look_at(Vector3(0, 1, 0))
	_log_motion = OS.get_cmdline_user_args().has("--log-spoon-physics")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset_run"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		_drop_weight()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _dropped and _elapsed >= drop_delay:
		_drop_weight()
	if _log_motion:
		_log_elapsed += delta
		if _log_elapsed >= 0.1:
			_log_elapsed = 0.0
			print("t=%.2f spoon=%.2f player=%s velocity=%s weight=%s" % [
				_elapsed, $WoodenSpoon.rotation_degrees.z,
				$Player.position, $Player.linear_velocity, weight.position])


func _drop_weight() -> void:
	if _dropped:
		return
	_dropped = true
	weight.freeze = false
	weight.sleeping = false

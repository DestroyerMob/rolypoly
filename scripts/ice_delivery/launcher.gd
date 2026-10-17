extends Node3D

## Fixed serving lane. The player times E against the moving target; no auto-aim.
@export var charge_seconds := 0.6
@export var flight_seconds := 1.05
var player: Player
var mouth: Node3D
var busy := false
var cooldown := 0.0
var ready_to_launch := false
var charge_elapsed := 0.0
var launch_window := false
var attempt_remaining := 0.0

func _physics_process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	if attempt_remaining > 0:
		attempt_remaining -= delta
		if attempt_remaining <= 0 and is_instance_valid(player) and not player.finished:
			player.reset_callback.call()
	if busy:
		charge_elapsed += delta
		$Model.scale.y = lerpf(1.0, .65, clampf(charge_elapsed / charge_seconds, 0, 1))
		if charge_elapsed >= charge_seconds:
			fire()
	else:
		$Model.scale.y = move_toward($Model.scale.y, 1.0, delta * 3)
	ready_to_launch = not busy and cooldown <= 0 and is_instance_valid(player) and not player.finished and $PickupArea.overlaps_body(player) and player.on_ground
	launch_window = false
	if is_instance_valid(mouth):
		var future_phase: float = (mouth.elapsed + charge_seconds + flight_seconds) * TAU / mouth.cycle_seconds
		launch_window = absf(sin(future_phase) * mouth.sweep_distance) < 1.6
	$Sign.text = "SERVING..." if busy else (("GREEN • E NOW!" if launch_window else "WAIT • MOUTH OUT OF LINE") if ready_to_launch else "TIMED SERVER\nGreen signal → press E")
	$Sign.modulate = Color("b6f4e3") if launch_window else Color("ffb393")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and ready_to_launch:
		launch()
		get_viewport().set_input_as_handled()

func launch() -> void:
	if not ready_to_launch or busy:
		return
	busy = true
	charge_elapsed = 0.0
	player.freeze = true

func cancel() -> void:
	if busy and is_instance_valid(player):
		player.freeze = false
	busy = false
	charge_elapsed = 0.0
	attempt_remaining = 0.0
	$Model.scale = Vector3.ONE

func fire() -> void:
	if not is_instance_valid(player) or player.finished:
		busy = false
		return
	var start: Vector3 = player.global_position + Vector3.UP * .2
	var target: Vector3 = mouth.get_parent().to_global(mouth.home)
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * player.gravity_scale
	var velocity := (target - start) / flight_seconds + Vector3.UP * gravity * flight_seconds * .5
	player.freeze = false
	player.flight_remaining = flight_seconds + .6
	player.teleport_to(Transform3D(Basis.IDENTITY, start), velocity)
	cooldown = 2.0
	attempt_remaining = 3.0
	busy = false

extends Node3D

## One short burst per airtime. Landing restores the charge.
@export_range(0.05, 2.0, 0.05) var burst_duration := 0.45
## Upward acceleration while firing, independent of character mass.
@export_range(1.0, 100.0, 1.0) var thrust_acceleration := 48.0
@export_range(1.0, 30.0, 0.5) var max_boost_rise_speed := 12.0

@onready var spray: GPUParticles3D = $CreamSpray

var _charged := true
var _burst_remaining := 0.0
var _player: Player


func air_jump(player: Player) -> void:
	if not _charged or player.on_ground or player.is_squished or player.freeze:
		return
	_player = player
	_charged = false
	_burst_remaining = burst_duration
	spray.emitting = true
	player.sleeping = false


func integrate_equipment_forces(player: Player, state: PhysicsDirectBodyState3D) -> void:
	if player.is_squished or player.freeze:
		_stop_burst()
		return
	if player.on_ground:
		_charged = true
		_stop_burst()
		return
	if _burst_remaining <= 0.0:
		return
	var thrust_time := minf(state.step, _burst_remaining)
	var velocity := state.linear_velocity
	# Cap only the speed this equipment adds; preserve faster external launches.
	if velocity.y < max_boost_rise_speed:
		velocity.y = minf(velocity.y + thrust_acceleration * thrust_time, max_boost_rise_speed)
		state.linear_velocity = velocity
	_burst_remaining = maxf(0.0, _burst_remaining - thrust_time)
	if _burst_remaining <= 0.0:
		_stop_burst()


func update_attachment(player: Player, mount: GadgetMount) -> void:
	if player != _player:
		_stop_burst()
		_player = player
	if player.is_squished or player.freeze:
		_stop_burst()
	# Keep the nozzle pointing down even when the camera pitches or body rolls.
	var right := Vector3(mount.global_basis.x.x, 0, mount.global_basis.x.z).normalized()
	global_basis = Basis(right, Vector3.UP, right.cross(Vector3.UP))
	global_position = mount.global_position + global_basis * mount.model_offset


func reset_equipment() -> void:
	_charged = true
	_stop_burst()
	# Clear the old world-space spray when the player respawns or teleports.
	spray.restart()
	spray.emitting = false


func _stop_burst() -> void:
	_burst_remaining = 0.0
	spray.emitting = false

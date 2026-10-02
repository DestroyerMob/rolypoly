extends Node3D

## Maximum downward speed while airborne; upward jump velocity is unchanged.
@export_range(0.1, 30.0, 0.1) var max_fall_speed := 5.0
## Height of the open umbrella's handle above the player's center.
@export var overhead_height := 2.5

@onready var closed_model: Node3D = $Closed
@onready var open_model: Node3D = $Open


func update_attachment(player: Player, mount: GadgetMount) -> void:
	var airborne := not player.on_ground and not player.is_squished
	closed_model.visible = not airborne
	open_model.visible = airborne
	# Stay upright as the camera pitches and the player rolls.
	var right := Vector3(mount.global_basis.x.x, 0, mount.global_basis.x.z).normalized()
	global_basis = Basis(right, Vector3.UP, right.cross(Vector3.UP))
	if airborne:
		global_position = player.global_position + Vector3.UP * overhead_height
	else:
		global_position = mount.global_position + global_basis * mount.model_offset


func integrate_equipment_forces(player: Player, state: PhysicsDirectBodyState3D) -> void:
	if player.on_ground or player.is_squished:
		return
	var velocity := state.linear_velocity
	velocity.y = maxf(velocity.y, -max_fall_speed)
	state.linear_velocity = velocity

extends "res://scripts/ice_cube.gd"

## Level adapter for Ethan's equipment. Amount controls shell THICKNESS, not
## the diameter of the edible core. A half-full shell cannot hide inside it.
var charging := false

func _ready() -> void:
	$Model.material_override = $Model.material_override.duplicate()
	$Model.material_override.shader = preload("res://scripts/ice_delivery/shell.gdshader")

func amount() -> float:
	return 1.0 - _melt_progress

func set_amount(value: float) -> void:
	_melt_progress = 1.0 - clampf(value, 0.001, 1.0)
	_update_ice_geometry()

func _physics_process(delta: float) -> void:
	if charging:
		_droplets.emitting = false
		_mist.emitting = false
		return
	super._physics_process(delta)

func _update_ice_geometry() -> void:
	if not is_instance_valid(_player) or _ice_shape == null:
		return
	var core_side := _side / size_multiplier
	var visual_side := lerpf(core_side + 0.12, _side, amount())
	# Stable collision avoids lifting / popping the player while charging.
	_ice_shape.size = Vector3.ONE * core_side
	_player.spawn_clearance = core_side * 0.5 - _player.collider.position.y
	$Model.scale = Vector3.ONE * visual_side / 64.0
	$Model.position.y = -visual_side * 0.5
	$Model.material_override.set_shader_parameter("melt_progress", _melt_progress)
	_droplet_material.emission_box_extents = Vector3(visual_side * .5, .1, visual_side * .5)
	_mist_material.emission_box_extents = Vector3(visual_side * .5, .05, visual_side * .5)
	_droplets.position.y = -core_side * .4
	_mist.position.y = -core_side * .1

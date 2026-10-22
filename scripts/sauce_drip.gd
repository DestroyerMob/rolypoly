class_name SauceDrip
extends Node3D

## Sauce dripping from this node down onto the floor below it. Place the node at the height the
## sauce falls from; the floor is the origin of the parent, so the drops land on the puddle.

@export var colour := Color(0.24, 0.11, 0.05)
@export_range(0.2, 20.0, 0.1) var drops_per_second := 3.0
## Droplet size in world units.
@export_range(0.1, 5.0, 0.05) var drop_size := 0.6
@export_range(50.0, 1000.0, 10.0) var gravity := 250.0
@export var show_nozzle := true


func _ready() -> void:
	var height := maxf(global_position.y - get_parent_node_3d().global_position.y, 1.0)
	var fall_time := sqrt(2.0 * height / gravity)
	_add_drops(height, fall_time)
	_add_splash(height)
	if show_nozzle:
		_add_nozzle()


func _material(glossy := true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.1 if glossy else 0.5
	return material


func _add_drops(height: float, fall_time: float) -> void:
	var drop := SphereMesh.new()
	drop.radius = drop_size * 0.5
	drop.height = drop_size * 1.5
	drop.radial_segments = 10
	drop.rings = 6
	drop.material = _material()

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.direction = Vector3.DOWN
	process.spread = 0.0
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.0
	process.gravity = Vector3(0.0, -gravity, 0.0)
	process.scale_min = 0.8
	process.scale_max = 1.2

	var particles := GPUParticles3D.new()
	particles.name = "Drops"
	particles.process_material = process
	particles.draw_pass_1 = drop
	particles.lifetime = fall_time
	particles.amount = maxi(1, ceili(drops_per_second * fall_time))
	particles.explosiveness = 0.0
	particles.randomness = 0.4
	particles.visibility_aabb = AABB(Vector3(-6.0, -height - 6.0, -6.0), Vector3(12.0, height + 12.0, 12.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)


## A small spatter where each drop lands.
func _add_splash(height: float) -> void:
	var bit := SphereMesh.new()
	bit.radius = drop_size * 0.22
	bit.height = drop_size * 0.44
	bit.radial_segments = 6
	bit.rings = 3
	bit.material = _material()

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 55.0
	process.initial_velocity_min = drop_size * 6.0
	process.initial_velocity_max = drop_size * 14.0
	process.gravity = Vector3(0.0, -gravity * 0.5, 0.0)

	var particles := GPUParticles3D.new()
	particles.name = "Splash"
	particles.position = Vector3(0.0, -height + 0.5, 0.0)
	particles.process_material = process
	particles.draw_pass_1 = bit
	particles.lifetime = 0.4
	particles.amount = maxi(2, ceili(drops_per_second * 0.4 * 4.0))
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	particles.visibility_aabb = AABB(Vector3(-8.0, -3.0, -8.0), Vector3(16.0, 10.0, 16.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)


func _add_nozzle() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = drop_size * 1.6
	cone.bottom_radius = drop_size * 0.7
	cone.height = drop_size * 3.0
	cone.material = _material(false)
	var nozzle := MeshInstance3D.new()
	nozzle.name = "Nozzle"
	nozzle.mesh = cone
	nozzle.position = Vector3(0.0, drop_size * 1.5, 0.0)
	add_child(nozzle)

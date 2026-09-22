extends RigidBody3D

const DEATH_PARTICLES := preload("res://packed_scenes/produce_death_particles.tscn")

@export var particle_color := Color(0.85, 0.3, 0.1)
@export var lifetime := 8.0

var _dead := false


func _ready() -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = lifetime
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()


func burst(outlet_transform: Transform3D) -> void:
	if _dead:
		return
	_dead = true
	var particles := DEATH_PARTICLES.instantiate() as GPUParticles3D
	var material := particles.process_material.duplicate() as ParticleProcessMaterial
	material.color = particle_color
	particles.process_material = material
	get_tree().current_scene.add_child(particles)
	particles.global_transform = outlet_transform.orthonormalized()
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
	queue_free()

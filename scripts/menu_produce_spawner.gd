extends Marker3D

const PRODUCE_BODY := preload("res://scripts/produce_body.gd")

@export var models: Array[PackedScene] = []
@export var particle_colors: Array[Color] = [Color(0.75, 0.4, 0.08), Color(0.9, 0.06, 0.03), Color(0.6, 0.8, 0.3)]
@export_range(0.2, 10.0, 0.1) var spawn_interval := 3.0
@export_range(0.1, 1.0, 0.05) var size_multiplier := 0.4
@export var lifetime := 8.0


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = spawn_interval
	timer.timeout.connect(spawn)
	add_child(timer)
	timer.start()
	spawn()


func spawn() -> void:
	if models.is_empty():
		return
	var model_index := randi_range(0, models.size() - 1)
	var body := models[model_index].instantiate() as RigidBody3D
	# Reuse the player artwork as a prop, without input or respawning.
	body.set_script(PRODUCE_BODY)
	if model_index < particle_colors.size():
		body.set("particle_color", particle_colors[model_index])
	body.set("lifetime", lifetime)
	body.gravity_scale = 1.0
	body.continuous_cd = true
	body.linear_damp = 0.05
	body.angular_damp = 0.05
	var collider := body.get_node("CollisionShape3D") as CollisionShape3D
	# Scale the collider node rather than its shape resource: this works for any
	# shape type (sphere, capsule, convex) and shrinks the artwork parented under it too.
	collider.scale *= size_multiplier
	collider.position *= size_multiplier
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.0
	body.physics_material_override = material
	add_child(body)
	body.global_transform = global_transform.orthonormalized()

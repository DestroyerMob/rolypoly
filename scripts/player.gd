class_name Player
extends RigidBody3D

@export var speed_force := 20.0
@onready var collider := $CollisionShape3D

var on_ground := false
var spawn_position: Vector3

func _ready() -> void:
	spawn_position = global_position
	contact_monitor = true
	max_contacts_reported = 8

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	on_ground = has_ground_contact(state)

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump()
	move(Input.get_vector("left", "right", "forward", "backward"))

func set_active(active: bool) -> void:
	freeze = not active
	set_physics_process(active)
	visible = active
	if active:
		sleeping = false

func respawn(world_position: Vector3) -> void:
	spawn_position = world_position
	var was_frozen := freeze
	freeze = true
	global_transform = Transform3D(Basis.IDENTITY, world_position)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	on_ground = false
	freeze = was_frozen
	sleeping = false

func move(input: Vector2) -> void:
	apply_central_force(Vector3(input.x, 0.0, input.y) * speed_force)

func jump() -> void:
	if not on_ground:
		return
	apply_central_impulse(Vector3.UP * 7.0)
	on_ground = false

func has_ground_contact(state: PhysicsDirectBodyState3D) -> bool:
	for i in range(state.get_contact_count()):
		if state.get_contact_local_normal(i).dot(Vector3.UP) > 0.5:
			return true
	return false

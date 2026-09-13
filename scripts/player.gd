class_name Player
extends RigidBody3D

@export var speed_force := 20.0
@onready var collider := $CollisionShape3D

var on_ground := false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	on_ground = false
	for i in range(state.get_contact_count()):
		if state.get_contact_collider_object(i) is TileShape:
			if state.get_contact_local_normal(i).dot(Vector3.UP) > 0.5:
				on_ground = true
				break

func _physics_process(delta: float) -> void:
	var input := Input.get_vector(
		"left", "right", "forward", "backward"
	)
	
	if Input.is_action_just_pressed("jump") and on_ground:
		apply_central_impulse(Vector3.UP * 7.0)
		on_ground = false
	
	var direction := Vector3(input.x, 0.0, input.y)
	
	apply_central_force(direction * speed_force)
	
	

class_name Player
extends RigidBody3D

@export var speed_force := 20.0

func _physics_process(delta: float) -> void:
	var input := Input.get_vector(
		"left", "right", "forward", "backward"
	)
	
	if Input.is_action_just_pressed("jump"):
		apply_central_impulse(Vector3.UP * 7.0)
	
	var direction := Vector3(input.x, 0.0, input.y)
	
	apply_central_force(direction * speed_force)

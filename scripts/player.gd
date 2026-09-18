class_name Player
extends RigidBody3D

signal squished

@export var speed_force := 20.0
@onready var collider := $CollisionShape3D
@onready var visual := $CollisionShape3D/MeshInstance3D

var on_ground := false
var is_squished := false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8

func _physics_process(delta: float) -> void:
	if is_squished:
		return

	var input := Input.get_vector(
		"left", "right", "forward", "backward"
	)
	
	on_ground = get_colliding_bodies().size() > 0
	
	if Input.is_action_just_pressed("jump") and on_ground:
		apply_central_impulse(Vector3.UP * 7.0)
	
	var direction := Vector3(input.x, 0.0, input.y)
	
	apply_central_force(direction * speed_force)


func squish_and_respawn(squish_duration := 0.18, respawn_delay := 0.55) -> void:
	if is_squished:
		return

	is_squished = true
	squished.emit()
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	if is_instance_valid(visual):
		var original_scale: Vector3 = visual.scale
		var squashed_scale := Vector3(
			original_scale.x * 1.55,
			original_scale.y * 0.18,
			original_scale.z * 1.55
		)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual, "scale", squashed_scale, squish_duration)
		await tween.finished

	await get_tree().create_timer(respawn_delay).timeout
	get_tree().reload_current_scene()

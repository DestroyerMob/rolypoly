class_name Player
extends RigidBody3D

signal squished

@export var speed_force := 20.0
@export var jump_impulse := 9.5
@onready var collider := $CollisionShape3D
@onready var visual := $CollisionShape3D/MeshInstance3D

var on_ground := false
var _teleport_target: Transform3D
var _teleport_queued := false
## Distance from this character's origin down to its lowest point.
## Ball 0.25, egg and corn will be different. Each character scene sets its own.
@export var spawn_clearance := 0.25
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
		apply_central_impulse(Vector3.UP * jump_impulse)
	
	var direction := Vector3(input.x, 0.0, input.y)
	
	apply_central_force(direction * speed_force)
	
#DEV 
#func _switch_character:
	
#func restart_level()
#func reset_to_spawn()
# --- TEMPORARY: belongs to the level, lives here until there are two callers ---

func _find_spawn() -> PlayerStart:
	return get_tree().get_first_node_in_group(&"player_start") as PlayerStart


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset_run"):
		reset_to_spawn()
	#elif event.is_action_pressed(&"restart_level"):
		#restart_level()

## Soft reset. Back to the spawn, level untouched.
func reset_to_spawn() -> void:
	var start := _find_spawn()
	if start == null:
		push_warning("Player: no PlayerStart in this scene, reset did nothing.")
		return

	var target := start.get_spawn_transform()
	target.origin += Vector3.UP * spawn_clearance   # the character adjusts for its own shape
	teleport_to(target)

## Hard reset. Rebuild the whole level scene.
func restart_level() -> void:
	get_tree().reload_current_scene()
	
# --- stays here forever ------------------------------------------------------

## The only safe way to move a rigid body. Records the request;
## the physics step fulfils it.
func teleport_to(target: Transform3D) -> void:
	_teleport_target = target
	_teleport_queued = true
	sleeping = false   # a resting body stops receiving _integrate_forces


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

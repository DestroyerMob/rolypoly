class_name Player
extends RigidBody3D

@export var speed_force := 20.0
@onready var collider := $CollisionShape3D

var on_ground := false
var _teleport_target: Transform3D
var _teleport_queued := false
## Distance from this character's origin down to its lowest point.
## Ball 0.25, egg and corn will be different. Each character scene sets its own.
@export var spawn_clearance := 0.25

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8

func _physics_process(delta: float) -> void:
	var input := Input.get_vector(
		"left", "right", "forward", "backward"
	)
	
	on_ground = get_colliding_bodies().size() > 0
	
	if Input.is_action_just_pressed("jump") and on_ground:
		apply_central_impulse(Vector3.UP * 7.0)
	
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

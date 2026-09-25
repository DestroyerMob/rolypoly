class_name Player
extends RigidBody3D

signal squished

#ENUMS FOR PLAYER STATE CONDITIONS
## Highest Priority first 
enum Condition {NORMAL,DIZZY,HURT,DEAD,WIN}
const PRIORITY := [Condition.WIN, Condition.DEAD, Condition.HURT, Condition.DIZZY, Condition.NORMAL]
signal condition_changed(new_condition: Condition)

@export var speed_force := 20.0  #  
@export var jump_impulse := 9.5 # Instantaneous velocity in upwards direction
@onready var collider := $CollisionShape3D
@onready var visual := $CollisionShape3D/MeshInstance3D
@onready var original_visual_scale: Vector3 = visual.scale

var on_ground := false
var _teleport_target: Transform3D
var _teleport_queued := false
var _active_conditions: Array[Condition] = [] #We have to enforce uniqueness ourselves
## Distance from this character's origin down to its lowest point.
## Ball 0.25, egg and corn will be different. Each character scene sets its own.
@export var spawn_clearance := 0.25
var spawn_position: Vector3
var is_squished := false
var squish_tween: Tween

func _ready() -> void:
	spawn_position = global_position
	contact_monitor = true
	max_contacts_reported = 8

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	on_ground = has_ground_contact(state)

func _physics_process(_delta: float) -> void:
	if is_squished:
		return
	if Input.is_action_just_pressed("jump"):
		jump()
	move(Input.get_vector("left", "right", "forward", "backward"))

#VFX

func enter_condition(condition: Condition)-> void:
	if not _active_conditions.has(condition): #Unless the condition is already in our array (enforce uniqueness)
		_active_conditions.append(condition) #append the condition to the array
	_resolve_condition()

func exit_condition(condition: Condition)-> void:
	_active_conditions.erase(condition)
	_resolve_condition()

func _resolve_condition() -> void:
	for condition in PRIORITY:
		if _active_conditions.has(condition):
			condition_changed.emit(condition)
			return 
	condition_changed.emit(Condition.NORMAL)
	
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
	if event.is_action_pressed(&"debug_probe"):
		_probe_colliders()
		
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
func set_active(active: bool) -> void:
	freeze = not active or is_squished
	set_physics_process(active)
	visible = active
	if active:
		sleeping = false

func respawn(world_position: Vector3) -> void:
	spawn_position = world_position
	var was_frozen := freeze
	if is_squished:
		was_frozen = not is_physics_processing()
		is_squished = false
		if squish_tween:
			squish_tween.kill()
		if is_instance_valid(visual):
			visual.scale = original_visual_scale
	freeze = true
	global_transform = Transform3D(Basis.IDENTITY, world_position)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	on_ground = false
	freeze = was_frozen
	sleeping = false

#Iroh Temporarily Supersede to test Orbital Camera with Slight Movement

#func move(input: Vector2) -> void: #5:15pm 22nd September 2026 Orbital Camera Work
	#apply_central_force(Vector3(input.x, 0.0, input.y) * speed_force)
	
func move(input: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	var wish := Vector3(input.x, 0.0, input.y)

	if camera == null:
		apply_central_force(wish * speed_force)
		return

	var direction := camera.global_basis * wish
	direction.y = 0.0
	direction = direction.normalized() * wish.length()

	apply_central_force(direction * speed_force)
	
func jump() -> void:
	if not on_ground:
		return
	apply_central_impulse(Vector3.UP * jump_impulse)
	on_ground = false

func has_ground_contact(state: PhysicsDirectBodyState3D) -> bool:
	for i in range(state.get_contact_count()):
		if state.get_contact_local_normal(i).dot(Vector3.UP) > 0.5:
			return true
	return false

func squish_and_respawn(squish_duration := 0.18, respawn_delay := 0.55) -> void:
	if is_squished or not is_physics_processing():
		return

	is_squished = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	squish_tween = create_tween()
	if is_instance_valid(visual):
		var squashed_scale := Vector3(
			original_visual_scale.x * 1.55,
			original_visual_scale.y * 0.18,
			original_visual_scale.z * 1.55
		)
		squish_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		squish_tween.tween_property(visual, "scale", squashed_scale, squish_duration)

	# Reuse respawn so the builder keeps its placed tiles and spawn flag.
	squish_tween.tween_interval(respawn_delay)
	squish_tween.tween_callback(respawn.bind(spawn_position))
	squished.emit()
	
## Dev tool. Asks the physics server what overlaps the marble right now and
## prints each hit's full node path. The blue debug outlines tell you a shape
## exists. This tells you which node owns it.
func _probe_colliders() -> void:
	#Job 1: Build a sphere a bit larger than the marble, as the thing trapping
	#       you is something you are INSIDE, and a touch test would miss it.
	var shape := SphereShape3D.new()
	shape.radius = 8.0

	#Job 2: Describe the query. Areas included, as a stray Area3D can block
	#       nothing and still be the thing you are trying to identify.
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = global_transform
	params.collide_with_bodies = true
	params.collide_with_areas = true
	#Job 3: Exclude ourselves, or the marble is always the first result.
	params.exclude = [get_rid()]

	var hits := get_world_3d().direct_space_state.intersect_shape(params, 32)
	print("--- overlapping at %s ---" % global_position)
	for hit in hits:
		var node := hit.collider as Node
		print("  %s  [%s]" % [node.get_path(), node.get_class()])

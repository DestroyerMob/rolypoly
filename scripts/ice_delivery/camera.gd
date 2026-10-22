extends "res://scripts/ice/ice_camera.gd"

var route_yaw := 0.0
var turn_remaining := 0.0
var survey := false
var focus := Vector3.ZERO
var initialized := false
const CONTROL_HINT := "WASD move · Space jump · R checkpoint\nArrows look · C recenter · V overview\nTab free camera · E spring server"

func _ready() -> void:
	pitch = deg_to_rad(-30.0)
	super._ready()

func turn_towards(value: float) -> void:
	route_yaw = value
	turn_remaining = 1.4

func _process(delta: float) -> void:
	if not free_mode:
		if Input.get_axis("ice_look_right", "ice_look_left") != 0:
			turn_remaining = 0.0
		if turn_remaining > 0:
			yaw = lerp_angle(yaw, route_yaw, 1.0 - exp(-4.0 * delta))
			turn_remaining -= delta
	super._process(delta)

func _follow() -> void:
	var desired_focus: Vector3 = player.global_position + Vector3.UP * 1.2
	if not initialized or focus.distance_to(desired_focus) > 35:
		focus = desired_focus
		initialized = true
	else:
		focus = focus.lerp(desired_focus, 1.0 - exp(-9.0 * get_process_delta_time()))
	rotation = Vector3(deg_to_rad(-48) if survey else pitch, yaw, 0)
	var desired := focus + global_basis.z * follow_distance * (1.65 if survey else 1.0)
	# Same principle as the team's spring arm: keep walls out of the view.
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	global_position = hit.position + hit.normal * .8 if not hit.is_empty() else desired

func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventKey and event.pressed and not event.echo and not free_mode:
		if event.physical_keycode == KEY_C:
			pitch = deg_to_rad(-30)
			turn_towards(route_yaw)
		elif event.physical_keycode == KEY_V:
			survey = not survey

func toggle_free() -> void:
	super.toggle_free()
	if not free_mode:
		get_node("../HUD/Margin/Panel/Rows/Controls").text = CONTROL_HINT

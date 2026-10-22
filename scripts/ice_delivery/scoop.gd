extends Player

signal melted
## Three health segments belong to the scoop, NOT to the refillable ice shell.
@export_range(5.0, 180.0) var naked_melt_seconds := 24.0
@export var maximum_speed := 12.0
var core_health := 3.0
var finished := false
var reset_callback: Callable
var cooling := false
var flight_remaining := 0.0

func _physics_process(delta: float) -> void:
	if finished or is_squished:
		return
	flight_remaining = maxf(0.0, flight_remaining - delta)
	if flight_remaining <= 0.0 and not freeze:
		move(Input.get_vector("ice_left", "ice_right", "ice_forward", "ice_backward"))
	if Input.is_action_just_pressed("jump") and flight_remaining <= 0.0 and not freeze:
		jump()
	var planar := Vector2(linear_velocity.x, linear_velocity.z)
	if planar.length() > maximum_speed and flight_remaining <= 0.0:
		planar = planar.normalized() * maximum_speed
		linear_velocity.x = planar.x
		linear_velocity.z = planar.y
	if not is_instance_valid(gadget) and not cooling:
		var rate := 3.0 / naked_melt_seconds
		for body in get_colliding_bodies():
			if body.has_method("get_ice_melt_rate"):
				rate = maxf(rate, body.get_ice_melt_rate() * 3.0)
		core_health = maxf(0.0, core_health - rate * delta)
	# Keep the collision stable; only the scoop's edible visual melts away.
	visual.scale = original_visual_scale * lerpf(0.55, 1.0, core_health / 3.0)
	if core_health <= 0.0:
		finished = true
		freeze = true
		melted.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		if reset_callback.is_valid():
			reset_callback.call()

func squish_and_respawn(squish_duration := 0.2, respawn_delay := 0.55) -> void:
	if is_squished or finished or flight_remaining > 0.0:
		return
	is_squished = true
	freeze = true
	var tween := create_tween()
	tween.tween_property(visual, "scale:y", original_visual_scale.y * .15, squish_duration)
	await get_tree().create_timer(squish_duration + respawn_delay).timeout
	if finished:
		return
	is_squished = false
	freeze = false
	if reset_callback.is_valid():
		reset_callback.call()

func star_count() -> int:
	if core_health <= 0.0:
		return 0
	return clampi(ceili(core_health - 0.00001), 1, 3)

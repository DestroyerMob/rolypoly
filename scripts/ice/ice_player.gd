extends "res://scripts/player.gd"

signal ice_changed(amount: float)
signal restarted(reason: String)
signal finished

@export var melt_per_second := 0.22
@export var hot_melt_per_second := 5.0
@export var refill_per_second := 40.0
@export var maximum_radius := 0.60
@export var minimum_radius := 0.30
var ice_amount := 100.0
var zones: Array[Area3D] = []
var checkpoint := Vector3.ZERO
var won := false
var status := "FOLLOW THE FROST TRAIL"
var _pending_reset := false
var _reset_target := Vector3.ZERO
var _shape_clock := 0.0
var _reason := ""

func _ready() -> void:
	preload("res://scripts/ice/ice_controls.gd").setup()
	super._ready()
	checkpoint = global_position
	collider.shape = collider.shape.duplicate()

func _physics_process(delta: float) -> void:
	if won:
		return
	var heat := false
	var cooling := false
	status = "ICE MELTS OVER TIME"
	for i in range(zones.size() - 1, -1, -1):
		if not is_instance_valid(zones[i]):
			zones.remove_at(i)
			continue
		var zone = zones[i]
		if zone.kind == 0:
			heat = true
		elif zone.kind == 1:
			cooling = true
		elif zone.kind == 2 or zone.kind == 3:
			var gust: float = zone.strength * zone.gust_factor()
			# A thick ice coat catches more air; a nearly melted core is easier to control.
			apply_central_force(zone.global_basis * zone.direction * gust * lerpf(0.45, 1.0, ice_amount / 100.0))
			status = "STEAM LIFT: RIDE THE PULSE" if zone.kind == 3 else "CROSSWIND: STEER INTO THE WIND"
	if cooling:
		ice_amount = minf(100.0, ice_amount + refill_per_second * delta)
		status = "COOLING / CHECKPOINT SAVED"
	else:
		ice_amount = maxf(0.0, ice_amount - (hot_melt_per_second if heat else melt_per_second) * delta)
		if heat:
			status = "HOT SURFACE! KEEP MOVING"
	_shape_clock += delta
	if _shape_clock >= 0.1:
		_shape_clock = 0.0
		var radius := lerpf(minimum_radius, maximum_radius, ice_amount / 100.0)
		collider.shape.radius = radius
		visual.scale = Vector3.ONE * radius / maximum_radius
	ice_changed.emit(ice_amount)
	if global_position.y < -2.0 or ice_amount <= 0.0:
		request_reset("FELL OFF THE COUNTER" if ice_amount > 0.0 else "MELTED — TRY A COOLER ROUTE")
	if Input.is_action_just_pressed("jump"):
		jump()
	move(Input.get_vector("ice_left", "ice_right", "ice_forward", "ice_backward"))
	# Keep kitchen-scale movement readable while preserving momentum.
	var horizontal := Vector2(linear_velocity.x, linear_velocity.z)
	if horizontal.length() > 7.2:
		horizontal = horizontal.limit_length(7.2)
		linear_velocity.x = horizontal.x
		linear_velocity.z = horizontal.y

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	super._integrate_forces(state)
	if _pending_reset:
		state.transform = Transform3D(Basis.IDENTITY, _reset_target)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_pending_reset = false
		reset_physics_interpolation()

func request_reset(reason: String) -> void:
	ice_amount = 100.0
	_reset_target = checkpoint
	won = false
	freeze = false
	sleeping = false
	_pending_reset = true
	_reason = reason
	restarted.emit(reason)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_run"):
		if won:
			get_tree().reload_current_scene()
		else:
			request_reset("BACK TO THE LAST COLD STATION")

func complete() -> void:
	if won:
		return
	won = true
	linear_velocity = Vector3.ZERO
	freeze = true
	status = "DESSERT SAVED"
	finished.emit()

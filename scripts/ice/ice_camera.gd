extends Camera3D

@export var follow_distance := 13.5
@export var orbit_speed_degrees := 70.0
@export var free_move_speed := 12.0
var free_mode := false
var yaw := 0.0
var pitch := deg_to_rad(-42.0)
var _previous_pause := false
@onready var player: Node3D = get_node("../Player")

func _ready() -> void:
	preload("res://scripts/ice/ice_controls.gd").setup()
	process_mode=Node.PROCESS_MODE_ALWAYS
	current=true
	_follow()

func _process(delta: float) -> void:
	var horizontal := Input.get_axis("ice_look_right","ice_look_left")
	var vertical := Input.get_axis("ice_look_down","ice_look_up")
	# Retain the previous X/Z pitch shortcuts too.
	vertical += float(Input.is_physical_key_pressed(KEY_Z)) - float(Input.is_physical_key_pressed(KEY_X))
	yaw += horizontal * deg_to_rad(orbit_speed_degrees) * delta
	pitch = clampf(pitch + vertical * deg_to_rad(orbit_speed_degrees) * delta,deg_to_rad(-85),deg_to_rad(85 if free_mode else -12))
	if free_mode:
		rotation=Vector3(pitch,yaw,0)
		var planar := Input.get_vector("ice_left","ice_right","ice_forward","ice_backward")
		var height := Input.get_axis("ice_camera_down","ice_camera_up")
		var direction := global_basis * Vector3(planar.x,0,planar.y) + Vector3.UP * height
		global_position += direction.limit_length() * free_move_speed * delta * (2.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	else:
		_follow()

func _follow() -> void:
	rotation=Vector3(pitch,yaw,0)
	global_position=player.global_position+global_basis.z*follow_distance

func _exit_tree() -> void:
	# Replay/scene changes must not leave the next scene paused.
	if free_mode:
		get_tree().paused=_previous_pause

func toggle_free() -> void:
	free_mode=not free_mode
	var state := get_node("../HUD/Margin/Panel/Rows/State") as Label
	var controls := get_node("../HUD/Margin/Panel/Rows/Controls") as Label
	if free_mode:
		_previous_pause=get_tree().paused
		get_tree().paused=true
		state.text="FREE CAMERA / GAME PAUSED"
		controls.text="WASD fly · Q / E down / up\nArrows look · Shift faster · Tab return"
	else:
		get_tree().paused=_previous_pause
		pitch=clampf(pitch,deg_to_rad(-80),deg_to_rad(-12))
		controls.text="WASD move · Space jump · R checkpoint\nArrows look · Tab free camera"
		_follow()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_TAB or event.keycode==KEY_TAB:
			toggle_free()
			get_viewport().set_input_as_handled()
		elif free_mode and (event.is_action_pressed("reset_run") or event.physical_keycode in [KEY_Q,KEY_E]):
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			pitch-=deg_to_rad(5)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			pitch+=deg_to_rad(5)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw-=event.relative.x*.004
		pitch-=event.relative.y*.004

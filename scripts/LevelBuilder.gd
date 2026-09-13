class_name LevelBuilder
extends Node3D

@export var Tile: PackedScene
@export var SurfaceMaterial: TileSurface
@export var build_height: float = 0.0
@export var camera_speed: float = 20.0

@onready var player: Player = $Player
@onready var camera: Camera3D = $Camera3D
var build_mode := true
var build_camera_transform: Transform3D
var play_camera_rotation: Vector3
var spawn_position: Vector3
var spawn_flag := Node3D.new()
var place_flag := false

func _ready() -> void:
	build_camera_transform = camera.global_transform
	play_camera_rotation = camera.global_rotation
	spawn_position = player.global_position
	add_child(spawn_flag)
	spawn_flag.hide()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE
	for size in [Vector3(0.08, 2, 0.08), Vector3(1, 0.6, 0.08)]:
		var part := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		part.mesh = mesh
		part.material_override = material
		part.position = Vector3(0, 1, 0) if size.x < 1 else Vector3(0.5, 1.7, 0)
		spawn_flag.add_child(part)
	set_build_mode(true)

func set_build_mode(enabled: bool) -> void:
	build_mode = enabled
	place_flag = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.freeze = true
	player.set_physics_process(not enabled)
	player.visible = not enabled
	camera.set_physics_process(not enabled)
	if enabled:
		camera.global_transform = build_camera_transform
	else:
		build_camera_transform = camera.global_transform
		player.global_transform = Transform3D(Basis.IDENTITY, spawn_position)
		player.linear_velocity = Vector3.ZERO
		player.angular_velocity = Vector3.ZERO
		player.on_ground = false
		player.freeze = false
		player.sleeping = false
		camera.global_rotation = play_camera_rotation
		camera.global_position = camera.start_position + spawn_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			set_build_mode(not build_mode)
		elif build_mode and event.physical_keycode == KEY_F:
			place_flag = true
	if not build_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.5, 1.5)

func _physics_process(delta: float) -> void:
	if not build_mode:
		return
	var movement := Input.get_vector("left", "right", "forward", "backward")
	var vertical := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	var direction := camera.global_basis * Vector3(movement.x, 0, movement.y) + Vector3.UP * vertical
	camera.global_position += direction.limit_length() * camera_speed * delta
	if place_flag:
		place_flag = false
		var flag_position: Variant = get_mouse_world_position(true)
		if flag_position != null:
			spawn_flag.global_position = flag_position + Vector3.UP * 4.0
			spawn_flag.show()
			spawn_position = spawn_flag.global_position + Vector3.UP
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	if (Input.is_action_just_pressed("build")):
		var placement: Variant = get_mouse_world_position()
		if placement == null:
			return
		var cell_position: Vector3 = placement.snapped(Vector3(8, 8, 8))
		for child in get_children():
			if child is TileShape and child.global_position.snapped(Vector3(8, 8, 8)) == cell_position:
				return
		var tile := Tile.instantiate() as TileShape
		tile.surface = SurfaceMaterial
		add_child(tile)
		tile.global_position = cell_position
		print_debug(tile.global_position)

func get_mouse_world_position(select_cell: bool = false) -> Variant:
	var camera := get_viewport().get_camera_3d()
	var mouse_pos := get_viewport().get_mouse_position()
	
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	while not hit.is_empty() and not hit.collider is TileShape:
		query.exclude += [hit.rid]
		hit = space.intersect_ray(query)
	if not hit.is_empty():
		if select_cell:
			return hit.collider.global_position.snapped(Vector3(8, 8, 8))
		var normal: Vector3 = hit.normal
		var axis := normal.abs().max_axis_index()
		var offset := Vector3.ZERO
		offset[axis] = signf(normal[axis]) * 8.0
		# Step from the tile's cell, even when its shape only fills part of it.
		return hit.collider.global_position.snapped(Vector3(8, 8, 8)) + offset
	if select_cell:
		return null
	var build_plane := Plane(Vector3.UP, snappedf(build_height, 8.0))
	return build_plane.intersects_ray(ray_origin, ray_direction)

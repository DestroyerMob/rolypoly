class_name LevelBuilder
extends Node3D

const CELL_SIZE := 8.0
const GRID_STEP := Vector3.ONE * CELL_SIZE

@export var Tile: PackedScene
@export var SurfaceMaterial: TileSurface
@export var build_height: float = 0.0
@export var camera_speed: float = 20.0

@onready var player: Player = $Player
@onready var camera: Camera3D = $Camera3D
var build_mode := true
var build_camera_transform: Transform3D
var spawn_position: Vector3
var spawn_flag := Node3D.new()
var flag_placed := false
var flag_placement_requested := false

func _ready() -> void:
	build_camera_transform = camera.global_transform
	spawn_position = player.global_position
	_create_spawn_flag()
	set_build_mode(true)

func set_build_mode(enabled: bool) -> void:
	build_mode = enabled
	spawn_flag.visible = enabled and flag_placed
	flag_placement_requested = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_active(false)
	camera.set_physics_process(not enabled)
	if enabled:
		camera.global_transform = build_camera_transform
	else:
		build_camera_transform = camera.global_transform
		player.respawn(spawn_position)
		player.set_active(true)
		camera.restore_follow_view()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			set_build_mode(not build_mode)
		elif build_mode and event.physical_keycode == KEY_F:
			flag_placement_requested = true
	if not build_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.look_free(event.relative)

func _physics_process(delta: float) -> void:
	if not build_mode:
		return
	camera.move_free(delta, camera_speed)
	if flag_placement_requested:
		flag_placement_requested = false
		place_spawn_flag_at_mouse()
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	if Input.is_action_just_pressed("build"):
		place_tile_at_mouse()

func place_tile_at_mouse() -> void:
	var placement: Variant = get_mouse_world_position()
	if placement != null:
		place_tile(placement)

func place_tile(world_position: Vector3) -> TileShape:
	var cell_position := snap_to_grid(world_position)
	if is_cell_occupied(cell_position):
		return null
	var tile := Tile.instantiate() as TileShape
	tile.surface = SurfaceMaterial
	add_child(tile)
	tile.global_position = cell_position
	print_debug(tile.global_position)
	return tile

func place_spawn_flag_at_mouse() -> void:
	var cell_position: Variant = get_mouse_world_position(true)
	if cell_position != null:
		set_spawn_cell(cell_position)

func set_spawn_cell(world_position: Vector3) -> void:
	spawn_flag.global_position = snap_to_grid(world_position) + Vector3.UP * CELL_SIZE * 0.5
	flag_placed = true
	spawn_flag.visible = build_mode
	spawn_position = spawn_flag.global_position + Vector3.UP

func snap_to_grid(world_position: Vector3) -> Vector3:
	return world_position.snapped(GRID_STEP)

func is_cell_occupied(world_position: Vector3) -> bool:
	var cell_position := snap_to_grid(world_position)
	for child in get_children():
		if child is TileShape and snap_to_grid(child.global_position) == cell_position:
			return true
	return false

func get_adjacent_cell(world_position: Vector3, normal: Vector3) -> Vector3:
	var axis := normal.abs().max_axis_index()
	var offset := Vector3.ZERO
	offset[axis] = signf(normal[axis]) * CELL_SIZE
	# Step from the tile's cell, even when its shape only fills part of it.
	return snap_to_grid(world_position) + offset

func get_mouse_world_position(select_cell: bool = false) -> Variant:
	var active_camera := get_viewport().get_camera_3d()
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := active_camera.project_ray_origin(mouse_pos)
	var ray_direction := active_camera.project_ray_normal(mouse_pos)
	var hit := raycast_tiles(ray_origin, ray_direction)
	if not hit.is_empty():
		if select_cell:
			return snap_to_grid(hit.collider.global_position)
		return get_adjacent_cell(hit.collider.global_position, hit.normal)
	if select_cell:
		return null
	var build_plane := Plane(Vector3.UP, snappedf(build_height, CELL_SIZE))
	return build_plane.intersects_ray(ray_origin, ray_direction)

func raycast_tiles(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	while not hit.is_empty() and not hit.collider is TileShape:
		query.exclude += [hit.rid]
		hit = space.intersect_ray(query)
	return hit

func _create_spawn_flag() -> void:
	add_child(spawn_flag)
	spawn_flag.hide()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE
	_add_flag_part(Vector3(0.08, 2, 0.08), Vector3(0, 1, 0), material)
	_add_flag_part(Vector3(1, 0.6, 0.08), Vector3(0.5, 1.7, 0), material)

func _add_flag_part(size: Vector3, offset: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	part.position = offset
	spawn_flag.add_child(part)

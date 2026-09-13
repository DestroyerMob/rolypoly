class_name LevelBuilder
extends Node3D

@export var Tile: PackedScene
@export var SurfaceMaterial: TileSurface
@export var build_height: float = 0.0

func _physics_process(delta: float) -> void:
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

func get_mouse_world_position() -> Variant:
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
		var normal: Vector3 = hit.normal
		var axis := normal.abs().max_axis_index()
		var offset := Vector3.ZERO
		offset[axis] = signf(normal[axis]) * 8.0
		# Step from the tile's cell, even when its shape only fills part of it.
		return hit.collider.global_position.snapped(Vector3(8, 8, 8)) + offset
	var build_plane := Plane(Vector3.UP, snappedf(build_height, 8.0))
	return build_plane.intersects_ray(ray_origin, ray_direction)

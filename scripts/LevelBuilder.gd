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
		var tile := Tile.instantiate() as TileShape
		tile.set_surface(SurfaceMaterial)
		add_child(tile)
		tile.global_position = placement.snapped(Vector3(8, 8, 8))
		print_debug(tile.global_position)

func get_mouse_world_position() -> Variant:
	var camera := get_viewport().get_camera_3d()
	var mouse_pos := get_viewport().get_mouse_position()
	
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var build_plane := Plane(Vector3.UP, snappedf(build_height, 8.0))
	return build_plane.intersects_ray(ray_origin, ray_direction)

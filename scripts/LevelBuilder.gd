class_name LevelBuilder
extends Node3D

@export var Tile: PackedScene
@export var SurfaceMaterial: TileSurface

func _physics_process(delta: float) -> void:
	if (Input.is_action_just_pressed("build")):
		var tile := Tile.instantiate() as TileShape
		tile.set_surface(SurfaceMaterial)
		tile.global_position = get_mouse_world_position()
		add_child(tile)
		print_debug(get_mouse_world_position())

func get_mouse_world_position() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var mouse_pos := get_viewport().get_mouse_position()
	
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_direction * 1000.0
	
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end
	)
	
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	
	if result:
		return result.position
	else:
		return Vector3.ZERO

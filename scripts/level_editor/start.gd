extends PlayerStart

func get_spawn_transform() -> Transform3D:
	return Transform3D(global_basis.orthonormalized(), global_position)

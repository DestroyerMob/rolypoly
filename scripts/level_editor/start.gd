extends PlayerStart

func get_spawn_transform() -> Transform3D:
	# Resizing an editor marker must never resize the character on respawn.
	return Transform3D(global_basis.orthonormalized(), global_position)

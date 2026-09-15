extends Area3D

# Respawn without discarding tiles placed in the level builder.
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		print("You died :( ")
		body.call_deferred("respawn", body.spawn_position)

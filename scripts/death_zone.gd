extends Area3D

var _restarting := false


# On death restart the scene after the current physics callback finishes.
func _on_body_entered(body: Node3D) -> void:
	if body is Player and not _restarting:
		_restarting = true
		print("You died :( ")
		get_tree().call_deferred("reload_current_scene")

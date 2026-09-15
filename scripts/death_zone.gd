extends Area3D

#On death restart scene
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		print("You died :( ")
		get_tree().reload_current_scene()

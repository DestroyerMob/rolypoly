extends Area3D

#On win, log that the player has won
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		print("You win!")
		get_tree().reload_current_scene()

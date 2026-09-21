extends Area3D

#On win, log that the player has won
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		print("You win!")
		body.call_deferred("respawn", body.spawn_position)
		body.enter_condition(Player.Condition.WIN)
		
		


func _on_body_exited(body):
	if body is Player:
		body.exit_condition(Player.Condition.NORMAL)

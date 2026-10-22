class_name StarGoalTime
extends StarGoal

## Earned by finishing within a time limit. Time stops while the game is paused.

@export_range(1.0, 3600.0, 1.0, "suffix:s") var seconds_limit := 60.0

var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta


func is_earned(_player: Node = null) -> bool:
	return elapsed <= seconds_limit

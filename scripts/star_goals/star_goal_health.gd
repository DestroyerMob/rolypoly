class_name StarGoalHealth
extends StarGoal

## Earned by finishing with enough health left.

@export_range(1, 1000) var min_health_left := 50


func is_earned(player: Node = null) -> bool:
	return player != null and "health" in player and player.health >= min_health_left

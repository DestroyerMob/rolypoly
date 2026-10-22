class_name StarGoalCollect
extends StarGoal

## Earned by collecting enough items. Anything that gets collected calls collect().

signal progress_changed(collected: int, required: int)

@export_range(1, 200) var required := 5

var collected := 0


func collect(amount := 1) -> void:
	collected += amount
	progress_changed.emit(collected, required)


func is_earned(_player: Node = null) -> bool:
	return collected >= required

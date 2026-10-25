class_name StarGoal
extends Node

## One way to earn stars on a level. Add goal nodes to a level (see the StarGoal* scripts)
## and the level complete card adds up the stars of every goal that was earned.

## What the player has to do, in a few words.
@export var description := ""
## Stars this goal gives when earned. The card caps the total at 3.
@export_range(1, 3) var stars_worth := 1


func _ready() -> void:
	add_to_group(&"star_goal")


## Whether the goal was met. `player` is the player who reached the finish, if known.
func is_earned(_player: Node = null) -> bool:
	return false


## How many stars this goal gives. All-or-nothing goals give `stars_worth` when earned; a goal
## with levels of success overrides this to give 0 to 3.
func earned_stars(player: Node = null) -> int:
	return stars_worth if is_earned(player) else 0

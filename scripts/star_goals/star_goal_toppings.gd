class_name StarGoalToppings
extends StarGoal

## Stars for how many different toppings the ice cream finishes with. Each number is how many
## toppings earn that star: the default [1, 3, 5] gives 1 star for 1-2 toppings, 2 stars for 3-4
## and 3 stars for 5 or more.

@export var toppings_for_each_star: Array[int] = [1, 3, 5]


func toppings_carried(player: Node) -> int:
	if player == null:
		return 0
	for child in player.get_children():
		if child.has_method(&"carried"):
			return child.carried().size()
	return 0


func earned_stars(player: Node = null) -> int:
	var carried := toppings_carried(player)
	var earned := 0
	for needed in toppings_for_each_star:
		if carried >= needed:
			earned += 1
	return mini(earned, 3)


func is_earned(player: Node = null) -> bool:
	return earned_stars(player) > 0

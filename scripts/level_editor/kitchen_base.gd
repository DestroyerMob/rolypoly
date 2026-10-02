extends Node3D

const KITCHEN := preload("res://scenes/kitchen.tscn") #switched to main kitche but the player is still inside

func _ready() -> void:
	reset()

func reset() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var kitchen := KITCHEN.instantiate()
	## Reuse the shared room and fixtures without the demonstration course objects.
	#for path in ["Fixtures/RangeWall/CookingRange/Pot", "Fixtures/SinkWall/BlenderModel"]:
		#kitchen.get_node(path).free() #Commented this out bc the models are in different node locations
	kitchen.get_node("_Set/_Fitout/_ElevationA_Range/_Oven/Oven").start_burners_on = false #changed this to the ovens actual node path
	add_child(kitchen)

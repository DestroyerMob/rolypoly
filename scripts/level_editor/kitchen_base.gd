extends Node3D

const KITCHEN := preload("res://scenes/prototyping/kitchen_set.tscn")

func _ready() -> void:
	reset()

func reset() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var kitchen := KITCHEN.instantiate()
	# Reuse the shared room and fixtures without the demonstration course objects.
	for path in ["Fixtures/RangeWall/CookingRange/Pot", "Fixtures/SinkWall/BlenderModel"]:
		kitchen.get_node(path).free()
	kitchen.get_node("Fixtures/RangeWall/CookingRange/Oven").start_burners_on = false
	add_child(kitchen)

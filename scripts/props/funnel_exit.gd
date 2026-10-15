class_name FunnelExit
extends Node3D

## Where a funnel with the same channel drops the player.
@export_range(1, 20) var channel := 1


func _ready() -> void:
	add_to_group(&"funnel_exit")

class_name StopMeltingZone
extends Area3D

## Stops an ice cream melting while it is inside. Attach to an Area3D around a cold spot, such as
## an icebox or a freezer. Other characters are not affected.

## Seconds the melting stays stopped after the ice cream leaves.
@export_range(0.0, 10.0, 0.05) var linger_seconds := 0.5


func _ready() -> void:
	collision_layer = 0
	monitorable = false


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		for child in body.get_children():
			if child.has_method(&"freeze_melt"):
				child.freeze_melt(linger_seconds)
				break

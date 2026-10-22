class_name CoolingStation
extends Area3D

## Cools down an ice cream standing inside it, bringing its size back.
## Attach to an Area3D with a CollisionShape3D around the cold spot (an ice bench, a fridge, a freezer), or drop in a new Area3D and give it this script.

## Seconds to get from fully melted back to full size while inside.
## 0 restores the ice cream completely the moment it enters.
@export_range(0.0, 60.0, 0.1) var recover_seconds := 2.0


func _ready() -> void:
	if recover_seconds <= 0.0:
		body_entered.connect(_cool.bind(1.0))


func _physics_process(delta: float) -> void:
	if recover_seconds <= 0.0:
		return
	for body in get_overlapping_bodies():
		_cool(body, delta / recover_seconds)


func _cool(body: Node3D, amount: float) -> void:
	for child in body.get_children():
		if child.has_method(&"refresh"):
			child.refresh(amount)
			return

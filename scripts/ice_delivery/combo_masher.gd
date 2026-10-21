extends "res://scripts/obstacles/masher.gd"

## Offset the second press without changing the shared obstacle.
@export var phase_offset := 0.0

func _ready() -> void:
	super._ready()
	for i in range(roundi(phase_offset * 60)):
		super._physics_process(1.0 / 60.0)

func safe_seconds() -> float:
	return _state_time if _state == State.WAITING else 0.0

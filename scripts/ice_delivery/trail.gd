extends IceCreamTrail

## Vika's ground trail, driven by the level's one authoritative health value.
func _physics_process(delta: float) -> void:
	if is_instance_valid(_player) and is_instance_valid(_player.gadget):
		_has_last = false
		return
	super._physics_process(delta)

func _melt(_amount: float) -> void:
	_progress = 1.0 - float(_player.core_health) / 3.0
	_update_scale()

func _apply_scale(factor: float) -> void:
	_applied_scale = factor

func refresh(_amount := 1.0) -> void:
	pass # Re-icing never restores eaten / melted scoop health.

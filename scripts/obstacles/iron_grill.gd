extends Node3D

@export var heated := true
## Total contact time required to melt a fresh ice powerup.
@export_range(0.5, 30.0, 0.5) var ice_melt_seconds := 6.0


func get_ice_melt_rate() -> float:
	return 1.0 / maxf(ice_melt_seconds, 0.5) if heated else 0.0

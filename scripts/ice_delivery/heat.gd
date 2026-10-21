extends StaticBody3D

@export var ice_melt_seconds := 9.0

func get_ice_melt_rate() -> float:
	return 1.0 / maxf(ice_melt_seconds, 0.1)

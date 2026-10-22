extends StaticBody3D

## A real contact surface: observe the colour cycle, then cross while cooling.
@export var period := 5.5
@export var hot_seconds := 2.2
@export var warning_seconds := .6
@export var ice_melt_seconds := 3.5
var elapsed := 0.0
var hot := true

func _physics_process(delta: float) -> void:
	elapsed = fposmod(elapsed+delta,period)
	hot = elapsed < hot_seconds
	var warning := elapsed > period-warning_seconds
	var color := Color("ff642e") if hot else (Color("e9c650") if warning else Color("69c6b7"))
	for child in get_children():
		if child.name.begins_with("HeatStripe"):
			var material: StandardMaterial3D = child.get_node("Mesh").material_override
			material.albedo_color=color
			material.emission_enabled=hot or warning
			material.emission=color
			material.emission_energy_multiplier=.7
	$HeatSign.text = "HOT • WAIT ON WOOD" if hot else ("HEATING SOON" if warning else "COOL • CROSS NOW")
	$HeatSign.modulate=color

func get_ice_melt_rate() -> float:
	return 1.0 / ice_melt_seconds if hot else 0.0

func safe_seconds() -> float:
	return period-elapsed if not hot else 0.0

extends Node3D

## Seconds per full blade rotation. Smaller values spin faster; zero stops it.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var rotation_duration := 1.0

@onready var blade_pivot: Node3D = $Model/BladePivot


func _process(delta: float) -> void:
	if rotation_duration <= 0.0:
		return
	blade_pivot.rotation.y = fposmod(blade_pivot.rotation.y + TAU * delta / rotation_duration, TAU)

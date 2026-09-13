class_name TileShape
extends Node3D

@export var surface: TileSurface

func _ready() -> void:
	var mesh: MeshInstance3D = $CollisionShape3D/MeshInstance3D
	var body: StaticBody3D = $"."
	
	if surface != null:
		mesh.material_override = surface.appearance
		body.physics_material_override = surface.physics
		
func set_surface(s: TileSurface) -> void:
	var mesh: MeshInstance3D = $CollisionShape3D/MeshInstance3D
	var body: StaticBody3D = $"."
	
	if surface != null:
		mesh.material_override = s.appearance
		body.physics_material_override = s.physics

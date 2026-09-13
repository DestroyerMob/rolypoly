class_name TileShape
extends StaticBody3D

@export var surface: TileSurface

func _ready() -> void:
	var mesh: MeshInstance3D = $CollisionShape3D/MeshInstance3D
	
	if surface != null:
		mesh.material_override = surface.appearance
		physics_material_override = surface.physics

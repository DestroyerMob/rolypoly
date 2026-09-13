class_name TileShape
extends Node3D

@export var surface: TileSurface

func _ready() -> void:
	set_surface(surface)

func set_surface(value: TileSurface) -> void:
	surface = value
	var mesh: MeshInstance3D = $CollisionShape3D/MeshInstance3D
	var body: StaticBody3D = $"."
	mesh.material_override = surface.appearance if surface != null else null
	body.physics_material_override = surface.physics if surface != null else null

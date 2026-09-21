@tool
class_name ProtoCylinder
extends ProtoPiece

@export var radius := 1.5:
	set(value):
		radius = maxf(value, 0.05)
		_rebuild()

@export var height := 0.3:
	set(value):
		height = maxf(value, 0.05)
		_rebuild()

@export_range(3, 64, 1) var sides := 24:
	set(value):
		sides = clampi(value, 3, 64)
		_rebuild()


func _height() -> float:
	return height


func _build_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	return m


func _build_shape(_mesh: Mesh) -> Shape3D:
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	return s

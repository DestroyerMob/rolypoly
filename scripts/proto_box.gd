@tool
class_name ProtoBox
extends ProtoPiece

@export var size := Vector3(4.0, 0.5, 4.0):
	set(value):
		size = Vector3(maxf(value.x, 0.05),maxf(value.y, 0.05),maxf(value.z, 0.05))
		_rebuild()

func _height() -> float:
	return size.y

func _build_mesh() -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func _build_shape(_mesh: Mesh) -> Shape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s

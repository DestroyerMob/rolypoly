@tool
class_name ProtoRamp
extends ProtoPiece

@export var run := 6.0:
	set(value):
		run = maxf(value, 0.1)
		_rebuild()

@export var rise := 1.5:
	set(value):
		rise = maxf(value, 0.05)
		_rebuild()

@export var width := 4.0:
	set(value):
		width = maxf(value, 0.1)
		_rebuild()

## Read-only convenience so designers can sanity check a gradient.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var angle_degrees: float:
	get:
		return rad_to_deg(atan2(rise, run))
	set(_v):
		pass


func _height() -> float:
	return rise


func _build_mesh() -> Mesh:
	var m := PrismMesh.new()
	m.size = Vector3(run, rise, width)
	m.left_to_right = 1.0      # 1.0 puts the apex fully to +X, giving a right-angle wedge
	return m


func _build_shape(mesh: Mesh) -> Shape3D:
	return mesh.create_convex_shape()

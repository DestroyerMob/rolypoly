@tool
class_name IrohKitchenPlayerStart
extends Marker3D

# Preview so game designers can see where the spawn is, and how big and
# how high off the floor it sits. Editor only.
@export var preview_radius := 0.25:
	set(preview_radius_value):
		preview_radius = preview_radius_value
		_refresh_preview()

const PREVIEW_COLOR := Color("#FF9AF2")   # GOAL pink, as per Miro

var _preview_mesh: MeshInstance3D = null

func _ready() -> void:
	add_to_group(&"player_start")   # StringName, interned so comparisons are cheap
	_refresh_preview()

func get_spawn_transform() -> Transform3D:   # position + rotation + scale, in world space
	return global_transform

func _refresh_preview() -> void:
	# Exported values are assigned before the node enters the tree,
	# so add_child() would be illegal on that first call. _ready() catches up.
	if not is_inside_tree():
		return
	# Editor affordance. At runtime it is never even constructed.
	if not Engine.is_editor_hint():
		return
	# Create if missing.
	if not is_instance_valid(_preview_mesh):
		_preview_mesh = MeshInstance3D.new()
		add_child(_preview_mesh)   # no set_owner, so it is never written into the .tscn
	# Resize always.
	var sphere := SphereMesh.new()
	sphere.radius = preview_radius
	sphere.height = preview_radius * 2.0
	_preview_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(PREVIEW_COLOR.r, PREVIEW_COLOR.g, PREVIEW_COLOR.b, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_mesh.material_override = mat

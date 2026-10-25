@tool
class_name BlenderUpdraft
extends Node3D

## A blender that blows straight up from its origin, whatever way the model
## is turned. Shows its column in the editor so you can size it by eye.

@export_group("Updraft")
## How high the column reaches above the blender's origin.
@export_range(0.1, 1000.0, 0.1, "or_greater", "suffix:m") var column_height := 5.0:
	set(value):
		column_height = value
		_resize()

@export_range(0.05, 1000.0, 0.05, "or_greater", "suffix:m") var column_radius := 1.0:
	set(value):
		column_radius = value
		_resize()

## Upward acceleration. Gravity is 9.8, so anything above that lifts.
@export_range(0.0, 1000.0, 0.5, "or_greater") var lift_strength := 20.0
## 0 pushes the same everywhere. 1 fades to nothing at the top.
@export_range(0.0, 1.0, 0.05) var falloff := 0.5

@export_group("Preview")
## The column always shows in the editor. Tick to also show it in game.
@export var show_in_game := false:
	set(value):
		show_in_game = value
		_resize()
@export var preview_color := Color(0.3, 0.8, 1.0, 0.15):
	set(value):
		preview_color = value
		_resize()

var _area: Area3D
var _cylinder: CylinderShape3D
var _preview: MeshInstance3D


func _ready() -> void:
	_build()
	_resize()


func _build() -> void:
	#Job 1: The preview. Never given an owner, so it never saves into the
	#       scene. top_level so the model's rotation never tilts it.
	_preview = MeshInstance3D.new()
	_preview.mesh = CylinderMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview.material_override = mat
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.top_level = true
	add_child(_preview)

	#Job 2: The real trigger, only in game.
	if Engine.is_editor_hint():
		return
	_area = Area3D.new()
	var shape := CollisionShape3D.new()
	_cylinder = CylinderShape3D.new()
	shape.shape = _cylinder
	_area.add_child(shape)
	_area.collision_layer = 0
	_area.collision_mask = 0xFFFFFFFF
	_area.monitorable = false
	_area.top_level = true
	add_child(_area)


## Pushes the current numbers into both the preview and the trigger, so the
## two can never disagree.
func _resize() -> void:
	if _preview == null:
		return
	var tube := _preview.mesh as CylinderMesh
	tube.top_radius = column_radius
	tube.bottom_radius = column_radius
	tube.height = column_height
	(_preview.material_override as StandardMaterial3D).albedo_color = preview_color
	_preview.visible = Engine.is_editor_hint() or show_in_game
	if _cylinder != null:
		_cylinder.radius = column_radius
		_cylinder.height = column_height
	_follow()


## Keeps both upright and centred over the blender, wherever it has moved.
func _follow() -> void:
	if not is_inside_tree():
		return
	var t := Transform3D(Basis.IDENTITY,
		global_position + Vector3.UP * column_height * 0.5)
	_preview.global_transform = t
	if _area != null:
		_area.global_transform = t


func _process(_delta: float) -> void:
	#Job 1: In the editor, keep the preview glued on while you drag the blender.
	if Engine.is_editor_hint():
		_follow()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _area == null:
		return
	_follow()
	for body in _area.get_overlapping_bodies():
		if not body is RigidBody3D:
			continue
		var h := clampf((body.global_position.y - global_position.y) / column_height, 0.0, 1.0)
		var strength := lift_strength * (1.0 - falloff * h)
		body.apply_central_force(Vector3.UP * strength * body.mass)

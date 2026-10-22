@tool #Runs in the editor so designers see the door as they size it
class_name IrohKitchenShakerFront #Register type globally
extends Node3D #Pure geometry, collision is optional and handled as one box

## Shaker cabinet front: a flat panel with a raised frame of two stiles and two
## rails. Faces +Z. Place it flat against a carcass face.
##
## The recessed centre is its own mesh, so it can take its own material. The
## WALLS of that recess are the inner faces of the stiles and rails, and stay
## with the frame, which is both simpler and correct joinery.

const GENERATED := &"shaker_generated"

## Width and height of the whole door.
@export var size := Vector2(74.0, 77.0):
	set(value):
		size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_rebuild()

## Thickness of the flat back panel.
@export var panel_depth := 2.0:
	set(value):
		panel_depth = maxf(value, 0.1)
		_rebuild()

## How wide the stiles and rails are. Real shaker is 55 to 75mm.
@export var frame_width := 8.0:
	set(value):
		frame_width = maxf(value, 0.5)
		_rebuild()

## How far the frame stands proud of the panel. This is the shadow line.
@export var frame_depth := 1.2:
	set(value):
		frame_depth = maxf(value, 0.1)
		_rebuild()

## Material for the stiles, rails and the back panel.
@export var material: Material:
	set(value):
		material = value
		_rebuild()

## Material for the recessed centre field only. Leave empty and it falls back
## to `material`, so every door built before this option existed is unchanged.
## Usually this should be the SAME material one value step darker, not a
## different one. A recessed panel reads as shadow, not as another timber.
@export var panel_material: Material:
	set(value):
		panel_material = value
		_rebuild()

## Off by default, as the carcass behind usually already has collision.
@export var collision_enabled := false:
	set(value):
		collision_enabled = value
		_rebuild()

var _parts: Array[MeshInstance3D] = []
var _body: StaticBody3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	#Job 1: Bail out early, as add_child() errors on a node not yet in the tree.
	if not is_inside_tree():
		return

	#Job 2: Clear the previous build, as the part count is fixed but their sizes
	#       all change together and rebuilding is simpler than mutating six boxes.
	_clear_generated()

	var half_w := size.x * 0.5
	var half_h := size.y * 0.5
	var frame_z := panel_depth + frame_depth * 0.5
	var rail_len := size.x - frame_width * 2.0

	#Job 3: Build the flat back panel, as everything else sits on top of it.
	#       It stays frame material, because its only visible parts are the
	#       edges of the door.
	_add_part("Panel",
		Vector3(size.x, size.y, panel_depth),
		Vector3(0.0, 0.0, panel_depth * 0.5),
		material)

	#Job 3b: Lay a thin plate over the centre, inset by one frame width on all
	#        four sides so it exactly fills the opening the frame leaves.
	#        This is the only part that can carry its own material, because it
	#        is the only part that is nothing but recess floor.
	#        Sitting 0.15 proud of the panel avoids z-fighting with it.
	var field_w := size.x - frame_width * 2.0
	var field_h := size.y - frame_width * 2.0
	if field_w > 0.01 and field_h > 0.01:
		var field_mat: Material = panel_material if panel_material != null else material
		_add_part("Field",
			Vector3(field_w, field_h, 0.15),
			Vector3(0.0, 0.0, panel_depth + 0.075),
			field_mat)

	#Job 4: Build the stiles at full height, as that is how a real shaker door
	#       is assembled and it puts the joint lines where the eye expects them.
	_add_part("Stile_L",
		Vector3(frame_width, size.y, frame_depth),
		Vector3(-half_w + frame_width * 0.5, 0.0, frame_z),
		material)
	_add_part("Stile_R",
		Vector3(frame_width, size.y, frame_depth),
		Vector3(half_w - frame_width * 0.5, 0.0, frame_z),
		material)

	#Job 5: Build the rails between the stiles, as they are shorter by exactly
	#       two stile widths and must not overlap them.
	if rail_len > 0.01:
		_add_part("Rail_Top",
			Vector3(rail_len, frame_width, frame_depth),
			Vector3(0.0, half_h - frame_width * 0.5, frame_z),
			material)
		_add_part("Rail_Bottom",
			Vector3(rail_len, frame_width, frame_depth),
			Vector3(0.0, -half_h + frame_width * 0.5, frame_z),
			material)

	#Job 6: Add one collider for the whole door, as six separate ones would let
	#       the marble catch on the seams between them.
	if collision_enabled:
		_add_body(Vector3(size.x, size.y, panel_depth + frame_depth),
			Vector3(0.0, 0.0, (panel_depth + frame_depth) * 0.5))


## Builds one box and parents it. No set_owner, so it never serialises.
func _add_part(part_name: String, box_size: Vector3, pos: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.set_meta(GENERATED, true)
	add_child(node)
	_parts.append(node)


func _add_body(box_size: Vector3, pos: Vector3) -> void:
	_body = StaticBody3D.new()
	_body.set_meta(GENERATED, true)
	add_child(_body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	col.position = pos
	_body.add_child(col)


## Removes everything the last rebuild made, as the parts are cheap to recreate
## and tracking six boxes individually is more code than it saves.
func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(GENERATED):
			child.queue_free()
	_parts.clear()
	_body = null

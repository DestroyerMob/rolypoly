@tool #Runs in the editor so designers see the door as they size it
class_name ShakerFront #Register type globally
extends Node3D #Pure geometry, collision is optional and handled as one box

## Shaker cabinet front: a flat panel with a raised frame of two stiles and two
## rails. Faces +Z. Place it flat against a carcass face.

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

@export var material: Material:
	set(value):
		material = value
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
	#       all change together and rebuilding is simpler than mutating five boxes.
	_clear_generated()

	var half_w := size.x * 0.5
	var half_h := size.y * 0.5
	var frame_z := panel_depth + frame_depth * 0.5
	var rail_len := size.x - frame_width * 2.0

	#Job 3: Build the flat back panel, as everything else sits on top of it.
	_add_part("Panel",
		Vector3(size.x, size.y, panel_depth),
		Vector3(0.0, 0.0, panel_depth * 0.5))

	#Job 4: Build the stiles at full height, as that is how a real shaker door
	#       is assembled and it puts the joint lines where the eye expects them.
	_add_part("Stile_L",
		Vector3(frame_width, size.y, frame_depth),
		Vector3(-half_w + frame_width * 0.5, 0.0, frame_z))
	_add_part("Stile_R",
		Vector3(frame_width, size.y, frame_depth),
		Vector3(half_w - frame_width * 0.5, 0.0, frame_z))

	#Job 5: Build the rails between the stiles, as they are shorter by exactly
	#       two stile widths and must not overlap them.
	if rail_len > 0.01:
		_add_part("Rail_Top",
			Vector3(rail_len, frame_width, frame_depth),
			Vector3(0.0, half_h - frame_width * 0.5, frame_z))
		_add_part("Rail_Bottom",
			Vector3(rail_len, frame_width, frame_depth),
			Vector3(0.0, -half_h + frame_width * 0.5, frame_z))

	#Job 6: Add one collider for the whole door, as five separate ones would let
	#       the marble catch on the seams between them.
	if collision_enabled:
		_add_body(Vector3(size.x, size.y, panel_depth + frame_depth),
			Vector3(0.0, 0.0, (panel_depth + frame_depth) * 0.5))


## Builds one box and parents it. No set_owner, so it never serialises.
func _add_part(part_name: String, box_size: Vector3, pos: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	node.mesh = mesh
	node.material_override = material
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
## and tracking five boxes individually is more code than it saves.
func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(GENERATED):
			child.queue_free()
	_parts.clear()
	_body = null

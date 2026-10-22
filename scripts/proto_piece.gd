@tool
class_name ProtoPiece
extends StaticBody3D

## Base class for every parametric blockout piece.
## Subclasses override _build_mesh() and _build_shape() and nothing else.
#To use this class, go into  res://scenes/prototyping/ and then drag in the prototype piece .tscn directly into the level.
#From there you can easily edit wiht the followiong settings
#
#Properties:
	#Fn = Function = Sets the color of the piece to the right material instance
	#Pivot = Object Pivot Point = Sets the pivot point of the object to either top center or base to easily manipulate
	#
###
enum Fn { NEUT, ACC, RDIR, GATE, REST, HAZA, SURF, MOVE, GOAL, CHEC,DEAD,FURN }
enum Pivot { BASE, CENTER, TOP }

## MOVE_ffe84e / fff993 / e0e3eb / 85878f

const MATERIALS := {
	Fn.NEUT: preload("res://materials/level_prototyping/MI_NEUT_world_grid_prototype.tres"),
	Fn.ACC:  preload("res://materials/level_prototyping/MI_ACC_world_grid_prototype.tres"),
	Fn.RDIR: preload("res://materials/level_prototyping/MI_RDIR_world_grid_prototype.tres"),
	Fn.GATE: preload("res://materials/level_prototyping/MI_GATE_world_grid_prototype.tres"),
	Fn.REST: preload("res://materials/level_prototyping/MI_REST_world_grid_prototype.tres"),
	Fn.HAZA: preload("res://materials/level_prototyping/MI_HAZA_world_grid_prototype.tres"),
	Fn.SURF: preload("res://materials/level_prototyping/MI_SURF_world_grid_prototype.tres"),
	Fn.MOVE: preload("res://materials/level_prototyping/MI_MOVE_world_grid_prototype.tres"),
	Fn.GOAL: preload("res://materials/level_prototyping/MI_GOAL_world_grid_prototype.tres"),
	Fn.CHEC: preload("res://materials/level_prototyping/MI_CHEC_world_grid_prototype.tres"),
	Fn.DEAD: preload("res://materials/level_prototyping/MI_DEAD_world_grid_prototype.tres"),
	Fn.FURN: preload("res://materials/level_prototyping/MI_FURN_world_grid_prototype.tres"),
}

@export var fn: Fn = Fn.NEUT:
	set(value):
		fn = value
		_rebuild()

## Where the node's origin sits relative to the shape.
## BASE is the default because it makes pieces sit on the floor at y = 0.
@export var pivot: Pivot = Pivot.BASE:
	set(value):
		pivot = value
		_rebuild()

var _mesh_node: MeshInstance3D
var _col_node: CollisionShape3D


func _ready() -> void:
	_rebuild()


# --- plumbing ---------------------------------------------------------------

func _ensure_nodes() -> void:
	if not is_instance_valid(_mesh_node):
		_mesh_node = get_node_or_null(^"Mesh") as MeshInstance3D
	if not is_instance_valid(_mesh_node):
		_mesh_node = MeshInstance3D.new()
		_mesh_node.name = "Mesh"
		add_child(_mesh_node)          # no set_owner, so it is never saved into the .tscn

	if not is_instance_valid(_col_node):
		_col_node = get_node_or_null(^"Collision") as CollisionShape3D
	if not is_instance_valid(_col_node):
		_col_node = CollisionShape3D.new()
		_col_node.name = "Collision"
		add_child(_col_node)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_ensure_nodes()

	var mesh := _build_mesh()
	if mesh == null:
		return

	_mesh_node.mesh = mesh
	_mesh_node.material_override = MATERIALS.get(fn)
	_col_node.shape = _build_shape(mesh)

	var offset := _pivot_offset()
	_mesh_node.position = offset
	_col_node.position = offset


func _pivot_offset() -> Vector3:
	var h := _height()
	match pivot:
		Pivot.BASE:
			return Vector3(0.0, h * 0.5, 0.0)
		Pivot.TOP:
			return Vector3(0.0, -h * 0.5, 0.0)
		_:
			return Vector3.ZERO


# --- subclass contract ------------------------------------------------------

func _build_mesh() -> Mesh:
	return null


func _build_shape(mesh: Mesh) -> Shape3D:
	return mesh.create_convex_shape()


func _height() -> float:
	return 1.0

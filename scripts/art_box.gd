@tool #Script that allows designers to choose size and then it automatically sizes mesh and collider 
class_name ArtBox #Register type globally 
extends StaticBody3D #Not to be moved by anything

## Resizable box for art-pass kitchen joinery. Same idea as ProtoBox, except
## the material is a designer choice rather than a function code.

const GENERATED := &"art_box_generated" #Stamp node  & is a StringName

enum Pivot { BASE, CENTER, TOP }
enum Plan {
	CENTER,
	LEFT, RIGHT, FRONT, BACK,
	FRONT_LEFT, FRONT_RIGHT, BACK_LEFT, BACK_RIGHT,
}
# Used For Bevelling 
const _AXES := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
# Indexed 0,1,2 so the builder below walks X, Y, Z in one loop instead of three
# copies of the same code. Order matters: X cross Y = Z, so
# _AXES[a] cross _AXES[a+1] = _AXES[a+2] and the winding maths stays honest.

@export var size := Vector3(100.0, 4.0, 60.0):
	set(value):
		size = Vector3(maxf(value.x, 0.01), maxf(value.y, 0.01), maxf(value.z, 0.01))
		_rebuild()

@export var material: Material:
	set(value):
		material = value
		_rebuild()

## Move mesh and collider inside box
@export var pivot: Pivot = Pivot.BASE:
	set(value):
		pivot = value
		_rebuild()
## Moves the pivot horizontally. Use an edge value for a hinge line, so the
## piece swings about that edge instead of orbiting its own centre.
@export var plan_pivot: Plan = Plan.CENTER:
	set(value):
		plan_pivot = value
		_rebuild()
		
## Chamfer on all twelve edges, in world units. 0 uses a plain BoxMesh.
## The point is the highlight it catches, not the silhouette, so keep it small.
## 0.6 on a benchtop, 1.5 on a beam. Auto-clamped so it can never eat the box.
@export var bevel := 0.0:
	set(value):
		bevel = maxf(value, 0.0)
		_rebuild()

## Turn off for decorative panels stuck to a face that already has collision,
## so the marble does not hit two colliders in the same place.
@export var collision_enabled := true:
	set(value):
		collision_enabled = value
		_rebuild()

var _mesh_node: MeshInstance3D
var _col_node: CollisionShape3D


## Catches up on the build that every setter skipped during load.
## Godot's load order:
##   1. Node constructed
##   2. Exported values read from the .tscn and assigned. Each assignment fires
##      its setter, which calls _rebuild()... but the node is not in the tree
##      yet, so every one of those hits the guard and returns immediately.
##   3. Node added to the tree
##   4. _ready() runs. FIRST moment a rebuild can actually work.
## Setters handle changes AFTER load. _ready() handles the initial build.

func _ready() -> void:
	_rebuild()

## Turns the four exports into geometry. Safe to run constantly, as it replaces rather than accumulates.
func _rebuild() -> void:
#Job 1: Bail out early, as add_child() errors on a node not yet in the tree.
	if not is_inside_tree():
		return
		
#Job 2: Guarantee both children exist, so everything below needs no null checks.
	_ensure_nodes()
	
#Job 3: Build the visual from size, as nothing connects the export to the
#       mesh. Below the threshold we use BoxMesh, which is 12 triangles and
#       free. Above it we generate a chamfered box, which is 44.
	var limit := minf(minf(size.x, size.y), size.z) * 0.49
	var b := clampf(bevel, 0.0, limit)
	if b <= 0.001:
		var mesh := BoxMesh.new()
		mesh.size = size
		_mesh_node.mesh = mesh
	else:
		_mesh_node.mesh = _build_beveled_box(size, b)
	_mesh_node.material_override = material
#Job 4: Build the collider from the SAME size, as a mismatch here is an invisible wall or a floor that is not there.
	var shape := BoxShape3D.new()
	shape.size = size
	_col_node.shape = shape
	_col_node.disabled = not collision_enabled
	
#Job 5: Offset both children identically, as the pivot must move the visual and the collision together or they drift apart.
	var offset := _pivot_offset()
	_mesh_node.position = offset
	_col_node.position = offset


## Children are created without set_owner, so they never serialise into the
## .tscn. The script rebuilds them every load. Same trick as ProtoPiece.
func _ensure_nodes() -> void:
	#Job 1: Skip the work below, as the reference we already hold is still valid.
	if not is_instance_valid(_mesh_node):
		#Job 2: Re-adopt the labelled child, as the reference dies on every scene or script reload but the node itself survives.
		for child in get_children():
			if child is MeshInstance3D and child.has_meta(GENERATED):
				_mesh_node = child
				break
				
	#Job 3: Create mesh node and label it before it joins the tree. As there is no reference and nothing found in the children. 
	if not is_instance_valid(_mesh_node):
		_mesh_node = MeshInstance3D.new()
		_mesh_node.set_meta(GENERATED, true)
		add_child(_mesh_node)
		
	#Jobs 1 to 3 repeated for the collider
	if not is_instance_valid(_col_node):
		for child in get_children():
			if child is CollisionShape3D and child.has_meta(GENERATED):
				_col_node = child
				break
	if not is_instance_valid(_col_node):
		_col_node = CollisionShape3D.new()
		_col_node.set_meta(GENERATED, true)
		add_child(_col_node)


## Works out how far to push the mesh and collider off the node origin, so that
## the origin lands where the designer asked. Height and plan are worked out
## separately, as they are independent choices that combine freely.
func _pivot_offset() -> Vector3:
	var half := size * 0.5
	var offset := Vector3.ZERO

	#Job 1: Height. Push up by half so the box stands ON the node, or down by
	#       half so it hangs FROM the node. CENTER and anything added later
	#       leave it alone.
	match pivot:
		Pivot.BASE:
			offset.y = half.y
		Pivot.TOP:
			offset.y = -half.y

	#Job 2: Plan. Collect a direction per axis rather than a finished offset,
	#       as the corner cases are just two edge cases at once and this way
	#       they need no extra arithmetic.
	var x_dir := 0.0
	var z_dir := 0.0
	match plan_pivot:
		Plan.LEFT:
			x_dir = 1.0
		Plan.RIGHT:
			x_dir = -1.0
		Plan.FRONT:
			z_dir = -1.0
		Plan.BACK:
			z_dir = 1.0
		Plan.FRONT_LEFT:
			x_dir = 1.0
			z_dir = -1.0
		Plan.FRONT_RIGHT:
			x_dir = -1.0
			z_dir = -1.0
		Plan.BACK_LEFT:
			x_dir = 1.0
			z_dir = 1.0
		Plan.BACK_RIGHT:
			x_dir = -1.0
			z_dir = 1.0

	#Job 3: Push the box away from the pivot, as the pivot staying put is the
	#       whole point. Hinge on the left edge and the door must extend right.
	offset.x = half.x * x_dir
	offset.z = half.z * z_dir
	return offset

## A chamfered box is three families of face: six inset rectangles where the
## original faces were, twelve quads spanning the original edges, and eight
## triangles at the original corners. No UVs are written, because every
## material on this tool is triplanar and generates its own coordinates.
func _build_beveled_box(dim: Vector3, b: float) -> ArrayMesh:
	var half := dim * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	#Job 1: Six face rectangles, each pulled in by the bevel on all four sides.
	for a in 3:
		var e_a: Vector3 = _AXES[a]
		var e_u: Vector3 = _AXES[(a + 1) % 3]
		var e_v: Vector3 = _AXES[(a + 2) % 3]
		var hu := half[(a + 1) % 3] - b
		var hv := half[(a + 2) % 3] - b
		for i in 2:
			var s := -1.0 if i == 0 else 1.0
			var c := e_a * (s * half[a])
			_add_face(st, [
				c - e_u * hu - e_v * hv,
				c + e_u * hu - e_v * hv,
				c + e_u * hu + e_v * hv,
				c - e_u * hu + e_v * hv,
			], e_a * s)

	#Job 2: Twelve edge quads, each bridging the gap the inset just opened up
	#       between two neighbouring faces.
	for a in 3:
		var e_a: Vector3 = _AXES[a]
		var e_u: Vector3 = _AXES[(a + 1) % 3]
		var e_v: Vector3 = _AXES[(a + 2) % 3]
		var ha := half[a] - b
		var hu := half[(a + 1) % 3]
		var hv := half[(a + 2) % 3]
		for iu in 2:
			for iv in 2:
				var su := -1.0 if iu == 0 else 1.0
				var sv := -1.0 if iv == 0 else 1.0
				var p_u := e_u * (su * hu) + e_v * (sv * (hv - b))
				var p_v := e_u * (su * (hu - b)) + e_v * (sv * hv)
				_add_face(st, [
					p_u - e_a * ha,
					p_u + e_a * ha,
					p_v + e_a * ha,
					p_v - e_a * ha,
				], (e_u * su + e_v * sv).normalized())

	#Job 3: Eight corner triangles, one per original corner, closing the three
	#       edge quads that meet there.
	for ix in 2:
		for iy in 2:
			for iz in 2:
				var sx := -1.0 if ix == 0 else 1.0
				var sy := -1.0 if iy == 0 else 1.0
				var sz := -1.0 if iz == 0 else 1.0
				_add_face(st, [
					Vector3(sx * half.x, sy * (half.y - b), sz * (half.z - b)),
					Vector3(sx * (half.x - b), sy * half.y, sz * (half.z - b)),
					Vector3(sx * (half.x - b), sy * (half.y - b), sz * half.z),
				], Vector3(sx, sy, sz).normalized())

	#Job 4: Flat normals, as a chamfer reads through its hard edges.
	st.generate_normals()
	return st.commit()


## Adds one convex polygon, facing outward, whatever order it arrived in.
func _add_face(st: SurfaceTool, points: Array, outward: Vector3) -> void:
	#Job 1: Pull the first three corners into typed locals, as indexing an
	#       untyped Array yields Variant and := cannot infer from it.
	var p0: Vector3 = points[0]
	var p1: Vector3 = points[1]
	var p2: Vector3 = points[2]
	var facing := (p1 - p0).cross(p2 - p0)
	#Job 2: Reverse if it comes out anticlockwise, as Godot's front faces are
	#       CLOCKWISE seen from outside and cull_back would eat the wrong ones.
	var p := points.duplicate()
	if facing.dot(outward) > 0.0:
		p.reverse()
	#Job 3: Fan from the first point, safe because every face here is convex.
	for i in range(1, p.size() - 1):
		st.add_vertex(p[0])
		st.add_vertex(p[i])
		st.add_vertex(p[i + 1])

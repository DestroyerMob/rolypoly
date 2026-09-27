@tool #Designer sizes it and the mesh and collider follow, live in the editor
class_name TaperBox
extends StaticBody3D #Level geometry, nothing moves it

## A frustum: a box whose top face differs in size from its bottom, optionally
## shifted sideways so the taper can be one-sided. Built for plastered
## rangehood canopies, chimney breasts, plinths and tapered legs.
## Geometry is built with the BOTTOM face at y = 0, then pushed by the pivot.

const GENERATED := &"taper_box_generated" #Stamp node

enum Pivot { BASE, CENTER, TOP }

## Footprint at the bottom, X by Z.
@export var bottom_size := Vector2(120.0, 60.0):
	set(value):
		bottom_size = Vector2(maxf(value.x, 0.01), maxf(value.y, 0.01))
		_rebuild()

## Footprint at the top, X by Z. Set both to 0 for a true pyramid.
@export var top_size := Vector2(60.0, 30.0):
	set(value):
		top_size = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		_rebuild()

@export var height := 80.0:
	set(value):
		height = maxf(value, 0.01)
		_rebuild()

## Slides the top face sideways. This is what makes the taper ONE SIDED.
## A canopy against a wall keeps its back face vertical, so set this to half
## the difference between the bottom and top depth and the back stops leaning.
@export var top_offset := Vector2.ZERO:
	set(value):
		top_offset = value
		_rebuild()

@export var pivot: Pivot = Pivot.BASE:
	set(value):
		pivot = value
		_rebuild()

@export var material: Material:
	set(value):
		material = value
		_rebuild()

@export var collision_enabled := true:
	set(value):
		collision_enabled = value
		_rebuild()

var _mesh_node: MeshInstance3D
var _col_node: CollisionShape3D


## Catches up on the build that every setter skipped during load, because at
## setter time the node is not in the tree yet and _rebuild bails out.
func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	#Job 1: Bail out early, as add_child() errors on a node not yet in the tree.
	if not is_inside_tree():
		return
	#Job 2: Guarantee both children exist, so everything below needs no checks.
	_ensure_nodes()

	#Job 3: Work the corners out ONCE, as the mesh and the collider must come
	#       from the same eight points or they will drift apart.
	var pts := _corners()

	#Job 4: Build the visual.
	_mesh_node.mesh = _build_mesh(pts)
	_mesh_node.material_override = material

	#Job 5: Build the collider as a convex hull of the same points. A frustum
	#       is convex, so this is exact, fast, and solid rather than a shell.
	if collision_enabled:
		var shape := ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array(pts)
		_col_node.shape = shape
	else:
		_col_node.shape = null
	_col_node.disabled = not collision_enabled

	#Job 6: Offset both children identically, or the collision drifts off the
	#       thing you can see.
	var offset := _pivot_offset()
	_mesh_node.position = offset
	_col_node.position = offset


## Indices 0 to 3 are the bottom face, 4 to 7 the top, both going the same way
## round, so side face i is simply corners i, i+1, i+5, i+4.
func _corners() -> Array[Vector3]:
	var b := bottom_size * 0.5
	var t := top_size * 0.5
	var h := height
	var o := top_offset
	return [
		Vector3(-b.x, 0.0, -b.y),
		Vector3(b.x, 0.0, -b.y),
		Vector3(b.x, 0.0, b.y),
		Vector3(-b.x, 0.0, b.y),
		Vector3(o.x - t.x, h, o.y - t.y),
		Vector3(o.x + t.x, h, o.y - t.y),
		Vector3(o.x + t.x, h, o.y + t.y),
		Vector3(o.x - t.x, h, o.y + t.y),
	]


func _build_mesh(pts: Array[Vector3]) -> ArrayMesh:
	#Job 1: Find the solid's centre, as it is what tells every face which way
	#       is out. On a frustum the side faces are not axis aligned, so there
	#       is no constant to compare against.
	var centre := Vector3.ZERO
	for p in pts:
		centre += p
	centre /= float(pts.size())

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	#Job 2: Bottom face.
	_add_face(st, [pts[0], pts[1], pts[2], pts[3]], centre)

	#Job 3: Top face, skipped when the top is a point, as four identical
	#       corners would produce degenerate triangles.
	if top_size.x > 0.001 and top_size.y > 0.001:
		_add_face(st, [pts[4], pts[5], pts[6], pts[7]], centre)

	#Job 4: Four sides, each bridging one bottom edge to the matching top edge.
	for i in 4:
		var j := (i + 1) % 4
		_add_face(st, [pts[i], pts[j], pts[j + 4], pts[i + 4]], centre)

	#Job 5: Flat normals, as a taper reads through its hard edges.
	st.generate_normals()
	return st.commit()


## Adds one convex polygon facing away from the solid's centre, whatever order
## it arrived in. Works for any convex solid, not just this one.
func _add_face(st: SurfaceTool, points: Array, centre: Vector3) -> void:
	#Job 1: Pull the first three corners into typed locals, as indexing an
	#       untyped Array yields Variant and := cannot infer from it.
	var p0: Vector3 = points[0]
	var p1: Vector3 = points[1]
	var p2: Vector3 = points[2]
	var facing := (p1 - p0).cross(p2 - p0)
	#Job 2a: Average ALL the points, not just the first three. On a heavily
	#        offset frustum the first three corners of a side quad sit well off
	#        that face's middle, and the direction they imply can be wrong.
	var face_centre := Vector3.ZERO
	for pt in points:
		face_centre += pt
	face_centre /= float(points.size())
	var outward := face_centre - centre
	
	var p := points.duplicate()
	if facing.dot(outward) > 0.0:
		p.reverse()
	#Job 3: Fan from the first point, safe because every face here is convex.
	for i in range(1, p.size() - 1):
		st.add_vertex(p[0])
		st.add_vertex(p[i])
		st.add_vertex(p[i + 1])


func _pivot_offset() -> Vector3:
	match pivot:
		#Job 1: Geometry is already built with its base at y = 0, so BASE needs
		#       nothing and the other two pull it down.
		Pivot.CENTER:
			return Vector3(0.0, -height * 0.5, 0.0)
		Pivot.TOP:
			return Vector3(0.0, -height, 0.0)
		_:
			return Vector3.ZERO


func _ensure_nodes() -> void:
	#Job 1: Skip the work below, as the reference we hold is still valid.
	if not is_instance_valid(_mesh_node):
		#Job 2: Re-adopt the labelled child, as the reference dies on every
		#       script reload but the node itself survives.
		for child in get_children():
			if child is MeshInstance3D and child.has_meta(GENERATED):
				_mesh_node = child
				break
	#Job 3: Create it and label it before it joins the tree, as there is no
	#       reference and nothing was found in the children.
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

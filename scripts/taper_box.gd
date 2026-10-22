@tool #Designer sizes it and the mesh and collider follow, live in the editor
class_name TaperBox
extends StaticBody3D #Level geometry, nothing moves it

## A frustum: a box whose top face differs in size from its bottom, optionally
## shifted sideways so the taper can be one-sided. Built for plastered
## rangehood canopies, chimney breasts, plinths and tapered legs.
## Geometry is built with the BOTTOM face at y = 0, then pushed by the pivot.

const GENERATED := &"taper_box_generated" #Stamp node

enum Pivot { BASE, CENTER, TOP }

## The solid's six faces, each as four corner indices from _corners().
## Corners 0 to 3 are the bottom going one way round, 4 to 7 the top going the
## SAME way round, so side face i is corners i, i+1, i+5, i+4.
## Everything the bevel does is driven off this table, which is why the bevel
## builder below never mentions an axis.
const _FACES := [
	[0, 1, 2, 3], #Bottom
	[4, 5, 6, 7], #Top
	[0, 1, 5, 4], #Sides
	[1, 2, 6, 5],
	[2, 3, 7, 6],
	[3, 0, 4, 7],
]

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

## Chamfer on all twelve edges, in world units. 0 builds the plain frustum.
## Measured IN THE PLANE OF EACH FACE, so on a steeply raked side the chamfer
## is very slightly wider measured vertically than it is on an upright one.
## Invisible at play distance, and it is the honest way to inset a slanted face.
##
## IGNORED when either top_size component is 0. A pyramid or a ridge has no top
## face, so the twelve-edge topology this builder relies on does not exist.
## Auto-clamped so it can never eat the solid.
@export var bevel := 0.0:
	set(value):
		bevel = maxf(value, 0.0)
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
	#       from the same points or they will drift apart.
	var pts := _corners()

	#Job 4: Build the visual, and collect the points the collider should use.
	#       Below the bevel threshold those are the eight raw corners. Above it
	#       they are the twenty four inset points, so the collider is chamfered
	#       too and the marble cannot catch on an edge that is not drawn.
	var b := _bevel_limit()
	var hull := PackedVector3Array()
	if b <= 0.001:
		_mesh_node.mesh = _build_mesh(pts)
		hull = PackedVector3Array(pts)
	else:
		var rings := _inset_rings(pts, b)
		_mesh_node.mesh = _build_beveled_mesh(pts, rings)
		for ring in rings:
			for p in ring:
				hull.append(p)
	_mesh_node.material_override = material

	#Job 5: Build the collider as a convex hull of those points. A frustum is
	#       convex and so is a chamfered one, so this is exact, fast, and solid
	#       rather than a shell.
	if collision_enabled:
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
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


## How much chamfer is actually legal on the current proportions.
func _bevel_limit() -> float:
	#Job 1: Refuse outright on a pyramid or a ridge. With a degenerate top the
	#       solid has eight edges and five faces, not twelve and six, and every
	#       assumption in the bevel builder fails. Better a hard no than a
	#       silently inside out mesh.
	if top_size.x <= 0.001 or top_size.y <= 0.001:
		return 0.0

	#Job 2: Cap at just under half the narrowest dimension, as two insets
	#       coming from opposite sides of the same face must not cross.
	var smallest := minf(minf(bottom_size.x, bottom_size.y),
			minf(top_size.x, top_size.y))
	smallest = minf(smallest, height)
	return clampf(bevel, 0.0, smallest * 0.49)


## The plain frustum. Twelve triangles for the sides plus the two caps.
func _build_mesh(pts: Array[Vector3]) -> ArrayMesh:
	#Job 1: Find the solid's centre, as it is what tells every face which way
	#       is out. On a frustum the side faces are not axis aligned, so there
	#       is no constant to compare against.
	var centre := _average(pts)

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


## One inset ring per face, in the same order as _FACES. Ring entry k belongs
## to solid corner _FACES[f][k], which is how the edge and corner builders
## below find the right point without any geometry search.
func _inset_rings(pts: Array[Vector3], b: float) -> Array:
	var rings := []
	for f in _FACES.size():
		var idx: Array = _FACES[f]
		var poly: Array[Vector3] = []
		for i in idx:
			poly.append(pts[i])
		rings.append(_inset_ring(poly, b))
	return rings


## Pushes every edge of one planar convex polygon inward by b, then reports
## where consecutive pushed edges now cross. This is the whole reason the
## bevel works on a taper: it never asks which axis the face faces.
func _inset_ring(poly: Array[Vector3], b: float) -> Array[Vector3]:
	var n := poly.size()
	var centre := _average(poly)

	#Job 1: The face's plane. Sign does not matter, as Job 2 decides inward by
	#       comparing against the face centre rather than trusting the normal.
	var normal := (poly[1] - poly[0]).cross(poly[2] - poly[0]).normalized()

	#Job 2: One pushed line per edge, stored as a point and a direction.
	var origins: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	for i in n:
		var a := poly[i]
		var c := poly[(i + 1) % n]
		var u := (c - a).normalized()
		var w := normal.cross(u)
		if w.dot(centre - a) < 0.0:
			w = -w
		origins.append(a + w * b)
		dirs.append(u)

	#Job 3: Corner i of the ring is where the edge ARRIVING at poly[i] and the
	#       edge LEAVING it now cross. On a rectangle this reduces to the plain
	#       inset in ArtBox. On a trapezoid it correctly follows the rake.
	var out: Array[Vector3] = []
	for i in n:
		var h := (i + n - 1) % n
		out.append(_line_cross(origins[h], dirs[h], origins[i], dirs[i]))
	return out


## Where two coplanar, non-parallel lines meet.
func _line_cross(p1: Vector3, u1: Vector3, p2: Vector3, u2: Vector3) -> Vector3:
	var x := u1.cross(u2)
	var denom := x.length_squared()
	#Job 1: Fall back to the midpoint on parallel lines. Cannot happen on the
	#       adjacent edges of a convex quad, but a NaN here would poison the
	#       whole mesh and a wrong point only bends one corner.
	if denom < 0.000001:
		return (p1 + p2) * 0.5
	var t := (p2 - p1).cross(u2).dot(x) / denom
	return p1 + u1 * t


## The chamfered frustum. Six inset faces, twelve edge quads, eight corner
## triangles. Same three families as the ArtBox builder, derived from the face
## table instead of from the axes.
func _build_beveled_mesh(pts: Array[Vector3], rings: Array) -> ArrayMesh:
	var centre := _average(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	#Job 1: The six inset faces, used exactly as _inset_rings produced them.
	for f in _FACES.size():
		var ring: Array[Vector3] = rings[f]
		_add_face(st, ring, centre)

	#Job 2: Twelve edge quads. Every edge is shared by exactly two faces, and
	#       both of those faces pulled away from it by b, so the quad spans the
	#       gap. Both of its long sides are parallel to the original edge, which
	#       is what guarantees it is planar and convex.
	var edges := _edge_faces()
	for key in edges:
		var e: Vector2i = key
		var fs: Array = edges[key]
		if fs.size() != 2:
			continue
		var f1: int = fs[0]
		var f2: int = fs[1]
		_add_face(st, [
			_corner_point(rings, f1, e.x),
			_corner_point(rings, f1, e.y),
			_corner_point(rings, f2, e.y),
			_corner_point(rings, f2, e.x),
		], centre)

	#Job 3: Eight corner triangles. Each original corner belongs to three faces
	#       and each of those left one point behind, so the three points close
	#       the hole the three edge quads meeting there left open.
	for v in pts.size():
		var fs := _faces_at(v)
		_add_face(st, [
			_corner_point(rings, fs[0], v),
			_corner_point(rings, fs[1], v),
			_corner_point(rings, fs[2], v),
		], centre)

	#Job 4: Flat normals, as a chamfer reads through its hard edges.
	st.generate_normals()
	return st.commit()


## Every edge of the solid, keyed by its two corner indices low to high, mapped
## to the faces that share it. Built from _FACES rather than hand listed, so
## adding a face to that table cannot silently desync this.
func _edge_faces() -> Dictionary:
	var out := {}
	for f in _FACES.size():
		var face: Array = _FACES[f]
		for k in face.size():
			var a: int = face[k]
			var c: int = face[(k + 1) % face.size()]
			var key := Vector2i(mini(a, c), maxi(a, c))
			if not out.has(key):
				out[key] = []
			out[key].append(f)
	return out


## The three faces meeting at one corner.
func _faces_at(v: int) -> Array[int]:
	var out: Array[int] = []
	for f in _FACES.size():
		var face: Array = _FACES[f]
		if face.has(v):
			out.append(f)
	return out


## The point face f left behind near solid corner v.
func _corner_point(rings: Array, f: int, v: int) -> Vector3:
	var face: Array = _FACES[f]
	var ring: Array[Vector3] = rings[f]
	return ring[face.find(v)]


func _average(points: Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in points:
		sum += p
	return sum / float(points.size())


## Adds one convex polygon facing away from the solid's centre, whatever order
## it arrived in. Works for any convex solid, not just this one.
func _add_face(st: SurfaceTool, points: Array, centre: Vector3) -> void:
	#Job 1: Pull the first three corners into typed locals, as indexing an
	#       untyped Array yields Variant and := cannot infer from it.
	var p0: Vector3 = points[0]
	var p1: Vector3 = points[1]
	var p2: Vector3 = points[2]
	var facing := (p1 - p0).cross(p2 - p0)
	#Job 2: Average ALL the points, not just the first three. On a heavily
	#       offset frustum the first three corners of a side quad sit well off
	#       that face's middle, and the direction they imply can be wrong.
	var outward := _average(points) - centre

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

@tool #Designer sizes the niche and it rebuilds live in the editor
class_name IrohKitchenArchNiche #Register type globally
extends StaticBody3D #The liner is level geometry, nothing moves it

## A round-headed niche, built as a CUP: arch-shaped back panel, plus returns
## running from the back panel out to the mouth, plus an optional flange around
## the mouth. The wall itself only needs a plain RECTANGULAR hole cut in it.
## The flange covers the square corners, so the cut never has to be accurate.

const GENERATED := &"arch_niche_generated" #Stamp node

## Clear opening. Height is the whole opening including the arched head.
@export var size := Vector2(60.0, 90.0):
	set(value):
		size = Vector2(maxf(value.x, 0.02), maxf(value.y, 0.02))
		_rebuild()

## How much of the height is arch rather than straight side.
## Equal to half the width gives a true semicircle.
## Less gives a segmental arch, which reads farmhouse rather than church.
## Zero gives a plain rectangle, which is a valid thing to want.
@export var crown_rise := 30.0:
	set(value):
		crown_rise = maxf(value, 0.0)
		_rebuild()

## How far back the niche goes. Must be LESS than the wall thickness.
@export var depth := 20.0:
	set(value):
		depth = maxf(value, 0.01)
		_rebuild()

## Arc resolution. 8 on a small pot niche, 20 on a big one. This is the control
## a CSG cylinder would not have given you.
@export_range(2, 48) var segments := 12:
	set(value):
		segments = value
		_rebuild()

## Band around the mouth, projecting outward in the wall plane. This is what
## hides the rectangular cut. 0 if you cut the hole exactly.
@export var flange := 3.0:
	set(value):
		flange = maxf(value, 0.0)
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
	#Job 3: Build the visual, as nothing connects the exports to the mesh.
	var mesh := _build_mesh()
	_mesh_node.mesh = mesh
	_mesh_node.material_override = material
	#Job 4: Derive the collider from the SAME mesh, as a curved liner cannot be
	#       approximated by a box without the marble catching on air.
	if collision_enabled and mesh != null:
		_col_node.shape = mesh.create_trimesh_shape()
	else:
		_col_node.shape = null
	_col_node.disabled = not collision_enabled


## The arch outline in 2D, counter-clockwise seen from +Z, starting bottom-left.
## Everything this tool draws is this list used three different ways, and the
## same list will build your arched doors and window heads later.
static func profile(w: float, h: float, rise: float, seg: int) -> PackedVector2Array:

	var pts := PackedVector2Array()
	var a := w * 0.5
	var r := clampf(rise, 0.0, h)
	var springing := h - r

	#Job 1: The two bottom corners, always present.
	pts.append(Vector2(-a, 0.0))
	pts.append(Vector2(a, 0.0))

	#Job 2: No rise means a plain rectangle, so finish the box and leave.
	if r <= 0.001:
		pts.append(Vector2(a, h))
		pts.append(Vector2(-a, h))
		return pts

	#Job 3: Find the circle through the two springing points and the crown.
	#       Radius comes from the chord half-width and the rise. This is the
	#       whole of the arch maths, and it is one line.
	var radius := (a * a + r * r) / (2.0 * r)
	var cy := springing + r - radius

	#Job 4: Sweep the arc. t_end is PI minus t_start by symmetry, which is
	#       exact and avoids atan2 wrapping the wrong way on a tall arch.
	var t_start := atan2(springing - cy, a)
	var t_end := PI - t_start
	for i in seg + 1:
		var t := lerpf(t_start, t_end, float(i) / float(seg))
		pts.append(Vector2(cos(t) * radius, cy + sin(t) * radius))
	return pts


func _build_mesh() -> ArrayMesh:
	var w := size.x
	var h := size.y
	var d := depth
	var inner := IrohKitchenArchNiche.profile(w, h, crown_rise, segments)
	var count := inner.size()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	#Job 1: Back panel. The outline is convex by construction, so a fan from
	#       the first point is safe and needs no triangulation library.
	var back: Array[Vector3] = []
	for p in inner:
		back.append(Vector3(p.x, p.y, -d))
	_add_face(st, back, Vector3.BACK)

	#Job 2: Returns. One quad per outline edge, running from the back panel to
	#       the mouth. They face INWARD, as you only ever see them from inside
	#       the cavity, and cull_back would eat them otherwise.
	for i in count:
		var a2 := inner[i]
		var b2 := inner[(i + 1) % count]
		var edge := b2 - a2
		if edge.length() < 0.0001:
			continue
		var inward := Vector2(-edge.y, edge.x).normalized()
		_add_face(st, [
			Vector3(a2.x, a2.y, -d),
			Vector3(b2.x, b2.y, -d),
			Vector3(b2.x, b2.y, 0.0),
			Vector3(a2.x, a2.y, 0.0),
		], Vector3(inward.x, inward.y, 0.0))

	#Job 3: Flange. A second, larger copy of the same profile, indexed against
	#       the first. Same point count means every quad is index i to i+1 on
	#       both rings, so there are no corner joins to work out.
	var f := flange
	if f > 0.001:
		var outer_rise := (crown_rise + f) if crown_rise > 0.001 else 0.0
		var outer := IrohKitchenArchNiche.profile(w + f * 2.0, h + f * 2.0, outer_rise, segments)
		#Job 3b: Skip rather than crash if the rings ever disagree, as a
		#        mismatched count would index past the end.
		if outer.size() == count:
			for i in count:
				var ia := inner[i]
				var ib := inner[(i + 1) % count]
				var oa := outer[i] - Vector2(0.0, f)
				var ob := outer[(i + 1) % count] - Vector2(0.0, f)
				_add_face(st, [
					Vector3(ia.x, ia.y, 0.0),
					Vector3(ib.x, ib.y, 0.0),
					Vector3(ob.x, ob.y, 0.0),
					Vector3(oa.x, oa.y, 0.0),
				], Vector3.BACK)

	#Job 4: Flat normals, as every vertex here belongs to one triangle only.
	#       The arch reads through its facets, which is what segments controls.
	st.generate_normals()
	return st.commit()


## Adds one convex polygon, facing outward, whatever order it arrived in.
func _add_face(st: SurfaceTool, points: Array, outward: Vector3) -> void:
	#Job 1: Pull the first three corners into typed locals, as indexing an
	#       untyped Array yields Variant and the compiler cannot infer from it.
	var p0: Vector3 = points[0]
	var p1: Vector3 = points[1]
	var p2: Vector3 = points[2]
	var facing := (p1 - p0).cross(p2 - p0)
	#Job 2: Reverse it if it faces the wrong way, so the three builders above
	#       never have to reason about winding.
	var p := points.duplicate()
	if facing.dot(outward) < 0.0:
		p.reverse()
	#Job 3: Fan from the first point, safe because every face here is convex.
	for i in range(1, p.size() - 1):
		st.add_vertex(p[0])
		st.add_vertex(p[i])
		st.add_vertex(p[i + 1])


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

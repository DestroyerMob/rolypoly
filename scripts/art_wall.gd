@tool #Designer sizes the wall and its openings, everything else is automatic
class_name ArtWall
extends CSGCombiner3D #Root of its own CSG tree, so Use Collision works here
# TODO: DUPLICATION. _build_beveled_box and _add_face below are a copy of the
# same two functions in art_box.gd. Kept local on purpose during crunch so this
# file has no cross-tool dependency

## A wall with holes in it. Builds the union solid, one exact arch-shaped
## subtraction per opening, and an ArchNiche liner for any opening marked NICHE.
## Origin is at the BASE CENTRE of the wall, so Position Y is floor level and
## every opening's sill height is measured from it.
## The room-facing side is +Z unless you tick Flip Cuts.

const GENERATED := &"art_wall_generated" #Stamp node

# Indexed 0,1,2 so the bevel builder walks X, Y, Z in one loop instead of three
# copies of the same code. Order matters: X cross Y = Z, so
# _AXES[a] cross _AXES[a+1] = _AXES[a+2] and the winding maths stays honest.
const _AXES := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]

@export var size := Vector3(600.0, 250.0, 35.0):
	set(value):
		size = Vector3(maxf(value.x, 0.02), maxf(value.y, 0.02), maxf(value.z, 0.02))
		_rebuild()

@export var material: Material:
	set(value):
		material = value
		_rebuild()

## Click + and choose New WallOpening for each hole.
@export var openings: Array[WallOpening] = []:
	set(value):
		#Job 1: Drop the old connections first, as the resources in the old
		#       array may still exist elsewhere and would keep firing.
		_unwatch()
		openings = value
		_watch()
		_rebuild()

## Godot extrudes a CSGPolygon3D one way along Z, and which way is not worth
## memorising. If your cuts miss the wall, or the niches appear on the far
## side, tick this once and forget it.
@export var flip_cuts := false:
	set(value):
		flip_cuts = value
		_rebuild()

## Chamfer on ALL TWELVE edges, in world units. 0 uses a plain CSGBox3D.
## CSG has no bevel operation, so above 0 the union becomes a CSGMesh3D
## carrying a chamfered box built below. That costs no extra boolean
## operations, which cutting twelve wedges would have.
## Real plaster arrises are 10 to 20mm, so 1 to 2 here.
## Auto-clamped so it can never eat the wall.
@export var bevel := 0.0:
	set(value):
		bevel = maxf(value, 0.0)
		_rebuild()


func _ready() -> void:
	_watch()
	_rebuild()


## The array setter only fires when the ARRAY is replaced. Editing a field
## inside one opening does not touch the array, so the wall would not notice.
## Connecting each resource's changed signal is what closes that gap.
func _watch() -> void:
	for op in openings:
		if op != null and not op.changed.is_connected(_rebuild):
			op.changed.connect(_rebuild)


func _unwatch() -> void:
	for op in openings:
		if op != null and op.changed.is_connected(_rebuild):
			op.changed.disconnect(_rebuild)


func _rebuild() -> void:
	#Job 1: Bail out early, as add_child() errors on a node not yet in the tree.
	if not is_inside_tree():
		return
	#Job 2: Throw the previous build away, as three kinds of child is more
	#       bookkeeping than re-adopting them is worth.
	_clear_generated()

	var t := size.z

	#Job 3: The wall itself, sitting on the node rather than centred on it.
	#       With no bevel it is a plain box. With a bevel it is a CSGMesh3D
	#       carrying the chamfered box built at the bottom of this file, which
	#       gets all twelve edges for one node rather than twelve subtractions.
	var wall: CSGShape3D
	if bevel > 0.001:
		var limit := minf(minf(size.x, size.y), size.z) * 0.49
		var mesh_node := CSGMesh3D.new()
		mesh_node.mesh = _build_beveled_box(size, clampf(bevel, 0.0, limit))
		mesh_node.material = material
		wall = mesh_node
	else:
		var box_node := CSGBox3D.new()
		box_node.size = size
		box_node.material = material
		wall = box_node
	wall.name = "Wall"
	wall.set_meta(GENERATED, true)
	wall.operation = CSGShape3D.OPERATION_UNION
	wall.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(wall)

	for i in openings.size():
		var op: WallOpening = openings[i]
		if op == null:
			continue

		#Job 4: The cut. A polygon, not a box plus a cylinder, so the hole is
		#       the exact arch the liner was built from.
		var poly := CSGPolygon3D.new()
		poly.name = "Cut_%d" % i
		poly.set_meta(GENERATED, true)
		poly.operation = CSGShape3D.OPERATION_SUBTRACTION
		poly.mode = CSGPolygon3D.MODE_DEPTH
		poly.polygon = ArchNiche.profile(op.size.x, op.size.y, op.crown_rise, op.segments)
		poly.material = op.material

		#Job 5: Work out where the extrusion has to start so it covers the
		#       right slab of wall. THROUGH overshoots both faces by 2.
		#       NICHE and RECESS start at the room face and stop at Depth.
		var cut_depth: float
		var z0: float
		if op.kind == WallOpening.Kind.THROUGH:
			cut_depth = t + 4.0
			z0 = (t * 0.5 + 2.0) if flip_cuts else (-t * 0.5 - 2.0)
		else:
			cut_depth = op.depth + 0.5
			z0 = (t * 0.5 + 0.5) if flip_cuts else (t * 0.5 - op.depth)

		#Job 5a: Sink the cavity into the thickness. RECESS only, because a
		#        NICHE's liner is positioned separately in Job 8 and would stay
		#        at the face while the cut moved, leaving a lining floating in
		#        front of its own hole. Guarding here is cheaper than keeping
		#        two positions in sync.
		if op.kind == WallOpening.Kind.RECESS:
			z0 += op.depth_offset

		#Job 5b: Apply the numbers and put the cut in the tree. Nothing above
		#        this line has any effect until the node joins the scene.
		poly.depth = cut_depth
		poly.position = Vector3(op.offset.x, op.offset.y, z0)
		add_child(poly)

		#Job 6: Nothing more to do for THROUGH or RECESS, as the CSG cut faces
		#       already carry the material. Only NICHE gets a liner.
		if op.kind != WallOpening.Kind.NICHE:
			continue

		#Job 7: The liner. Its own collision, so the shelves you add inside it
		#       have something to sit on.
		var niche := ArchNiche.new()
		niche.name = "Niche_%d" % i
		niche.set_meta(GENERATED, true)
		niche.size = op.size
		niche.crown_rise = op.crown_rise
		niche.depth = op.depth
		niche.segments = op.segments
		niche.flange = op.flange
		niche.material = op.material
		niche.collision_enabled = true
		#Job 8: Sit it in the room face with its back running into the wall.
		#       Flipped, it faces the other way, which is a 180 on Y.
		if flip_cuts:
			niche.position = Vector3(op.offset.x, op.offset.y, -t * 0.5)
			niche.rotation = Vector3(0.0, PI, 0.0)
		else:
			niche.position = Vector3(op.offset.x, op.offset.y, t * 0.5)
		add_child(niche)


func _clear_generated() -> void:
	#Job 1: Detach first, as queue_free defers to the end of the frame and the
	#       old children would still be found by the next loop until then.
	for child in get_children():
		if child.has_meta(GENERATED):
			remove_child(child)
			child.queue_free()


## A chamfered box, centred on its own origin, as three families of face:
## six inset rectangles where the original faces were, twelve quads spanning
## the original edges, and eight triangles at the original corners.
## No UVs are written, because every material on this tool is triplanar and
## generates its own coordinates.
static func _build_beveled_box(dim: Vector3, b: float) -> ArrayMesh:
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
	#       between two neighbouring faces. These ARE the chamfers.
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
static func _add_face(st: SurfaceTool, points: Array, outward: Vector3) -> void:
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

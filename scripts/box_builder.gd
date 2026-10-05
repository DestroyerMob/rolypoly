class_name BoxBuilder

## Shared box geometry for every piece that needs one. No state, no exports,
## no _ready. Lifted verbatim from ArtBox so that ArtBox, TaperBox and
## ProtoBook all render the same chamfer from one implementation.

# Indexed 0,1,2 so the builder walks X, Y, Z in one loop instead of three
# copies of the same code. Order matters: X cross Y = Z, so
# _AXES[a] cross _AXES[a+1] = _AXES[a+2] and the winding maths stays honest.
const _AXES := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]


## The one call site everything should use. Clamps the bevel so it can never
## eat the box, and drops to a plain BoxMesh below the threshold, which is
## 12 triangles instead of 44.
static func box_mesh(dim: Vector3, bevel: float) -> Mesh:
	var limit := minf(minf(dim.x, dim.y), dim.z) * 0.49
	var b := clampf(bevel, 0.0, limit)
	if b <= 0.001:
		var mesh := BoxMesh.new()
		mesh.size = dim
		return mesh
	return beveled_box(dim, b)


## A chamfered box is three families of face: six inset rectangles where the
## original faces were, twelve quads spanning the original edges, and eight
## triangles at the original corners. No UVs are written, because the
## materials on these tools are triplanar and generate their own.
static func beveled_box(dim: Vector3, b: float) -> ArrayMesh:
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

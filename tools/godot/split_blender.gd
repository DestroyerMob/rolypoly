extends SceneTree

const ASSET_DIR := "res://assets/models/obstacles/blender/"
const BLADE_REGION := AABB(Vector3(-0.0042, -0.0042, 0.0042), Vector3(0.0084, 0.0084, 0.0011))

var _parents: Dictionary[Vector3i, Vector3i] = {}


func _initialize() -> void:
	var source := load(ASSET_DIR + "Blender.fbx").instantiate() as Node3D
	var original := source.find_children("*", "MeshInstance3D")[0] as MeshInstance3D
	var mesh := original.mesh
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for face in range(0, indices.size(), 3):
			var first := _key(vertices[indices[face]])
			for corner in range(3):
				_parents[_root(_key(vertices[indices[face + corner]]))] = _root(first)

	var is_blade: Dictionary[Vector3i, bool] = {}
	var is_lid: Dictionary[Vector3i, bool] = {}
	for surface in range(mesh.get_surface_count()):
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var component := _root(_key(vertex))
			is_blade[component] = is_blade.get(component, true) and BLADE_REGION.has_point(vertex)
			is_lid[component] = is_lid.get(component, true) and vertex.z > 0.0263

	var housing_mesh := ArrayMesh.new()
	var blade_mesh := ArrayMesh.new()
	var lid_mesh := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var housing_indices := PackedInt32Array()
		var blade_indices := PackedInt32Array()
		var lid_indices := PackedInt32Array()
		for face in range(0, indices.size(), 3):
			if is_blade[_root(_key(vertices[indices[face]]))]:
				blade_indices.append_array(indices.slice(face, face + 3))
			elif is_lid[_root(_key(vertices[indices[face]]))]:
				lid_indices.append_array(indices.slice(face, face + 3))
			else:
				housing_indices.append_array(indices.slice(face, face + 3))
		_append_surface(housing_mesh, arrays, housing_indices, mesh.surface_get_material(surface))
		_append_surface(blade_mesh, arrays, blade_indices, mesh.surface_get_material(surface))
		_append_surface(lid_mesh, arrays, lid_indices, mesh.surface_get_material(surface))

	if blade_mesh.get_surface_count() == 0 or housing_mesh.get_surface_count() == 0 or lid_mesh.get_surface_count() == 0:
		push_error("Blender source geometry changed; could not separate the blade and lid.")
		source.free()
		quit(1)
		return

	if ResourceSaver.save(housing_mesh, ASSET_DIR + "housing.res") != OK or ResourceSaver.save(blade_mesh, ASSET_DIR + "blade.res") != OK:
		quit(1)
		return
	housing_mesh.take_over_path(ASSET_DIR + "housing.res")
	blade_mesh.take_over_path(ASSET_DIR + "blade.res")
	if ResourceSaver.save(lid_mesh, ASSET_DIR + "lid.res") != OK:
		quit(1)
		return
	lid_mesh.take_over_path(ASSET_DIR + "lid.res")
	var housing_collision := housing_mesh.create_trimesh_shape()
	housing_collision.set_faces(original.transform * housing_collision.get_faces())
	housing_collision.backface_collision = true
	if ResourceSaver.save(housing_collision, ASSET_DIR + "housing_collision.res") != OK:
		quit(1)
		return
	print("Separated blade bounds: ", blade_mesh.get_aabb())
	var model := Node3D.new()
	model.name = "BlenderModel"
	var housing := MeshInstance3D.new()
	housing.name = "Housing"
	housing.mesh = housing_mesh
	housing.transform = original.transform
	model.add_child(housing)
	housing.owner = model
	var lid := MeshInstance3D.new()
	lid.name = "Lid"
	lid.mesh = lid_mesh
	lid.transform = original.transform
	model.add_child(lid)
	lid.owner = model
	var pivot := Node3D.new()
	pivot.name = "BladePivot"
	pivot.position = original.transform * Vector3(0, 0, 0.0048618)
	model.add_child(pivot)
	pivot.owner = model
	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	blade.mesh = blade_mesh
	blade.transform = pivot.transform.affine_inverse() * original.transform
	pivot.add_child(blade)
	blade.owner = model
	var scene := PackedScene.new()
	var result := scene.pack(model)
	if result == OK:
		result = ResourceSaver.save(scene, ASSET_DIR + "blender_model.tscn")
	print("Saved blender model with separate housing, lid, and blade: ", error_string(result))
	source.free()
	model.free()
	quit(0 if result == OK else 1)


func _key(vertex: Vector3) -> Vector3i:
	return Vector3i((vertex * 10000000.0).round())


func _root(vertex: Vector3i) -> Vector3i:
	if not _parents.has(vertex):
		_parents[vertex] = vertex
	var current := vertex
	while _parents[current] != current:
		_parents[current] = _parents[_parents[current]]
		current = _parents[current]
	return current


func _append_surface(target: ArrayMesh, arrays: Array, indices: PackedInt32Array, material: Material) -> void:
	if indices.is_empty():
		return
	var subset := ArrayMesh.new()
	var selected := arrays.duplicate()
	selected[Mesh.ARRAY_INDEX] = indices
	subset.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, selected)
	var surface := SurfaceTool.new()
	surface.create_from(subset, 0)
	surface.deindex()
	surface.index()
	surface.set_material(material)
	surface.commit(target)

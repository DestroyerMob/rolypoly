extends SceneTree

# Rebuild the dynamic spoon and its hollow compound collision from the OBJ.
# godot --headless --path . --script res://tools/godot/build_wooden_spoon.gd
const ASSET_DIR := "res://assets/models/props/wooden_spoon/"
const SCENE_PATH := "res://scenes/props/wooden_spoon.tscn"


func _initialize() -> void:
	var spoon := RigidBody3D.new()
	spoon.name = "WoodenSpoon"
	spoon.mass = 2.0
	spoon.continuous_cd = true
	spoon.physics_material_override = PhysicsMaterial.new()
	spoon.physics_material_override.friction = 0.65
	var model := MeshInstance3D.new()
	model.name = "Model"
	model.mesh = load(ASSET_DIR + "wooden-spoon.obj")
	model.scale = Vector3.ONE * 0.45
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ASSET_DIR + "base_color.png")
	material.normal_enabled = true
	material.normal_texture = load(ASSET_DIR + "normal.png")
	material.roughness_texture = load(ASSET_DIR + "roughness.png")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	model.material_override = material
	spoon.add_child(model)
	model.owner = spoon
	# Small solid sections preserve the shallow bowl; a single hull fills it in.
	var faces := model.mesh.get_faces()
	for vertex in range(faces.size()):
		faces[vertex] *= 0.45
	var index := 0
	for x_index in range(8):
		for z_index in range(4):
			var x_min := -4.4 + x_index * 0.4
			var z_min := -0.8 + z_index * 0.4
			index = _add_section(spoon, faces, x_min, x_min + 0.4, z_min, z_min + 0.4, index)
	index = _add_section(spoon, faces, -1.2, 4.5, -0.8, 0.8, index)
	var packed := PackedScene.new()
	var error := packed.pack(spoon)
	if error == OK:
		error = ResourceSaver.save(packed, SCENE_PATH)
	spoon.free()
	if error != OK:
		push_error("Could not save wooden spoon: %s" % error_string(error))
		quit(1)
		return
	print("Saved dynamic wooden spoon with %d convex collision pieces." % index)
	quit()


func _add_section(spoon: RigidBody3D, faces: PackedVector3Array, x_min: float, x_max: float, z_min: float, z_max: float, index: int) -> int:
	var points := PackedVector3Array()
	for face in range(0, faces.size(), 3):
		var polygon := faces.slice(face, face + 3)
		polygon = _clip(polygon, 0, x_min, true)
		polygon = _clip(polygon, 0, x_max, false)
		polygon = _clip(polygon, 2, z_min, true)
		polygon = _clip(polygon, 2, z_max, false)
		points.append_array(polygon)
	if points.size() < 4:
		return index
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	shape.margin = 0.005
	var collision := CollisionShape3D.new()
	collision.name = "Collision%02d" % index
	collision.shape = shape
	spoon.add_child(collision)
	collision.owner = spoon
	return index + 1


func _clip(polygon: PackedVector3Array, axis: int, boundary: float, greater: bool) -> PackedVector3Array:
	var result := PackedVector3Array()
	if polygon.is_empty():
		return result
	var previous := polygon[-1]
	var previous_inside := previous[axis] >= boundary if greater else previous[axis] <= boundary
	for current in polygon:
		var current_inside := current[axis] >= boundary if greater else current[axis] <= boundary
		if current_inside != previous_inside:
			var ratio := (boundary - previous[axis]) / (current[axis] - previous[axis])
			result.append(previous.lerp(current, ratio))
		if current_inside:
			result.append(current)
		previous = current
		previous_inside = current_inside
	return result

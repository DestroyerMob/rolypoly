extends SceneTree

const COREXY := "res://assets/models/props/corexy/"
const DICER_PATH := "res://scenes/props/razor_dicer.tscn"
const MACHINE_PATH := "res://scenes/props/corexy.tscn"
var _failed := false
var _blade_mesh_saved := false


func _initialize() -> void:
	_build_dicer()
	if not _failed:
		_build_machine()
	quit(1 if _failed else 0)


func _own(parent: Node, node: Node, root: Node) -> void:
	parent.add_child(node)
	node.owner = root


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _visual(root: Node3D, title: String, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.position = position
	node.material_override = material
	_own(root, node, root)
	return node


func _box(root: Node3D, title: String, size: Vector3, position: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_visual(root, title, mesh, position, material)
	_box_collision(root, title + "Collision", size, Transform3D(Basis.IDENTITY, position))


func _box_collision(root: Node3D, title: String, size: Vector3, transform: Transform3D) -> void:
	var collision := CollisionShape3D.new()
	collision.name = title
	var shape := BoxShape3D.new()
	shape.size = size
	shape.margin = 0.002
	collision.shape = shape
	collision.transform = transform
	_own(root, collision, root)


func _build_dicer() -> void:
	var dicer := AnimatableBody3D.new()
	dicer.name = "RazorDicer"
	dicer.sync_to_physics = false
	dicer.set_script(load("res://scripts/props/razor_dicer.gd"))
	var steel := _material(Color(0.31, 0.38, 0.43), 0.75, 0.28)
	var brass := _material(Color(0.95, 0.48, 0.09), 0.55, 0.3)
	for inner in [false, true]:
		var wall := CylinderMesh.new()
		wall.top_radius = 0.83 if inner else 0.93
		wall.bottom_radius = wall.top_radius
		wall.height = 0.6
		wall.radial_segments = 64
		wall.cap_top = false
		wall.cap_bottom = false
		wall.flip_faces = inner
		_visual(dicer, "InnerWall" if inner else "OuterWall", wall, Vector3(0, -0.3, 0), steel)
	for height in [0.0, -0.6]:
		var rim := TorusMesh.new()
		rim.inner_radius = 0.83
		rim.outer_radius = 0.93
		rim.rings = 64
		rim.ring_segments = 12
		_visual(dicer, "TopRim" if height > -0.5 else "BottomRim", rim, Vector3(0, height, 0), brass)
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		var center := Vector3(sin(angle) * 0.88, -0.3, cos(angle) * 0.88)
		_box_collision(dicer, "WallCollision%02d" % index, Vector3(0.184, 0.7, 0.1), Transform3D(Basis(Vector3.UP, angle), center))
	var razor: PackedScene = load("res://assets/models/props/razor_blade/razor_blade.glb")
	for axis in range(2):
		for row in range(5):
			var offset := float(row - 2) * 0.28
			var length := 2.0 * sqrt(0.87 * 0.87 - offset * offset)
			var blade := razor.instantiate() as Node3D
			blade.name = "Blade%s%d" % ["X" if axis == 0 else "Z", row + 1]
			_strip_physics(blade)
			blade.transform = Transform3D(
				Basis(Vector3.UP, axis * PI / 2.0) * Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(length / 2.721743, 6.0, 0.24 / 1.4058)),
				Vector3(0, -0.52, offset) if axis == 0 else Vector3(offset, -0.52, 0)
			)
			_own(dicer, blade, dicer)
			_own_descendants(blade, dicer)
	var trigger := Area3D.new()
	trigger.name = "BladeTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.monitorable = false
	_own(dicer, trigger, dicer)
	var collision := CollisionShape3D.new()
	collision.name = "AllBlades"
	collision.position.y = -0.52
	var trigger_shape := CylinderShape3D.new()
	trigger_shape.radius = 0.84
	trigger_shape.height = 0.24
	collision.shape = trigger_shape
	_own(trigger, collision, dicer)
	var outlet := Marker3D.new()
	outlet.name = "Outlet"
	outlet.position.y = -0.8
	_own(dicer, outlet, dicer)
	_save(dicer, DICER_PATH)
	dicer.free()


func _strip_physics(node: Node) -> void:
	node.scene_file_path = ""
	if node is MeshInstance3D and not _blade_mesh_saved:
		var path := "res://assets/models/props/razor_blade/razor_blade_visual.res"
		var error := ResourceSaver.save(node.mesh, path)
		if error == OK:
			node.mesh.take_over_path(path)
			_blade_mesh_saved = true
		else:
			push_error("Could not save blade mesh: %s" % error_string(error))
			_failed = true
	for child in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D:
			child.free()
		else:
			_strip_physics(child)


func _own_descendants(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own_descendants(child, root)


func _build_machine() -> void:
	var machine := Node3D.new()
	machine.name = "CoreXY"
	machine.set_script(load("res://scripts/props/corexy.gd"))
	var frame: Node3D = load(COREXY + "corexy_frame.glb").instantiate()
	frame.name = "Frame"
	_own(machine, frame, machine)
	for part in ["Gantry", "Carriage"]:
		var body := AnimatableBody3D.new()
		body.name = part
		body.sync_to_physics = false
		body.position = Vector3(-0.401713 if part == "Carriage" else 0.0, 0.0, -1.002853)
		_own(machine, body, machine)
		if part == "Gantry":
			var model: Node3D = load(COREXY + "corexy_gantry.glb").instantiate()
			model.name = "Model"
			_own(body, model, machine)
			_add_mesh_collision(model, Transform3D.IDENTITY, body, machine)
			_add_rods(body, machine)
		else:
			var mount_material := _material(Color(0.18, 0.23, 0.27), 0.7, 0.3)
			for side in [-1.0, 1.0]:
				var prefix := "Left" if side < 0 else "Right"
				for height in [1.731, 2.122]:
					_box(body, prefix + ("LowerBearing" if height < 2 else "UpperBearing"), Vector3(0.25, 0.23, 0.28), Vector3(side * 0.94, height, 0), mount_material)
			for child in body.get_children():
				child.owner = machine
			var socket := Marker3D.new()
			socket.name = "AttachmentSocket"
			socket.position = Vector3(0, 2.3, 0)
			_own(body, socket, machine)
			var attachment: Node3D = load(DICER_PATH).instantiate()
			attachment.name = "RazorDicer"
			_own(socket, attachment, machine)
	_save(machine, MACHINE_PATH)
	machine.free()


func _add_rods(gantry: AnimatableBody3D, machine: Node3D) -> void:
	var material := _material(Color(0.65, 0.72, 0.78), 0.8, 0.22)
	for side in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		var outer: float = side * 3.82
		var inner: float = -0.401713 + side * 0.94
		var length := absf(outer - inner)
		for height in [1.731, 2.122]:
			var rod := AnimatableBody3D.new()
			rod.name = prefix + ("LowerRod" if height < 2.0 else "UpperRod")
			rod.sync_to_physics = false
			rod.position = Vector3((outer + inner) / 2.0, height, 0)
			_own(gantry, rod, machine)
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.078
			mesh.bottom_radius = 0.078
			mesh.height = 1.0
			mesh.radial_segments = 24
			var visual := _visual(rod, "Mesh", mesh, Vector3.ZERO, material)
			visual.rotation.z = PI / 2.0
			visual.scale.y = length
			_box_collision(rod, "CollisionShape3D", Vector3(length, 0.156, 0.156), Transform3D.IDENTITY)
			rod.get_node("CollisionShape3D").shape.resource_local_to_scene = true
			for child in rod.get_children():
				child.owner = machine


func _add_mesh_collision(node: Node3D, parent_transform: Transform3D, body: AnimatableBody3D, root: Node) -> void:
	var local := parent_transform * node.transform
	if node is MeshInstance3D:
		var collision := CollisionShape3D.new()
		collision.name = "MechanicalCollision"
		collision.shape = node.mesh.create_trimesh_shape()
		var path := COREXY + "corexy_" + str(body.name).to_lower() + "_collision.res"
		var error := ResourceSaver.save(collision.shape, path)
		if error != OK:
			push_error("Could not save machine collision: %s" % error_string(error))
			_failed = true
		else:
			collision.shape.take_over_path(path)
		collision.transform = local
		_own(body, collision, root)
	for child in node.get_children():
		if child is Node3D:
			_add_mesh_collision(child, local, body, root)


func _save(node: Node, path: String) -> void:
	var scene := PackedScene.new()
	var error := scene.pack(node)
	if error == OK:
		error = ResourceSaver.save(scene, path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		_failed = true
	else:
		print("Saved ", path)

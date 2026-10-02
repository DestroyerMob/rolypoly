extends Node3D
signal completed
const Catalog = preload("res://scripts/level_editor/catalog.gd")
const PICK_LAYER := 1 << 19
var objects: Array[Node3D] = []
var rig: PlayerRig
var mount: GadgetMount
var play_camera: Camera3D
var start_position := Vector3.ZERO
var fall_height := -30.0
var _finished := false

func build(document: Dictionary, editing: bool) -> void:
	if editing:
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		for entry in document.objects:
			if entry.id == "spawn":
				start_position = Catalog.vector(entry.position)
		_create_player()
	for index in document.objects.size():
		var entry: Dictionary = document.objects[index]
		var node := Catalog.instantiate(entry, mount)
		node.set_meta("level_index", index)
		add_child(node)
		objects.append(node)
		fall_height = minf(fall_height, node.position.y - 30.0)
		if editing:
			freeze_for_edit(node)
			add_pick_body(node)
		elif node.has_signal("level_completed"):
			node.connect("level_completed", _on_completed)
	if not editing:
		_update_spawn(rig.current_player)
		rig.current_player.respawn(rig.current_player.spawn_position)

func _create_player() -> void:
	rig = PlayerRig.new()
	rig.name = "PlayerRig"
	var player: Player = preload("res://packed_scenes/player_onion.tscn").instantiate()
	player.position = start_position + Vector3.UP * 2.2
	rig.add_child(player)
	var pivot := CameraPivot.new()
	pivot.name = "CameraPivot"
	pivot.player_rig = rig
	pivot.position = player.position
	pivot.follow_offset = Vector3(0, 1.5, 0)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 25.0
	arm.margin = 0.5
	pivot.add_child(arm)
	play_camera = Camera3D.new()
	play_camera.name = "Camera3D"
	play_camera.far = 3000
	arm.add_child(play_camera)
	rig.add_child(pivot)
	mount = GadgetMount.new()
	mount.name = "GadgetMount"
	mount.player_rig = rig
	mount.camera = play_camera
	rig.add_child(mount)
	add_child(rig)
	rig.player_swapped.connect(_update_spawn)
	play_camera.make_current()

func _update_spawn(player: Player) -> void:
	# Older character scenes still use the marble's default clearance.
	var shape := player.get_node("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape != null:
		var bounds: AABB = shape.transform * shape.shape.get_debug_mesh().get_aabb()
		player.spawn_clearance = maxf(0.1, -bounds.position.y) + 0.05
	player.spawn_position = start_position + Vector3.UP * player.spawn_clearance

func _physics_process(_delta: float) -> void:
	if rig != null and is_instance_valid(rig.current_player) and not _finished:
		if rig.current_player.global_position.y < fall_height:
			rig.current_player.respawn(rig.current_player.spawn_position)

func _on_completed(_player: Player) -> void:
	if not _finished:
		_finished = true
		completed.emit.call_deferred()

static func freeze_for_edit(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is RigidBody3D:
		node.freeze = true
	if node is Area3D:
		node.monitoring = false
		node.monitorable = false
	if node is CollisionObject3D:
		node.collision_mask = 0
	if node is GPUParticles3D or node is CPUParticles3D:
		node.emitting = false
	if node is AudioStreamPlayer3D or node is AudioStreamPlayer:
		node.stop()
	for child in node.get_children():
		freeze_for_edit(child)

static func bounds_of(root: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	var candidates: Array[Node] = [root]
	candidates.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for node in candidates:
		if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
			var relative: Transform3D = root.global_transform.affine_inverse() * node.global_transform
			var part: AABB = relative * node.get_aabb()
			bounds = bounds.merge(part) if found else part
			found = true
	return bounds if found else AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))

static func add_pick_body(root: Node3D) -> void:
	var bounds := bounds_of(root)
	var body := StaticBody3D.new()
	body.name = "EditorPickBody"
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bounds.size.max(Vector3.ONE * 0.2)
	collision.shape = shape
	collision.position = bounds.get_center()
	body.add_child(collision)
	root.add_child(body)

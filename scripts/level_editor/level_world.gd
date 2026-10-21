extends Node3D
signal completed
signal lost
const Catalog = preload("res://scripts/level_editor/catalog.gd")
const PICK_LAYER := 1 << 19
var objects: Array[Node3D] = []
var watchers: Array = []
var links: MeshInstance3D
var rig: PlayerRig
var mount: GadgetMount
var play_camera: Camera3D
var brawl: FreeForAll
var start_position := Vector3.ZERO
var fall_height := -140.0
var _lowest := INF
var _finished := false

func build(document: Dictionary, editing: bool) -> void:
	if editing:
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		for entry in document.objects:
			if entry.id == "spawn":
				start_position = Catalog.vector(entry.position)
		_create_player(Catalog.player_of(document))
	for index in document.objects.size():
		var entry: Dictionary = document.objects[index]
		var node := Catalog.instantiate(entry, mount)
		node.set_meta("level_index", index)
		var preview := node.get_node_or_null("EditorPreview") as Node3D
		if preview != null:
			preview.visible = editing
			if editing and entry.id == "spawn":
				preview.add_child(character_preview(Catalog.player_of(document)))
			elif editing and entry.id == "npc":
				preview.add_child(character_preview(node.character_key()))
		add_child(node)
		objects.append(node)
		fall_height = minf(fall_height, node.position.y - 30.0)
		_lowest = minf(_lowest, node.position.y)
		if editing:
			freeze_for_edit(node)
			add_pick_body(node)
		elif entry.id == "goal":
			node.connect("level_completed", _on_completed)
		elif entry.id == "npc":
			node.spawn.call_deferred(Catalog.PLAYERS[node.character_key()].scene)
	if editing:
		draw_links(document)
	else:
		_wire_watchers(document)
		if Catalog.mode_of(document) == "ffa":
			_start_match()
		_update_spawn(rig.current_player)
		rig.current_player.respawn(rig.current_player.spawn_position)

func node_of_uid(document: Dictionary, uid: int) -> Node3D:
	for index in document.objects.size():
		if int(document.objects[index].get("uid", 0)) == uid:
			return objects[index]
	return null

func _wire_watchers(document: Dictionary) -> void:
	for index in document.objects.size():
		var entry: Dictionary = document.objects[index]
		if entry.id != "watcher":
			continue
		var watcher: Variant = objects[index]
		for target in entry.get("targets", []):
			var node := node_of_uid(document, int(target.uid))
			if node != null:
				var target_index: int = node.get_meta("level_index")
				watcher.targets.append({"node": node, "id": document.objects[target_index].id,
					"action": target.action, "mode": target.mode})
		watcher.source_uid = int(entry.get("source", 0))
		watchers.append(watcher)
	if watchers.is_empty():
		return
	rig.current_player.died.connect(func():
		for watcher in watchers:
			watcher.player_died()
	)
	for index in document.objects.size():
		var entry: Dictionary = document.objects[index]
		if entry.id == "goal":
			objects[index].connect("npc_finished", func(_npc: NPC):
				for watcher in watchers:
					watcher.npc_finished()
			)
		elif entry.id == "scale":
			var uid := int(entry.get("uid", 0))
			objects[index].connect("weight_changed", func(weight: float, _id: StringName):
				for watcher in watchers:
					watcher.scale_weighed(weight, uid)
			)

func _start_match() -> void:
	brawl = FreeForAll.new()
	brawl.name = "FreeForAll"
	brawl.kill_height = _lowest - 30.0
	add_child(brawl)
	brawl.match_won.connect(func(winner: Player):
		if winner == rig.current_player:
			_on_completed(winner)
		else:
			_on_lost()
	)
	rig.current_player.eliminated.connect(_on_lost)

func _on_lost() -> void:
	if not _finished:
		_finished = true
		lost.emit.call_deferred()

func draw_links(document: Dictionary) -> void:
	if is_instance_valid(links):
		links.free()
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	var drawn := false
	for index in document.objects.size():
		var entry: Dictionary = document.objects[index]
		if entry.id != "watcher":
			continue
		var from := objects[index].global_transform * bounds_of(objects[index]).get_center()
		var ends: Array = []
		for target in entry.get("targets", []):
			ends.append([node_of_uid(document, int(target.uid)), Color(0.75, 0.6, 1)])
		if entry.has("source"):
			ends.append([node_of_uid(document, int(entry.source)), Color(0.4, 0.95, 0.75)])
		for end in ends:
			if end[0] == null:
				continue
			if not drawn:
				mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
				drawn = true
			mesh.surface_set_color(end[1])
			mesh.surface_add_vertex(from)
			mesh.surface_add_vertex(end[0].global_transform * bounds_of(end[0]).get_center())
	if drawn:
		mesh.surface_end()
	links = MeshInstance3D.new()
	links.name = "WatcherLinks"
	links.mesh = mesh
	links.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(links)

func _create_player(character: String) -> void:
	rig = PlayerRig.new()
	rig.name = "PlayerRig"
	rig.allow_character_swap = false
	var player: Player = Catalog.PLAYERS[character].scene.instantiate()
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
	player.spawn_position = start_position + Vector3.UP * player.spawn_clearance

func _physics_process(_delta: float) -> void:
	if _finished:
		return
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		if player.global_position.y < fall_height:
			player.die()

func _on_completed(_player: Player) -> void:
	if not _finished:
		_finished = true
		completed.emit.call_deferred()

static func character_preview(character: String) -> Node3D:
	var player: Player = Catalog.PLAYERS[character].scene.instantiate()
	var model := Node3D.new()
	model.name = "Character"
	model.position = Vector3.UP * maxf(player.spawn_clearance, player.get_collision_clearance() + 0.05)
	for node in player.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		var relative := Transform3D.IDENTITY
		var shown := source.mesh != null
		var current: Node3D = source
		while current != player:
			shown = shown and current.visible
			relative = current.transform * relative
			current = current.get_parent_node_3d()
		if not shown:
			continue
		var visual := MeshInstance3D.new()
		visual.mesh = source.mesh
		visual.transform = relative
		visual.material_override = source.material_override
		for surface in source.get_surface_override_material_count():
			visual.set_surface_override_material(surface, source.get_surface_override_material(surface))
		model.add_child(visual)
	player.free()
	return model

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
	body.process_mode = Node.PROCESS_MODE_ALWAYS
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bounds.size.max(Vector3.ONE * 0.2)
	collision.shape = shape
	collision.position = bounds.get_center()
	body.add_child(collision)
	root.add_child(body)

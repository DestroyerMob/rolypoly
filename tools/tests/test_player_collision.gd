extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func wait_physics(frames: int) -> void:
	for frame in frames:
		await physics_frame
		await process_frame

func make_box(parent: Node, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body

func visual_bottom(player: Player) -> float:
	var bottom := INF
	for model in player.find_children("*", "MeshInstance3D", true, false):
		if model.mesh == null or not model.is_visible_in_tree():
			continue
		for surface in model.mesh.get_surface_count():
			for point in model.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				bottom = minf(bottom, (model.global_transform * point).y)
	return bottom

func test_tables() -> void:
	for path in ["res://scenes/props/table_tapered.tscn", "res://scenes/props/bench_tapered.tscn"]:
		var table: Node3D = load(path).instantiate()
		root.add_child(table)
		for scene in PlayerRig.CHARACTERS.values():
			var player: Player = scene.instantiate()
			player.position = Vector3(0, 8.5 + player.get_collision_clearance(), 0)
			player.axis_lock_angular_x = true
			player.axis_lock_angular_y = true
			player.axis_lock_angular_z = true
			root.add_child(player)
			player.set_physics_process(false)
			await wait_physics(90)
			check(player.on_ground, "%s must support %s." % [path, scene.resource_path])
			check(visual_bottom(player) >= 7.92, "%s clips into %s: bottom=%s." % [scene.resource_path, path, visual_bottom(player)])
			if scene == PlayerRig.CHARACTERS.swap_character_3:
				check(visual_bottom(player) <= 8.08, "The resized tomato's collider must let its model rest against the tabletop.")
			player.free()
		table.free()

func test_fast_impacts() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	make_box(fixture, Vector3(0, -0.025, 0), Vector3(40, 0.05, 40))
	await wait_physics(2)
	for scene in PlayerRig.CHARACTERS.values():
		var player: Player = scene.instantiate()
		player.position = Vector3(0, 10, 0)
		player.gravity_scale = 0.0
		root.add_child(player)
		player.set_physics_process(false)
		player.linear_velocity = Vector3(0, -900, 0)
		await wait_physics(3)
		check(player.global_position.y > 0.0, "%s passed through a thin surface at high speed." % scene.resource_path)
		player.free()
	fixture.free()

func test_swaps() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	make_box(fixture, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	var rig := PlayerRig.new()
	var onion: Player = PlayerRig.CHARACTERS.swap_character_1.instantiate()
	onion.position = Vector3(0, 1.05, 0)
	rig.add_child(onion)
	fixture.add_child(rig)
	onion.set_physics_process(false)
	await wait_physics(60)
	check(onion.on_ground, "The swap test must begin on the table.")
	var spawn := onion.spawn_position - Vector3.UP * onion.spawn_clearance
	rig.swap_to(PlayerRig.CHARACTERS.swap_character_4)
	check(rig.current_player != onion, "There must be room to swap from onion to ice cream on an open table.")
	check(visual_bottom(rig.current_player) >= -0.08, "Swapping to a larger character must lift its visible body above the table.")
	check((rig.current_player.spawn_position - Vector3.UP * rig.current_player.spawn_clearance).is_equal_approx(spawn), "A swap must preserve the respawn surface.")
	rig.current_player.set_physics_process(false)
	await wait_physics(30)
	check(visual_bottom(rig.current_player) >= -0.08, "The larger character must stay above the table after physics settles.")
	# In open air, rotation and momentum should remain exactly as they were.
	var rotation := Basis.from_euler(Vector3(0.4, 0.7, -0.3))
	rig.current_player.global_transform = Transform3D(rotation, Vector3(50, 20, 0))
	rig.current_player.on_ground = false
	rig.current_player.linear_velocity = Vector3(1, 2, 3)
	rig.current_player.angular_velocity = Vector3(3, 2, 1)
	rig.swap_to(PlayerRig.CHARACTERS.swap_character_2)
	check(rig.current_player.global_transform.is_equal_approx(Transform3D(rotation, Vector3(50, 20, 0))), "An airborne swap must preserve the transform.")
	check(rig.current_player.linear_velocity.is_equal_approx(Vector3(1, 2, 3)), "A swap must preserve linear velocity.")
	check(rig.current_player.angular_velocity.is_equal_approx(Vector3(3, 2, 1)), "A swap must preserve angular velocity.")
	# An onion fits under this shelf; ice cream does not.
	rig.current_player.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.05, 0))
	rig.current_player.on_ground = false
	rig.swap_to(PlayerRig.CHARACTERS.swap_character_1)
	rig.current_player.set_physics_process(false)
	var ceiling := make_box(fixture, Vector3(0, 3, 0), Vector3(20, 0.1, 20))
	await wait_physics(60)
	var before := rig.current_player
	rig.swap_to(PlayerRig.CHARACTERS.swap_character_4)
	check(rig.current_player == before and is_instance_valid(before), "A swap underneath furniture must keep the original player if the larger character does not fit.")
	ceiling.free()
	fixture.free()
	await wait_physics(2)

func test_spawn_clearance() -> void:
	for scene in PlayerRig.CHARACTERS.values():
		var player: Player = scene.instantiate()
		root.add_child(player)
		check(player.spawn_clearance >= player.get_collision_clearance() + 0.049, "%s must calculate safe clearance outside the level editor." % scene.resource_path)
		check(player.continuous_cd, "%s must use continuous collision detection in every scene." % scene.resource_path)
		player.free()
	var onion: Player = PlayerRig.CHARACTERS.swap_character_1.instantiate()
	check(is_equal_approx(onion.get_collision_clearance(Basis.from_euler(Vector3(0.5, 0.3, 0.8))), 1.0), "Rolling a sphere must not inflate its support distance.")
	onion.free()

func test_tomato_size() -> void:
	var onion: Player = PlayerRig.CHARACTERS.swap_character_1.instantiate()
	var tomato: Player = PlayerRig.CHARACTERS.swap_character_3.instantiate()
	root.add_child(onion)
	root.add_child(tomato)
	var widths: Array[float] = []
	for player in [onion, tomato]:
		var bounds := AABB()
		var found := false
		for model in player.find_children("*", "MeshInstance3D", true, false):
			if model.mesh != null and model.is_visible_in_tree():
				var part: AABB = model.global_transform * model.get_aabb()
				bounds = bounds.merge(part) if found else part
				found = true
		widths.append(bounds.size.x)
	check(widths[1] > widths[0] * 0.8 and widths[1] < widths[0], "The tomato must be slightly smaller than the onion, rather than several times larger.")
	print("Player widths: onion=%.3f, tomato=%.3f" % [widths[0], widths[1]])
	onion.free()
	tomato.free()

func _run() -> void:
	await test_tables()
	await test_fast_impacts()
	await test_swaps()
	test_spawn_clearance()
	test_tomato_size()
	print("Player collision tests: ", failures, " failure(s).")
	quit(1 if failures > 0 else 0)

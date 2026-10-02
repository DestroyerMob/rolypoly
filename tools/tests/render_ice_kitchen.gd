extends SceneTree

func _initialize() -> void:
	call_deferred("render_preview")

func render_preview() -> void:
	var scene := load("res://scenes/levels/ice_block_kitchen.tscn").instantiate() as Node3D
	scene.persist_best_score=false
	root.add_child(scene)
	current_scene=scene
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_kitchen_gameplay.png")
	scene.get_node("HUD").hide()
	var camera := scene.get_node("Camera3D") as Camera3D
	camera.set_physics_process(false)
	camera.set_process(false)
	camera.global_position=Vector3(69,66,42)
	camera.look_at(Vector3(12,2,-25))
	camera.fov=55
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_kitchen_overview.png")
	camera.global_position=Vector3(20,18,-14)
	camera.look_at(Vector3(0,3.2,-38))
	camera.fov=62
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_kitchen_hub.png")
	camera.global_position=Vector3(52,20,-13)
	camera.look_at(Vector3(34,2.6,-32))
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_kitchen_lagoon.png")
	# UI fixture only; the runtime test separately earns all three via real movement.
	scene.get_node("HUD").show()
	for id in ["freezer","lagoon","recipe"]:
		scene.collect_crystal(id)
	scene.get_node("Player").ice_amount=74.0
	scene.get_node("Player").complete()
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_kitchen_results.png")
	scene.queue_free()
	await process_frame
	quit()

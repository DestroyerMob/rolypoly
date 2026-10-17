extends SceneTree

func _initialize() -> void:
	call_deferred("render_scene")

func render_scene() -> void:
	var scene=load("res://scenes/levels/ice_block.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_block_start.png")
	var camera=scene.get_node("PlayerRig/Camera3D")
	camera.set_process(false)
	scene.get_node("PlayerRig/HUD").hide()
	camera.position=Vector3(50,43,-30)
	camera.look_at(Vector3(10,-1,-125))
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_block_route.png")
	camera.position=Vector3(10,27,-163)
	camera.look_at(Vector3(-23,14,-189))
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_block_mouth.png")
	# Inspect the actual player-follow angle, not just presentation cameras.
	var player=scene.get_node("PlayerRig/Player")
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(30,3,-125)))
	camera.initialized=false
	camera.yaw=-PI/2
	camera.route_yaw=-PI/2
	camera.pitch=deg_to_rad(-35)
	camera.set_process(true)
	scene.active_station="02 ISLAND"
	scene.get_node("PlayerRig/HUD").show()
	for i in range(60): await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_block_fork_play.png")
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(82,4,-133)))
	camera.initialized=false
	camera.yaw=0
	camera.set_process(true)
	scene.get_node("PlayerRig/HUD").show()
	for i in range(90): await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_block_sink_play.png")
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(65,8.9,-169)))
	scene.active_station="04 SERVING COUNTER"
	camera.yaw=PI/2
	camera.route_yaw=PI/2
	camera.initialized=false
	for i in range(45): await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_block_roller_play.png")
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(29,9,-189)))
	scene.active_station="05 ROLLER EXIT"
	camera.yaw=PI/2
	camera.route_yaw=PI/2
	camera.initialized=false
	for i in range(30): await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_block_hotplate_play.png")
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(-3,10,-189)))
	camera.yaw=PI/2
	camera.route_yaw=PI/2
	camera.initialized=false
	for i in range(90): await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://renders/ice_block_launcher_play.png")
	scene.queue_free()
	await process_frame
	quit()

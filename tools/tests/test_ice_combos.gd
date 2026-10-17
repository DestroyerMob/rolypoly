extends "res://tools/tests/test_ice_block.gd"

func _initialize() -> void:
	call_deferred("run_combos")

func run_combos() -> void:
	scene = load("res://scenes/levels/ice_block.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	player = scene.get_node("PlayerRig/Player")
	await frames(30)
	var fan = scene.get_node("Course/HotTrayFan/EffectZone")
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(50,3.3,-125)))
	fan.elapsed = 0
	await frames(40)
	check(not fan.blowing and absf(player.position.z+125)<.2,"calm fan does not apply invisible sideways force")
	fan.elapsed = 3.1
	await frames(1)
	check(not fan.blowing and scene.get_node("Course/HotTrayFan/WindSign").text.contains("STARTING"),"fan visibly warns before pushing")
	fan.elapsed = 4
	await frames(45)
	check(fan.blowing and player.position.z > -122.0,"active crosswind really pushes the shell toward the tray edge")
	await frames(130)
	check(player.position.distance_to(scene.checkpoint)<4,"ignoring wind on hot tray causes a recoverable fall")
	# A player waiting off the hot tray can cross during the real calm window.
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(32,3,-125)))
	await frames(60)
	for i in range(400):
		if fan.safe_seconds()>3.7: break
		await frames(1)
	player.gadget.set_amount(1)
	var hot_start := player.position
	var hot_reached := await walk_to(Vector3(64,0,-125),270)
	check(hot_reached,"timed hot shortcut clears within 4.5 seconds (%s to %s)" % [hot_start,player.position])
	check(player.gadget != null and player.gadget.amount() < .85,"hot shortcut is traversable but costs more ice")
	await step_to(Vector3(82,0,-133))
	await frames(250)
	var plate = scene.get_node("Course/SinkingPlateA")
	var ladle = scene.get_node("Course/SinkSweeper")
	# Isolate the plate's load/return test from the separate sweeping collision.
	ladle.active = false
	ladle.phase_degrees = 90
	ladle.reset_immediately()
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(79.5,3.5,-141.5)))
	await frames(70)
	check(plate.position.y < .65,"standing on a dish physically sinks it")
	await frames(180)
	check(player.position.distance_to(scene.checkpoint)<4,"staying on sinking dish reaches water and returns to sink cooler")
	await frames(150)
	check(plate.position.y>1.1,"unoccupied dish floats back for another attempt")
	# Restore live sweeping motion and deliberately enter a known bad phase.
	ladle.active = true
	for i in range(600):
		var phase: float = ladle._elapsed / ladle.swing_period * TAU
		if phase>4.30 and phase<4.34: break
		await frames(1)
	await jump_to(Vector3(79.5,0,-141.5))
	player.jump()
	var reached := await walk_to(Vector3(84,0,-150),180,8)
	check(not reached or player.position.distance_to(Vector3(84,3,-150))>4,"wrong spoon timing interrupts the second jump")
	# New raised loop: actual rotation and falling off must matter.
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(65,4.8,-189)))
	await frames(260)
	check(scene.active_station.begins_with("04"),"roller section has its own reachable recovery station")
	var roller=scene.get_node("Course/CounterRoller")
	var before_angle: float = roller._angle
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(50,8.9,-169)))
	await frames(40)
	check(player.get_colliding_bodies().has(roller.moving_part),"player stands on rotating cylinder, not a hidden flat bridge")
	check(absf(roller._angle-before_angle)>.2,"striped rolling pin actually rotates")
	await frames(340)
	check(player.position.distance_to(scene.checkpoint)<5,"unbalanced rider returns to cooler (actual %s, checkpoint %s)" % [player.position,scene.checkpoint])
	# Hot/cool phases act through the same physical surface with no extra lip.
	var hotplate=scene.get_node("Course/TimedHotplate/WalkableBoard")
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(20,9.4,-189)))
	await frames(40)
	if not player.gadget: scene.refill()
	hotplate.elapsed=0
	player.gadget.set_amount(1)
	await frames(60)
	var hot_amount: float = player.gadget.amount()
	check(hot_amount < .78,"new hotplate visibly heated phase rapidly consumes shell")
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(20,9.4,-189)))
	await frames(40)
	hotplate.elapsed=2.4
	player.gadget.set_amount(1)
	await frames(60)
	check(player.gadget.amount()>.92 and player.gadget.amount()>hot_amount+.12,"green hotplate phase only consumes ambient ice")
	var green_stripes := 0
	for stripe in hotplate.get_children():
		if stripe.name.begins_with("HeatStripe") and stripe.get_node("Mesh").material_override.albedo_color.g>.7:
			green_stripes+=1
	check(green_stripes==5,"all five heat strips show the same safe phase")
	scene.queue_free()
	await process_frame
	print("COMBO TEST FAILURES: ",failures)
	quit(1 if failures else 0)

extends SceneTree

var scene: Node3D
var player: Player
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ", message)
	if not condition: failures += 1

func frames(n: int) -> void:
	for i in range(n): await physics_frame

func walk_to(target: Vector3, limit := 1000, speed := 10.0) -> bool:
	for frame in range(limit):
		var offset: Vector3 = target - player.position
		offset.y = 0
		if offset.length() < 2.0:
			player.linear_velocity = Vector3.ZERO
			return true
		var desired: Vector3 = offset.normalized() * minf(speed, offset.length() * 2)
		var force: Vector3 = (desired - Vector3(player.linear_velocity.x, 0, player.linear_velocity.z)) * 10
		player.apply_central_force(force.limit_length(30))
		await frames(1)
	return false

func wait_for_press(press: Node) -> void:
	for i in range(600):
		if press.safe_seconds() > 2.4:
			return
		await frames(1)
	check(false,"press must provide a reachable crossing window")

func step_to(target: Vector3) -> void:
	var reached := await walk_to(target)
	check(reached,"combined route reaches %s (actual %s)" % [target, player.position])

func jump_to(target: Vector3) -> void:
	for i in range(60):
		if player.on_ground: break
		await frames(1)
	check(player.on_ground,"jump starts from a physical support")
	player.jump()
	var reached := await walk_to(target,180,8.0)
	for i in range(90):
		if player.on_ground: break
		await frames(1)
	check(reached and player.on_ground and Vector2(player.position.x-target.x,player.position.z-target.z).length()<4,"jump lands on %s (actual %s)" % [target,player.position])

func run() -> void:
	scene = load("res://scenes/levels/ice_block.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	player = scene.get_node("PlayerRig/Player")
	await frames(90)
	check(player.gadget != null and player.collider.shape is BoxShape3D, "Ethan box equipment attaches")
	check(player.position.y > -5, "spawn supported by merged Iroh kitchen")
	player.core_health = 1.45
	player.gadget.set_amount(.2)
	await frames(60)
	check(player.gadget.amount() > .42 and player.gadget.amount() < .49, "one second cooler adds approximately 25%, not instant full")
	check(is_equal_approx(player.core_health, 1.45), "re-icing never heals the scoop")
	for amount in [1.0, .5, .1]:
		player.gadget.set_amount(amount)
		var side: float = player.gadget.get_node("Model").scale.x * 64
		check(side > 4.4, "shell remains outside core at %d%%" % int(amount * 100))
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0,-1,-37)))
	await frames(5)
	player.gadget.set_amount(.8)
	await frames(60)
	check(absf(player.gadget.amount()-(.8-1.0/17.0))<.004, "partial shell loses 1/17 per second away from cooler")
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(50,3.3,-125)))
	await frames(120)
	check(player.gadget.amount() < .59, "real warm tray contact accelerates melting")
	for health in [3.0,2.5,2.0,1.5,1.0,.1,0.0]:
		player.core_health = health
		check(player.star_count() == clampi(ceili(health),0,3), "stars depend on core health %s" % health)
	player.core_health = 3
	scene.get_node("GadgetMount").unequip()
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(0,-1,-37)))
	await frames(120)
	check(player.core_health < 2.9, "bare scoop melts (only one authoritative health clock)")
	check(absf(player.core_health-2.75)<.015,"bare scoop now melts fully in 24 seconds")
	var damaged: float = player.core_health
	scene.reset_checkpoint()
	await frames(60)
	check(player.core_health <= damaged, "reset cannot recover star health")
	check(player.gadget != null and player.gadget.amount() < .4, "reset returns to gradual cooler, not free full shell")
	await frames(240)
	check(player.gadget.amount() > .99, "cooler completes the charge")
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(0,-15,-65)))
	await frames(30)
	check(player.global_position.distance_to(scene.checkpoint) < 4, "fall returns to saved cooler")
	var masher = scene.get_node("Course/TimingMasher")
	masher.reset_immediately()
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(0,.3,-80)))
	await frames(30)
	masher.trigger()
	await frames(110)
	check(player.global_position.distance_to(scene.checkpoint) < 4, "actual masher collision squashes and returns player")
	player.core_health = 3
	await frames(240)
	# Live phases, no test reset/disable of hazards during the route.
	await step_to(Vector3(0,0,-65))
	await wait_for_press(masher)
	await step_to(Vector3(0,0,-87))
	await wait_for_press(scene.get_node("Course/SecondMasher"))
	await step_to(Vector3(0,0,-111))
	await step_to(Vector3(10,0,-120))
	await frames(250)
	# Longer, cooler route must genuinely be connected and avoid the gust.
	for target in [Vector3(32,0,-125),Vector3(32,0,-105),Vector3(67,0,-105),Vector3(67,0,-125),Vector3(82,0,-133)]:
		await step_to(target)
	await frames(250)
	var ladle=scene.get_node("Course/SinkSweeper")
	# Observe from the bank; standing still on a plate is not safe.
	for i in range(400):
		var phase: float = ladle._elapsed / ladle.swing_period * TAU
		if phase > 3.25 and phase < 3.4: break
		await frames(1)
	await jump_to(Vector3(79.5,0,-141.5))
	await jump_to(Vector3(84,0,-150))
	await jump_to(Vector3(82,0,-161))
	for target in [Vector3(82,0,-181),Vector3(65,0,-189),Vector3(65,0,-169),Vector3(35,0,-169),Vector3(35,0,-189),Vector3(29,0,-189)]:
		await step_to(target)
		if target == Vector3(65,0,-189) or target == Vector3(35,0,-169): await frames(250)
	var hotplate=scene.get_node("Course/TimedHotplate/WalkableBoard")
	for i in range(400):
		if hotplate.safe_seconds()>3.1: break
		await frames(1)
	await step_to(Vector3(-3,0,-189))
	check(scene.active_station.begins_with("05"), "extended route activates fifth cooler")
	check(player.core_health>2,"continuous route still permits three-star health with faster melting")
	var camera = scene.get_node("PlayerRig/Camera3D")
	camera.toggle_free()
	var paused_health: float = player.core_health
	for i in range(10): await process_frame
	check(paused and player.core_health == paused_health, "free camera pauses melting")
	camera.toggle_free()
	var goal = scene.get_node("Course/MovingMouth")
	var launcher = scene.get_node("Course/SpringServer")
	for phase in [0.0,2.35,4.0,6.35]:
		# Fixture reset between four independent, real ballistic throws.
		goal.set_physics_process(false)
		scene.result = false
		goal.accepted = false
		player.finished = false
		player.freeze = false
		player.core_health = 1.5
		if is_instance_valid(player.gadget): player.gadget.set_physics_process(true)
		player.flight_remaining = 0
		launcher.cooldown = 0
		scene.get_node("PlayerRig/HUD/Result").hide()
		player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(-3,10,-189)))
		await frames(90)
		if phase == 6.35:
			scene.get_node("GadgetMount").unequip()
			await frames(15)
		goal.elapsed = phase
		goal._physics_process(0)
		goal.set_physics_process(true)
		check(launcher.ready_to_launch, "physical plate detects grounded player")
		if phase == 0.0:
			var event := InputEventKey.new()
			event.physical_keycode = KEY_E
			event.keycode = KEY_E
			event.pressed = true
			Input.parse_input_event(event)
			await frames(1)
			event.pressed = false
			Input.parse_input_event(event)
		else:
			launcher.launch()
		await frames(240)
		if phase in [2.35,6.35]:
			check(scene.result and goal.accepted,"timed green-window serve succeeds at phase %s" % phase)
			check(scene.get_node("PlayerRig/HUD/Result/Rows/Stars").text == "★★☆", "delivery scores scoop, not shell")
		else:
			check(not scene.result and not goal.accepted,"out-of-time serve misses; no automatic targeting")
			check(player.position.distance_to(scene.checkpoint)<4,"missed serve safely returns to last cooler")
	scene.queue_free()
	await process_frame
	scene = load("res://scenes/levels/ice_block.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	player = scene.get_node("PlayerRig/Player")
	await frames(30)
	goal = scene.get_node("Course/MovingMouth")
	goal.set_physics_process(false)
	player.teleport_to(Transform3D(Basis.IDENTITY,goal.to_global(Vector3(9,0,.5))),goal.global_basis*Vector3(0,0,-2))
	await frames(2)
	goal._physics_process(0)
	check(not scene.result,"passing outside the mouth cannot trigger completion")
	launcher = scene.get_node("Course/SpringServer")
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(-3,10,-189)))
	await frames(90)
	launcher.launch()
	await frames(5)
	scene.reset_checkpoint()
	await frames(60)
	check(not player.freeze and not launcher.busy and player.position.distance_to(scene.checkpoint)<4,"R safely cancels a charging launch")
	scene.get_node("GadgetMount").unequip()
	player.core_health = .01
	player.teleport_to(Transform3D(Basis.IDENTITY,Vector3(0,0,-37)))
	await frames(40)
	check(scene.result and not goal.accepted,"core depletion fails rather than completing")
	scene.queue_free()
	await process_frame
	print("ICE BLOCK TEST FAILURES: ", failures)
	quit(1 if failures else 0)

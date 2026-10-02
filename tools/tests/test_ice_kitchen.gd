extends SceneTree

var level: Node3D
var player: RigidBody3D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func place(p: Vector3) -> void:
	player.checkpoint = p
	player.request_reset("TEST POSITION")
	await frames(12)

func steer_to(target: Vector3, max_frames := 600) -> bool:
	# Test normal movement force on real collision geometry; never teleport a segment.
	for i in max_frames:
		var difference := target - player.global_position
		difference.y = 0
		if difference.length() < .55 or player.won:
			return true
		var desired: Vector3 = difference.normalized() * minf(4.0, difference.length() * 2)
		var velocity: Vector3 = player.linear_velocity
		velocity.y = 0
		var force := ((desired - velocity) * 5).limit_length(player.speed_force)
		player.apply_central_force(force)
		await physics_frame
	print("BLOCKED at ",player.global_position," aiming ",target)
	return false

func run() -> void:
	Engine.max_fps = 0
	level = load("res://scenes/levels/ice_block_kitchen.tscn").instantiate()
	level.persist_best_score = false
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	await frames(40)
	check(player.global_position.y > 3.4 and player.global_position.y < 4.2,"spawn stands on cold tray")
	for completed in [false, true]:
		for ice in [49.9,50.0,100.0]:
			for crystals in [0,2,3]:
				var expected := 0 if not completed else 1 + int(ice >= 50) + int(crystals >= 3)
				check(level.calculate_stars(completed,ice,crystals) == expected,"star boundary %s / %s / %s" % [completed,ice,crystals])
	await place(Vector3(0,3.9,-3))
	player.ice_amount = 80
	await frames(120)
	check(player.ice_amount < 72,"hotplate accelerates melting through real Area3D contact")
	await place(Vector3(0,3.9,-10))
	player.ice_amount = 45
	await frames(120)
	check(player.ice_amount > 98,"cold station refills")
	var saved_checkpoint: Vector3 = player.checkpoint
	await place(Vector3(-7,4.3,-42))
	await frames(45)
	check(level.collected_ids.has("freezer"),"physical pickup inside freezer")
	level.collect_crystal("freezer")
	check(level.collected_ids.size() == 1,"duplicate pickup cannot count twice")
	player.checkpoint = saved_checkpoint
	player.request_reset("TEST FALL RECOVERY")
	await frames(30)
	print("RESET POSITION ",player.global_position," expected ",saved_checkpoint," target ",player._reset_target)
	check(player.global_position.distance_to(saved_checkpoint) < 1,"checkpoint reset")
	check(level.collected_ids.size() == 1,"crystal survives reset")
	await place(Vector3(18,3.9,-45))
	check(await steer_to(Vector3(18,0,-53)),"cookery ramp alternative reaches dessert")
	await place(Vector3(0,3.9,-38))
	check(await steer_to(Vector3(0,0,-49)),"central hub ramp reaches dessert")
	await place(Vector3(36,3.85,-32))
	var floe := level.get_node("FloatingIce3") as Node3D
	var original_height := floe.position.y
	await frames(100)
	check(floe.position.y < original_height-.05,"standing on an ice floe makes it sink gently")
	await place(Vector3(25.5,3.9,-26))
	await frames(100)
	check(floe.position.y > original_height-.08,"ice floe floats back after leaving")
	# Start a fresh scene so the route must physically collect every crystal itself.
	level.queue_free()
	await process_frame
	level = load("res://scenes/levels/ice_block_kitchen.tscn").instantiate()
	level.persist_best_score = false
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	await frames(30)
	var route := [Vector3(0,0,1),Vector3(4.6,0,1),Vector3(4.6,0,-8),Vector3(5,0,-9),Vector3(4.6,0,1),Vector3(0,0,1),Vector3(0,0,-10),Vector3(0,0,-22),Vector3(1,0,-30),Vector3(1,0,-35),Vector3(-3,0,-38),Vector3(-7,0,-41),Vector3(-3,0,-38),Vector3(1,0,-35),Vector3(18,0,-35),Vector3(21.5,0,-35),Vector3(21.5,0,-24),Vector3(25.5,0,-24),Vector3(25.5,0,-27.5),Vector3(27.5,0,-27.5),Vector3(30.3,0,-29),Vector3(33.1,0,-30.5),Vector3(36,0,-32),Vector3(38.8,0,-33.5),Vector3(40.4,0,-36.3),Vector3(42.5,0,-36.3),Vector3(42.5,0,-40.5),Vector3(26,0,-40.5),Vector3(26,0,-51.5),Vector3(18,0,-53),Vector3(9,0,-53),Vector3(3,0,-56),Vector3(1.8,0,-53),Vector3(-3,0,-53)]
	for i in route.size():
		if i == 11:
			route[i] = Vector3(-7,0,-42)
		var passed := await steer_to(route[i])
		check(passed,"continuous route waypoint %d" % i)
		if not passed:
			break
	check(player.won,"main route reaches goal")
	print("FINAL SCORE ",level.stars," ICE ",player.ice_amount," CRYSTALS ",level.collected_ids)
	check(level.stars == 3,"full exploration earns three stars")
	check(level.results.visible,"results panel displayed")
	print("ICE TEST FAILURES: ",failures)
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)

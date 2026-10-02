extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+message)
	if not condition:
		failures+=1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func key(code: Key, pressed_: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed_
	Input.parse_input_event(event)

func run() -> void:
	var level = load("res://scenes/levels/ice_block_kitchen.tscn").instantiate()
	level.persist_best_score=false
	root.add_child(level)
	current_scene=level
	var player = level.get_node("Player")
	var camera = level.get_node("Camera3D")
	await frames(30)
	var start: Vector3 = player.position
	key(KEY_W,true)
	await frames(100)
	key(KEY_W,false)
	check(player.position.distance_to(start)>3.0,"physical W key moves the player")
	player.request_reset("TEST")
	await frames(80)
	start=player.position
	var yaw_before: float = camera.yaw
	key(KEY_RIGHT,true)
	await frames(30)
	key(KEY_RIGHT,false)
	check(absf(camera.yaw-yaw_before)>.2,"right arrow turns camera")
	check(player.position.distance_to(start)<.2,"arrow does not also move player")
	var pitch_before: float = camera.pitch
	key(KEY_UP,true)
	await frames(20)
	key(KEY_UP,false)
	check(camera.pitch>pitch_before,"up arrow raises view")
	key(KEY_TAB,true)
	await frames(3)
	key(KEY_TAB,false)
	check(camera.free_mode and paused,"Tab enables free view and pauses game")
	var ice_before: float = player.ice_amount
	start=player.position
	var camera_before: Vector3 = camera.position
	key(KEY_W,true)
	key(KEY_E,true)
	await frames(35)
	key(KEY_W,false)
	key(KEY_E,false)
	check(camera.position.distance_to(camera_before)>1,"W / E moves free camera")
	check(player.position.distance_to(start)<.01 and player.ice_amount==ice_before,"free view freezes player and melting")
	key(KEY_TAB,true)
	await frames(3)
	key(KEY_TAB,false)
	check(not camera.free_mode and not paused,"Tab restores gameplay")
	await frames(10)
	check(absf(camera.position.distance_to(player.position)-camera.follow_distance)<.1,"camera returns to player")
	key(KEY_D,true)
	await frames(70)
	key(KEY_D,false)
	check(player.position.distance_to(start)>1,"player moves after returning from free view")
	level.queue_free()
	await process_frame
	print("CONTROL FAILURES: ",failures)
	quit(1 if failures else 0)

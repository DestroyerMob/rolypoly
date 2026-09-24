extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_test")


func _run_test() -> void:
	var sink_scene := load("res://scenes/obstacles/sink_demo.tscn") as PackedScene
	if sink_scene == null:
		push_error("Sink test: sink scene did not load.")
		quit(1)
		return

	var sink := sink_scene.instantiate()
	root.add_child(sink)
	await process_frame

	var dish := sink.get_node("Sink/Dishes/PlateMiddle") as SinkableDish
	var player := sink.get_node("Player") as Player
	player.respawn(dish.global_position + Vector3(0.0, 1.4, 0.0))
	var rest_y := dish.position.y

	for frame in 180:
		await physics_frame
	var sunk_y := dish.position.y
	if sunk_y > rest_y - 0.55:
		push_error("Sink test: dish did not sink far enough. rest=%s sunk=%s" % [rest_y, sunk_y])
		player.queue_free()
		quit(1)
		return

	player.respawn(Vector3(0.0, 6.0, 8.0))
	for frame in 150:
		await physics_frame
	var returned_y := dish.position.y
	if absf(returned_y - rest_y) > 0.06:
		push_error("Sink test: dish did not float back. rest=%s returned=%s" % [rest_y, returned_y])
		player.queue_free()
		quit(1)
		return

	print("Sink runtime test passed: %.3f -> %.3f -> %.3f" % [rest_y, sunk_y, returned_y])
	player.queue_free()
	quit()

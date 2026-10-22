extends SceneTree

func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	var kitchen = load("res://scenes/levels/ice_block_environment.tscn").instantiate()
	kitchen.scale=Vector3.ONE*.25
	root.add_child(kitchen)
	await process_frame
	await physics_frame
	for i in range(3): await physics_frame
	for xz in [Vector2(82,-135),Vector2(82,-140),Vector2(82,-145),Vector2(82,-150),Vector2(82,-155),Vector2(82,-160),Vector2(82,-165),Vector2(82,-170),Vector2(82,-175)]:
		var query:=PhysicsRayQueryParameters3D.create(Vector3(xz.x,25,xz.y),Vector3(xz.x,-10,xz.y))
		print("SURFACE ",xz," ",kitchen.get_world_3d().direct_space_state.intersect_ray(query))
	for node in kitchen.find_children("*", "CollisionShape3D", true, false):
		if node.shape is BoxShape3D and ("Counter" in str(node.get_path()) or "Table" in str(node.get_path())):
			print(node.get_path(), " POSITION ", node.global_position, " SIZE ", node.shape.size * node.global_basis.get_scale())
	quit()

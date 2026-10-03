extends SceneTree

# Regenerate mesh-matched collision resources after changing these models.
# godot --headless --path . --script res://tools/godot/build_player_collision_shapes.gd
const MODELS := [
	["res://packed_scenes/player_tomato.tscn", "CollisionShape3D/Tomato", "CollisionShape3D", "res://models/vegetables/tomato/player_collision.tres"],
	["res://scenes/props/table_tapered.tscn", "table_tapered", ".", "res://assets/models/props/table_tapered_collision.tres"],
	["res://scenes/props/bench_tapered.tscn", "bench_tapered_smooth", ".", "res://assets/models/props/bench_tapered_collision.tres"],
]

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	for entry in MODELS:
		var instance: Node3D = load(entry[0]).instantiate()
		root.add_child(instance)
		var collision_root: Node3D = instance.get_node(entry[2])
		var points := PackedVector3Array()
		for model in instance.get_node(entry[1]).find_children("*", "MeshInstance3D", true, false):
			var relative: Transform3D = collision_root.global_transform.affine_inverse() * model.global_transform
			var hull: ConvexPolygonShape3D = model.mesh.create_convex_shape(true, false)
			for point in hull.points:
				points.append(relative * point)
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var error := ResourceSaver.save(shape, entry[3])
		instance.free()
		if error != OK:
			push_error("Could not save collision shape: %s" % entry[3])
			quit(1)
			return
		print("Saved ", entry[3], " (", points.size(), " points)")
	quit()

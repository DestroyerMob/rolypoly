extends Node3D


func _ready() -> void:
	for node in $Model.find_children("*", "MeshInstance3D"):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := mesh_instance.mesh.create_trimesh_shape()
		shape.backface_collision = true
		collider.shape = shape
		mesh_instance.add_child(body)
		body.add_child(collider)

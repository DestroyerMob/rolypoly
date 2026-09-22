extends Area3D

const ProduceBody := preload("res://scripts/produce_body.gd")

## Disable when an obstacle handles produce itself, such as the blender's burst.
@export var kills_produce := true

# Respawn without discarding tiles placed in the level builder.
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		print("You died :( ")
		body.call_deferred("respawn", body.spawn_position)
	elif kills_produce and body is ProduceBody:
		body.queue_free()

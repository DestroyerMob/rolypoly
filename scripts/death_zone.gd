extends Area3D

const ProduceBody := preload("res://scripts/produce_body.gd")

@export var kills_produce := true

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		print("You died :( ")
		body.call_deferred("respawn", body.spawn_position)
	elif kills_produce and body is ProduceBody:
		body.queue_free()

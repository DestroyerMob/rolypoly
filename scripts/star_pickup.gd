class_name StarPickup
extends Area3D

## A small collectible that counts towards the level's collect star goal. It spins in place and
## disappears when a player touches it.

@export var colour := Color(1.0, 0.45, 0.7):
	set(value):
		colour = value
		_apply_colour()
@export_range(0.0, 720.0, 1.0) var spin_degrees_per_second := 180.0

var _taken := false


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	body_entered.connect(_on_body_entered)
	_apply_colour()


func _process(delta: float) -> void:
	$Model.rotate_y(deg_to_rad(spin_degrees_per_second) * delta)


func _apply_colour() -> void:
	var model := get_node_or_null("Model/Disc") as MeshInstance3D
	if model == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 0.9
	material.roughness = 0.3
	model.material_override = material


func _on_body_entered(body: Node3D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	for goal in get_tree().get_nodes_in_group(&"star_goal"):
		if goal.has_method(&"collect"):
			goal.collect(1)
	var tween := create_tween()
	tween.tween_property($Model, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)

extends Node3D

## Seconds per full blade rotation. Smaller values spin faster; zero stops it.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var rotation_duration := 1.0
## Radius around the blade in which physics bodies are affected.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m") var force_range := 5.0
## Positive pushes along the blade's local Y axis; negative pulls.
@export var force_strength := 10.0

@onready var blade_pivot: Node3D = $Model/BladePivot
var _force_area := Area3D.new()
var _force_shape := SphereShape3D.new()


func _ready() -> void:
	_force_shape.radius = maxf(force_range, 0.001)
	var collision := CollisionShape3D.new()
	collision.shape = _force_shape
	_force_area.collision_layer = 0
	_force_area.collision_mask = 0xFFFFFFFF
	_force_area.monitorable = false
	_force_area.add_child(collision)
	blade_pivot.add_child(_force_area)


func _physics_process(_delta: float) -> void:
	if force_range <= 0.0 or force_strength == 0.0:
		return
	_force_shape.radius = force_range
	var force := blade_pivot.global_basis.y.normalized() * force_strength
	for body in _force_area.get_overlapping_bodies():
		if body is RigidBody3D:
			body.apply_central_force(force)


func _process(delta: float) -> void:
	if rotation_duration <= 0.0:
		return
	blade_pivot.rotation.y = fposmod(blade_pivot.rotation.y + TAU * delta / rotation_duration, TAU)

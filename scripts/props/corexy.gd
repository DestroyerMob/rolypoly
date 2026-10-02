extends Node3D

signal player_passed_through(player: Player)

@export_category("Dicer Motion")
@export var active := true
@export_range(0.0, 5.0, 0.1, "suffix:m/s") var travel_speed := 1.6
## Machine X/Y travel maps to Godot's horizontal X/Z plane.
@export var travel_half_extents := Vector2(2.5, 2.35)
@export var initial_direction := Vector2(1.0, 0.73)

@onready var gantry: AnimatableBody3D = $Gantry
@onready var carriage: AnimatableBody3D = $Carriage
@onready var dicer: AnimatableBody3D = $Carriage/AttachmentSocket/RazorDicer

const RAIL_END := 3.82
const MOUNT_OFFSET := 0.94
var _direction := Vector2.ZERO


func _ready() -> void:
	_direction = initial_direction.normalized()
	if _direction.is_zero_approx():
		_direction = Vector2(1.0, 0.73).normalized()
	dicer.player_passed_through.connect(func(player: Player): player_passed_through.emit(player))
	_update_rods()


func _physics_process(delta: float) -> void:
	if not active or travel_speed <= 0.0:
		return
	var extent := Vector2(
		clampf(absf(travel_half_extents.x), 0.1, 2.65),
		clampf(absf(travel_half_extents.y), 0.1, 2.45)
	)
	var point := Vector2(carriage.position.x, carriage.position.z)
	point += _direction * travel_speed * delta
	# Reflect each axis independently: both motors run throughout the sweep.
	for axis in range(2):
		while point[axis] > extent[axis] or point[axis] < -extent[axis]:
			if point[axis] > extent[axis]:
				point[axis] = 2.0 * extent[axis] - point[axis]
				_direction[axis] = -absf(_direction[axis])
			else:
				point[axis] = -2.0 * extent[axis] - point[axis]
				_direction[axis] = absf(_direction[axis])
	carriage.position = Vector3(point.x, 0.0, point.y)
	gantry.position.z = point.y
	_update_rods()


func get_travel_velocity() -> Vector3:
	if not active:
		return Vector3.ZERO
	return global_basis * Vector3(_direction.x, 0, _direction.y) * maxf(travel_speed, 0.0)


func _update_rods() -> void:
	for side in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		var outer: float = side * RAIL_END
		var inner: float = carriage.position.x + side * MOUNT_OFFSET
		var length := absf(outer - inner)
		for level in ["Lower", "Upper"]:
			var rod := gantry.get_node(prefix + level + "Rod") as AnimatableBody3D
			rod.position.x = (outer + inner) / 2.0
			rod.get_node("Mesh").scale.y = length
			var shape := rod.get_node("CollisionShape3D").shape as BoxShape3D
			shape.size = Vector3(length, 0.156, 0.156)

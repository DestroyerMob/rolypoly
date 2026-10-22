class_name IceCreamToppings
extends Node3D

## Holds the toppings stuck to the ice cream. Toppings are tiny meshes parented under the
## ball's model, so they roll with it, squash with it and shrink as it melts.

signal topping_added(topping_id: StringName, total: int)

## Most pieces kept per topping. Past this the oldest are reused.
@export_range(10, 2000) var max_per_topping := 400
## How far out the pieces sit, as a fraction of the collision sphere. The model is slightly smaller.
@export_range(0.5, 1.2, 0.01) var surface_fit := 0.95
## Strip the toppings when the ice cream is squished and respawns.
@export var lose_on_death := true

var _player: Player
var _layers := {}   # topping id -> {multimesh, stuck}
var _holder: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_warning("IceCreamToppings must be a child of a Player.")
		return
	_rng.randomize()
	_player.squished.connect(func(): if lose_on_death: clear())


## Names of the toppings currently on the ice cream.
func carried() -> Array:
	return _layers.keys()


func has_topping(topping_id: StringName) -> bool:
	return _layers.has(topping_id)


func clear() -> void:
	for id in _layers:
		var layer: Dictionary = _layers[id]
		layer.multimesh.visible_instance_count = 0
		layer.stuck = 0


## How a piece sits on the ball: lying along the surface (sprinkles), tumbled at random
## (nuts, marshmallows), or flat against it with its up axis along the surface normal (sauce).
enum Orientation { LAY, TUMBLE, FLAT }

## Sticks `count` pieces of `mesh` around the side of the ball facing `world_point`.
## `size` scales the pieces and `spread_degrees` is how wide an area they cover.
func stick_topping(topping_id: StringName, mesh: Mesh, colours: Array[Color], world_point: Vector3,
		count: int, size := 1.0, spread_degrees := 40.0, orientation := Orientation.LAY) -> void:
	if _player == null or count <= 0:
		return
	var layer := _layer_for(topping_id, mesh)
	var multimesh: MultiMesh = layer.multimesh
	var visual := _player.visual as Node3D
	var collider := _player.collider as CollisionShape3D
	var centre := collider.global_position
	var radius := (collider.shape as SphereShape3D).radius * collider.global_transform.basis.get_scale().x * surface_fit
	var to_local := visual.global_transform.affine_inverse()
	var piece_scale := size * _player.scale.x / visual.global_transform.basis.get_scale().x

	var base := (world_point - centre).normalized()
	if base.is_zero_approx():
		base = Vector3.DOWN
	for i in count:
		var direction := _scatter(base, deg_to_rad(spread_degrees))
		var normal := (to_local.basis * direction).normalized()
		var position := to_local * (centre + direction * radius)
		var basis := _orientation(normal, orientation) * Basis.from_scale(Vector3.ONE * piece_scale * _rng.randf_range(0.8, 1.2))
		var slot: int = layer.stuck % multimesh.instance_count
		multimesh.set_instance_transform(slot, Transform3D(basis, position))
		if multimesh.use_colors and not colours.is_empty():
			multimesh.set_instance_color(slot, colours[_rng.randi() % colours.size()])
		layer.stuck += 1
	multimesh.visible_instance_count = mini(layer.stuck, multimesh.instance_count)
	topping_added.emit(topping_id, multimesh.visible_instance_count)


func _scatter(direction: Vector3, spread: float) -> Vector3:
	var reference := Vector3.RIGHT if absf(direction.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
	var axis := direction.cross(reference).normalized().rotated(direction, _rng.randf() * TAU)
	return direction.rotated(axis, spread * sqrt(_rng.randf())).normalized()


func _orientation(normal: Vector3, mode: int) -> Basis:
	if mode == Orientation.FLAT:
		return Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, _rng.randf() * TAU)
	if mode == Orientation.TUMBLE:
		return Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3(_rng.randf(), _rng.randf(), _rng.randf()).normalized(), _rng.randf() * TAU)
	var reference := Vector3.RIGHT if absf(normal.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
	var along := normal.cross(reference).normalized().rotated(normal, _rng.randf() * TAU)
	return Basis(along.cross(normal), along, normal)


func _layer_for(topping_id: StringName, mesh: Mesh) -> Dictionary:
	if _layers.has(topping_id):
		return _layers[topping_id]
	if _holder == null:
		_holder = Node3D.new()
		_holder.name = "Toppings"
		(_player.visual as Node3D).add_child(_holder)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = max_per_topping
	multimesh.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.name = String(topping_id).capitalize().replace(" ", "")
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Pieces cling to the ball, so never cull the batch away.
	instance.custom_aabb = AABB(Vector3.ONE * -10.0, Vector3.ONE * 20.0)
	_holder.add_child(instance)
	var layer := {"multimesh": multimesh, "stuck": 0}
	_layers[topping_id] = layer
	return layer

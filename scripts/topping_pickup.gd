class_name ToppingPickup
extends Area3D

## A pile of topping on the floor. An ice cream rolling through it picks the pieces up and wears them. Other characters are unaffected.

enum Kind { SPRINKLES, NUTS }

@export var kind := Kind.SPRINKLES
@export var topping_id: StringName = &"sprinkles"
@export var colours: Array[Color] = [Color(0.357, 0.702, 0.278, 1.0), Color(0.812, 0.224, 0.502, 1.0), Color(0.185, 0.488, 0.793, 1.0)]
@export_range(0.2, 3.0, 0.05) var piece_size := 1.0
@export_range(1, 1000) var pieces := 150
@export_range(1.0, 600.0, 1.0) var pieces_per_second := 90.0
@export_range(5.0, 120.0, 1.0) var spread_degrees := 40.0
@export_range(0.0, 120.0, 0.5) var respawn_seconds := 0.0

const PILE_DISPLAY := 70

static var _mesh_cache := {}

var _mesh: Mesh
var _remaining := 0
var _budget := 0.0
var _refill_in := 0.0
var _pile: MultiMeshInstance3D


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	_mesh = _mesh_for(kind)
	_remaining = pieces
	_build_pile()


func _physics_process(delta: float) -> void:
	if _remaining <= 0:
		if respawn_seconds > 0.0:
			_refill_in -= delta
			if _refill_in <= 0.0:
				_remaining = pieces
				_update_pile()
		return
	for body in get_overlapping_bodies():
		var toppings := _toppings_of(body)
		if toppings == null:
			continue
		_budget += pieces_per_second * delta
		var count := mini(floori(_budget), _remaining)
		if count <= 0:
			return
		_budget -= count
		_remaining -= count
		toppings.stick_topping(topping_id, _mesh, colours, global_position, count,
				piece_size, spread_degrees, kind == Kind.SPRINKLES)
		if _remaining <= 0:
			_refill_in = respawn_seconds
		_update_pile()
		return


func _toppings_of(body: Node3D) -> Node:
	for child in body.get_children():
		if child.has_method(&"stick_topping"):
			return child
	return null


func _build_pile() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _mesh
	multimesh.instance_count = PILE_DISPLAY
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(topping_id)   # same pile every run
	var shape := ($CollisionShape3D as CollisionShape3D).shape as SphereShape3D
	var spread := shape.radius * 0.55 if shape != null else 0.8
	for i in PILE_DISPLAY:
		var angle := rng.randf() * TAU
		var distance := spread * sqrt(rng.randf())
		var lay := Basis(Vector3.UP, rng.randf() * TAU)
		if kind == Kind.SPRINKLES:
			lay = lay * Basis(Vector3.RIGHT, PI * 0.5)   # capsule lies on its side
		else:
			lay = lay * Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU)
		var scaled := lay * Basis.from_scale(Vector3.ONE * piece_size * rng.randf_range(0.8, 1.2))
		var height := 0.05 * piece_size + 0.1 * piece_size * (1.0 - distance / spread)
		multimesh.set_instance_transform(i, Transform3D(scaled, Vector3(cos(angle) * distance, height, sin(angle) * distance)))
		multimesh.set_instance_color(i, colours[rng.randi() % colours.size()] if not colours.is_empty() else Color.WHITE)
	_pile = MultiMeshInstance3D.new()
	_pile.name = "Pile"
	_pile.multimesh = multimesh
	add_child(_pile)
	_update_pile()


func _update_pile() -> void:
	var fraction := float(_remaining) / maxf(pieces, 1.0)
	_pile.multimesh.visible_instance_count = ceili(PILE_DISPLAY * fraction)


static func _mesh_for(topping_kind: Kind) -> Mesh:
	if _mesh_cache.has(topping_kind):
		return _mesh_cache[topping_kind]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	var mesh: Mesh
	if topping_kind == Kind.SPRINKLES:
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.035
		capsule.height = 0.22
		capsule.radial_segments = 8
		capsule.rings = 3
		mesh = capsule
		material.roughness = 0.3
	else:
		# A rough nut piece: a coarse, squashed sphere so the facets catch the light.
		var chunk := SphereMesh.new()
		chunk.radius = 0.1
		chunk.height = 0.15
		chunk.radial_segments = 6
		chunk.rings = 3
		mesh = chunk
		material.roughness = 0.85
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mesh.material = material
	_mesh_cache[topping_kind] = mesh
	return mesh

class_name ToppingPickup
extends Area3D

## A pile of topping on the floor. An ice cream rolling through it picks the pieces up and wears them. Other characters are unaffected.

enum Kind { SPRINKLES, NUTS, CHOC_SAUCE, MARSHMELLOW, PISTACHIO_SAUCE }

@export var kind := Kind.SPRINKLES
@export var topping_id: StringName = &"sprinkles"
@export var colours: Array[Color] = [Color(0.357, 0.702, 0.278, 1.0), Color(0.812, 0.224, 0.502, 1.0), Color(0.185, 0.488, 0.793, 1.0)]
@export_range(0.2, 3.0, 0.05) var piece_size := 1.0
@export_range(1, 1000) var pieces := 150
@export_range(1.0, 600.0, 1.0) var pieces_per_second := 90.0
@export_range(5.0, 120.0, 1.0) var spread_degrees := 40.0
@export_range(0.0, 120.0, 0.5) var respawn_seconds := 0.0
## Pieces the pile refills per second, up to `pieces`. A dripping sauce keeps its puddle topped up.
@export_range(0.0, 400.0, 1.0) var refill_per_second := 0.0
## Radius of the puddle for sauces. 0 leaves a sauce at the size of the trigger.
@export_range(0.0, 60.0, 0.5) var puddle_radius := 8.0

const PILE_DISPLAY := 70

static var _mesh_cache := {}

var _mesh: Mesh
var _remaining := 0
var _budget := 0.0
var _refill_in := 0.0
var _refill_budget := 0.0
var _pile: MultiMeshInstance3D
var _puddle: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	_mesh = _mesh_for(kind)
	_remaining = pieces
	if _is_sauce():
		_build_puddle()
	else:
		_build_pile()


func _is_sauce() -> bool:
	return kind == Kind.CHOC_SAUCE or kind == Kind.PISTACHIO_SAUCE


func _orientation() -> int:
	if _is_sauce():
		return IceCreamToppings.Orientation.FLAT
	return IceCreamToppings.Orientation.LAY if kind == Kind.SPRINKLES else IceCreamToppings.Orientation.TUMBLE


func _physics_process(delta: float) -> void:
	if refill_per_second > 0.0 and _remaining < pieces and _remaining > 0:
		_refill_budget += refill_per_second * delta
		var whole := floori(_refill_budget)
		if whole > 0:
			_refill_budget -= whole
			_remaining = mini(_remaining + whole, pieces)
			_update_pile()
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
				piece_size, spread_degrees, _orientation())
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


## Sauce sits in a glossy puddle that shrinks as it is used and grows back as it refills.
func _build_puddle() -> void:
	var shape := ($CollisionShape3D as CollisionShape3D).shape as SphereShape3D
	if shape != null and puddle_radius > 0.0:
		var trigger := shape.duplicate() as SphereShape3D
		trigger.radius = puddle_radius * 0.6
		($CollisionShape3D as CollisionShape3D).shape = trigger
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 2.0
	dome.radial_segments = 48
	dome.rings = 12
	var material := StandardMaterial3D.new()
	material.albedo_color = colours[0] if not colours.is_empty() else Color.WHITE
	material.roughness = 0.12
	material.metallic = 0.0
	material.rim_enabled = false
	dome.material = material
	_puddle = MeshInstance3D.new()
	_puddle.name = "Puddle"
	_puddle.mesh = dome
	_puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_puddle)
	_update_pile()


func _update_pile() -> void:
	var fraction := float(_remaining) / maxf(pieces, 1.0)
	if _puddle != null:
		var width := puddle_radius * lerpf(0.35, 1.0, sqrt(fraction))
		_puddle.scale = Vector3(width, 0.45 * lerpf(0.5, 1.0, fraction), width)
		_puddle.visible = _remaining > 0
		return
	_pile.multimesh.visible_instance_count = ceili(PILE_DISPLAY * fraction)


static func _mesh_for(topping_kind: Kind) -> Mesh:
	if _mesh_cache.has(topping_kind):
		return _mesh_cache[topping_kind]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	var mesh: Mesh
	if topping_kind == Kind.MARSHMELLOW:
		mesh = _rounded_cylinder(0.12, 0.16, 0.06)
		material.roughness = 0.9
	elif topping_kind == Kind.CHOC_SAUCE or topping_kind == Kind.PISTACHIO_SAUCE:
		# A flat, glossy blob. Overlapping many of them reads as a coat of sauce.
		var blob := SphereMesh.new()
		blob.radius = 0.35
		blob.height = 0.2
		blob.radial_segments = 16
		blob.rings = 6
		mesh = blob
		material.roughness = 0.1
	elif topping_kind == Kind.SPRINKLES:
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
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = material
	else:
		mesh.surface_set_material(0, material)
	_mesh_cache[topping_kind] = mesh
	return mesh


## A cylinder with softly rounded edges, like a marshmallow. `bevel` is the radius of the rounding.
static func _rounded_cylinder(radius: float, height: float, bevel: float, segments := 16, arc_steps := 5) -> ArrayMesh:
	bevel = minf(bevel, minf(radius, height * 0.5))
	var profile: Array[Vector4] = []   # radius, height, normal radius, normal height
	profile.append(Vector4(0.0, height * 0.5, 0.0, 1.0))
	for step in arc_steps + 1:
		var angle := PI * 0.5 * (1.0 - float(step) / arc_steps)
		var direction := Vector2(cos(angle), sin(angle))
		profile.append(Vector4(radius - bevel + bevel * direction.x, height * 0.5 - bevel + bevel * direction.y, direction.x, direction.y))
	for step in arc_steps + 1:
		var angle := -PI * 0.5 * float(step) / arc_steps
		var direction := Vector2(cos(angle), sin(angle))
		profile.append(Vector4(radius - bevel + bevel * direction.x, -height * 0.5 + bevel + bevel * direction.y, direction.x, direction.y))
	profile.append(Vector4(0.0, -height * 0.5, 0.0, -1.0))

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in profile.size() - 1:
		for segment in segments:
			var a0 := TAU * segment / segments
			var a1 := TAU * (segment + 1) / segments
			var corners := [[ring, a0], [ring + 1, a0], [ring + 1, a1], [ring, a1]]
			var verts: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner in corners:
				var p: Vector4 = profile[corner[0]]
				verts.append(Vector3(p.x * cos(corner[1]), p.y, p.x * sin(corner[1])))
				normals.append(Vector3(p.z * cos(corner[1]), p.w, p.z * sin(corner[1])))
			for index in [0, 2, 1, 0, 3, 2]:
				tool.set_normal(normals[index])
				tool.add_vertex(verts[index])
	return tool.commit()

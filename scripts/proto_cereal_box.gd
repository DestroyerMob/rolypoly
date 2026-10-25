@tool
class_name ProtoCerealBox
extends Node3D

## A parametric cereal box with hinged flaps top and bottom. Closed it is set
## dressing; opened it is a ramp the marble can run down. Geometry comes from
## BoxBuilder, shared with ArtBox and ProtoBook.
##
## Local space, box standing upright:
##   X = width, Y = height, Z = depth, front face at +Z

const GENERATED := &"proto_cereal_generated"
## How far the artwork quad floats off the carton face.
const ART_OFFSET := 0.05

## Which edge the flaps are hinged on. A real carton hinges its big flap on
## the back panel, but a ramp usually wants to run off the front, and the
## front artwork means you cannot just spin the node around.
enum FlapSide { BACK, FRONT }

## Enum values serialise as integers, so NONE stays first and any new cereal
## goes on the END of this list, never in the middle.
enum Title {
	NONE,
	LOCOCHOCO,
	BORING,
	LOOPIES,
}

const CEREAL_DIR := "res://assets/textures/Cereal/"

## Title to filename stem. Rename the two placeholders once your other two
## cereals are exported, and keep the order.
const TITLE_STEM := {
	Title.LOCOCHOCO: "T_Cereal_LocoChoco",
	Title.BORING: "T_Cereal_Boring",
	Title.LOOPIES: "T_Cereal_Loopies",
}

var _mat_cache := {}

# ----- shape --------------------------------------------------------------
@export_group("Shape")
## Defaults are a standard family carton, 20 by 30 by 7.5 cm. Scale all three
## by 10 for the castle, since the ratios are what make it read as a box.
@export var width := 20.0:
	set(value):
		width = maxf(value, 0.1)
		_rebuild()

@export var height := 30.0:
	set(value):
		height = maxf(value, 0.1)
		_rebuild()

@export var depth := 7.5:
	set(value):
		depth = maxf(value, 0.1)
		_rebuild()

## Card is thin, so a small chamfer is all a carton edge wants.
@export var carton_bevel := 0.15:
	set(value):
		carton_bevel = maxf(value, 0.0)
		_rebuild()

# ----- flaps --------------------------------------------------------------
@export_group("Flaps")
@export var has_flaps := true:
	set(value):
		has_flaps = value
		_rebuild()

@export var flap_side: FlapSide = FlapSide.FRONT:
	set(value):
		flap_side = value
		_rebuild()

## How far the flap reaches from its hinge. 0 means one depth, which is what
## a real carton flap measures. Lengthen it when you want a longer ramp.
@export var top_flap_length := 0.0:
	set(value):
		top_flap_length = maxf(value, 0.0)
		_rebuild()

@export var bottom_flap_length := 0.0:
	set(value):
		bottom_flap_length = maxf(value, 0.0)
		_rebuild()

@export var flap_thickness := 0.25:
	set(value):
		flap_thickness = maxf(value, 0.02)
		_rebuild()
## How far the player can nudge the aim away from the goal, in degrees. Rotates camera to goal
@export_range(0.0, 45.0, 0.5) var aim_clamp_degrees := 10.0

## 0 closed and flat. Positive lifts the free edge, 90 is upright, 180 folds
## it back over the hinge. Negative drops it below the lid, which is the
## angle you want for a ramp.
@export_range(-180.0, 180.0, 0.5) var top_open_degrees := 0.0:
	set(value):
		top_open_degrees = value
		_rebuild()

@export_range(-180.0, 180.0, 0.5) var bottom_open_degrees := 0.0:
	set(value):
		bottom_open_degrees = value
		_rebuild()

# ----- art ----------------------------------------------------------------
@export_group("Art")
## Pick a cereal and its front artwork loads automatically.
@export var title: Title = Title.NONE:
	set(value):
		title = value
		_mat_cache.clear()
		_rebuild()

## Leave empty to use the picked Title. Set to override by hand.
@export var mat_front: Material:
	set(value):
		mat_front = value
		_rebuild()

## Every face except the front, plus both flaps. Cartons are printed on one
## side and this is the paper stock showing everywhere else.
@export var body_color := Color("eddabb"):
	set(value):
		body_color = value
		_mat_cache.erase(&"body")
		_rebuild()

## Overrides body_color entirely when set.
@export var mat_body: Material:
	set(value):
		mat_body = value
		_rebuild()

# ----- physics ------------------------------------------------------------
@export_group("Physics")
@export var collision_enabled := true:
	set(value):
		collision_enabled = value
		_rebuild()

# ----- aimring ------------------------------------------------------------
@export_group("AimRing")
## True while the player is on this box's aim ring.
var _player_on_ring := false
## A faint column over the ring so players can see the launch spot.
@export var show_zone := true:
	set(value):
		show_zone = value
		_rebuild()

## Colour of the column. Keep alpha low, around 0.1, for the faint look.
@export var zone_color := Color(1.0, 1.0, 1.0, 0.12):
	set(value):
		zone_color = value
		_rebuild()
		
func _ready() -> void:
	_rebuild()
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if title != Title.LOOPIES or not _player_on_ring:
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F:
		var hinge := get_node_or_null("TopHinge") as Node3D
		if hinge:
			var v := _vignette()
			if v:
				v.pulse(2.0)
			create_tween().tween_property(hinge, "rotation_degrees:x", 135.0, 0.2)

func _rebuild() -> void:
	#Job 1: Bail out early, as add_child() errors on a node not yet in the tree.
	if not is_inside_tree():
		return

	#Job 2: Clear the previous build. Generated children are stamped and never
	#       given an owner, so they never serialise into the .tscn.
	for child in get_children():
		if child.has_meta(GENERATED):
			remove_child(child)
			child.queue_free()

	#Job 3: The carton itself, centred on the node so the box can be rotated
	#       and stacked without the origin fighting you.
	_build_carton()

	#Job 4: Flaps last, as each one hangs off the carton's top or bottom edge.
	if has_flaps:
		_build_flap(true)
		_build_flap(false)


# --------------------------------------------------------------------------
# Pieces
# --------------------------------------------------------------------------

## The printed carton. One box, body material, artwork floated on +Z.
func _build_carton() -> void:
	var size := Vector3(width, height, depth)
	var carton := _box("Carton", size, Vector3.ZERO, _body_material(),
		false, carton_bevel, null)

	#Job 1: Front artwork. The hand-set override wins, otherwise the picked
	#       Title supplies it, otherwise the carton stays plain paper.
	var art := _art_material("Front", mat_front)
	if art == null:
		return

	#Job 2: Shrink the art to the chamfered face, as the outward face of a
	#       bevelled box is inset by the bevel on all four sides.
	var inset := _carton_bevel_used() * 2.0

	#Job 3: Front faces +Z, so the quad's own axes are already world axes and
	#       the basis is identity. Image U along +X, V along +Y.
	_art(carton, "FrontArt",
		Vector2(maxf(width - inset, 0.05), maxf(height - inset, 0.05)),
		Basis.IDENTITY,
		Vector3(0.0, 0.0, size.z * 0.5 + ART_OFFSET),
		art)


## One flap: a hinge on the carton's top or bottom edge, and a panel offset so
## its hinged edge sits exactly on the pivot.
func _build_flap(is_top: bool) -> void:
	var prefix: String = "Top" if is_top else "Bottom"
	var angle: float = top_open_degrees if is_top else bottom_open_degrees

	#Job 1: Work out the hinge line. Y picks the lid or the base, Z picks the
	#       panel it is glued to.
	var hinge_y: float = (height * 0.5) if is_top else (-height * 0.5)
	var side_sign: float = -1.0 if flap_side == FlapSide.BACK else 1.0
	var hinge_z := depth * 0.5 * side_sign

	var hinge := Node3D.new()
	hinge.name = prefix + "Hinge"
	hinge.position = Vector3(0.0, hinge_y, hinge_z)
	#       Flaps hinge about X. Mirroring the sign between top and bottom
	#       means both angles read as "how far open" rather than one of them
	#       needing to be negative to look the same.
	hinge.rotation_degrees.x = angle if is_top else -angle
	_adopt(hinge)

	#Job 2: The panel. flap_length of 0 means "one depth", which is what a
	#       real carton flap measures.
	var asked: float = top_flap_length if is_top else bottom_flap_length
	var reach: float = asked if asked > 0.001 else depth
	var size := Vector3(width, flap_thickness, reach)

	#       Push the panel out along Z away from the hinge, so the hinged
	#       edge lands on the pivot and rotation sweeps the free edge.
	var pos := Vector3(0.0, 0.0, -side_sign * reach * 0.5)

	var panel := _box(prefix + "Flap", size, pos, _body_material(), true,
		carton_bevel * 0.5, hinge)

	#Job 3: Loopies are launchers, so their top flap wears a loop as the
	#       aim mark. Parented to the panel so it swings with the flap.
	if is_top and title == Title.LOOPIES:
		var ring := MeshInstance3D.new()
		ring.name = "LoopMark"
		var torus := TorusMesh.new()
		var r := minf(size.x, size.z) * 0.3
		torus.outer_radius = r
		torus.inner_radius = r * 0.75
		ring.mesh = torus
		var mark := StandardMaterial3D.new()
		mark.albedo_color = Color("ff6a3d")
		ring.material_override = mark
		ring.scale.y = 0.3
		ring.position = Vector3(0.0, size.y * 0.5 + 0.05,
			-side_sign * size.z * 0.1)
		panel.add_child(ring)
		#Job 4: A trigger over the ring. Standing on it hands the camera to the goal; leaving hands it back.
		var zone := Area3D.new()
		zone.name = "AimZone"
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = r
		cylinder.height = r
		shape.shape = cylinder
		zone.add_child(shape)
		zone.position = ring.position + Vector3(0.0, r * 0.5, 0.0)
		zone.body_entered.connect(_on_aim_zone_entered)
		zone.body_exited.connect(_on_aim_zone_exited)
		panel.add_child(zone)
		#Job 5: A visible copy of the trigger. Open tube, no caps, unshaded,
		#so it reads as a soft glass column rather than a solid object.
		if show_zone:
			var column := MeshInstance3D.new()
			column.name = "ZoneColumn"
			var tube := CylinderMesh.new()
			tube.top_radius = cylinder.radius
			tube.bottom_radius = cylinder.radius
			tube.height = cylinder.height
			tube.cap_top = false
			tube.cap_bottom = false
			column.mesh = tube
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glow.cull_mode = BaseMaterial3D.CULL_DISABLED
			glow.albedo_color = zone_color
			column.material_override = glow
			column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			column.position = zone.position
			panel.add_child(column)

# --------------------------------------------------------------------------
# Builders
# --------------------------------------------------------------------------

## One box with its collider. Geometry comes from BoxBuilder, shared with
## ArtBox and ProtoBook, so a fix to the chamfer fixes every piece at once.
func _box(p_name: String, size: Vector3, pos: Vector3, mat: Material,
		movable: bool, bevel: float, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = p_name
	mi.mesh = BoxBuilder.box_mesh(size, bevel)
	mi.position = pos
	if mat != null:
		mi.material_override = mat

	if parent == null:
		_adopt(mi)
	else:
		parent.add_child(mi)

	if not collision_enabled:
		return mi

	#Job 1: AnimatableBody3D for anything on a hinge, StaticBody3D otherwise.
	#       A StaticBody3D rotated by script does not push a resting body and
	#       lets the marble sink through the flap as it swings.
	var body: PhysicsBody3D
	if movable:
		var animatable := AnimatableBody3D.new()
		animatable.sync_to_physics = false
		body = animatable
	else:
		body = StaticBody3D.new()
	body.name = p_name + "Body"

	#Job 2: A sharp box collider even where the mesh is chamfered, as a
	#       rolling ball behaves better against a flat plane than a hull.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	mi.add_child(body)

	return mi


## A flat quad carrying the front artwork, floated off the carton rather than
## UV-mapped onto it. BoxBuilder writes no UVs, and overlapping surfaces are
## free, so the art is geometry instead of a mapping problem.
func _art(parent: Node3D, p_name: String, size: Vector2, basis: Basis,
		offset: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = p_name
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.transform = Transform3D(basis, offset)
	mi.material_override = mat
	#Job 1: No collider. The artwork sits on a carton that already has one.
	parent.add_child(mi)


func _adopt(node: Node) -> void:
	node.set_meta(GENERATED, true)
	add_child(node)


# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------

## Picks the material for the front face: the hand-set override if there is
## one, otherwise the texture the chosen title implies, otherwise nothing.
func _art_material(face: String, override: Material) -> Material:
	if override != null:
		return override
	if title == Title.NONE:
		return null
	var stem: String = TITLE_STEM.get(title, "")
	if stem.is_empty():
		return null
	return _material_for(CEREAL_DIR + stem + "_" + face + ".png")


## Builds and caches one matte material around a carton texture.
func _material_for(path: String) -> Material:
	#Job 1: Serve the cache, as _rebuild runs on every export change and a
	#       fresh material per rebuild allocates at editor speed.
	if _mat_cache.has(path):
		return _mat_cache[path]

	#Job 2: Check before loading, as load() on a missing path throws an error
	#       into the Output panel on every single rebuild.
	if not ResourceLoader.exists(path):
		push_warning("ProtoCerealBox: texture not found, " + path)
		return null

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path) as Texture2D
	#Job 3: Printed card, so matte and non-metallic.
	mat.roughness = 0.75
	mat.metallic = 0.0
	_mat_cache[path] = mat
	return mat


## The unprinted paper stock. Cached under a fixed key so the colour export
## can invalidate it without clearing the texture materials too.
func _body_material() -> Material:
	if mat_body != null:
		return mat_body
	if _mat_cache.has(&"body"):
		return _mat_cache[&"body"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.roughness = 0.8
	mat.metallic = 0.0
	_mat_cache[&"body"] = mat
	return mat


## BoxBuilder clamps the bevel to just under half the smallest dimension, and
## for a carton that is the depth. Mirror the clamp here so the artwork is
## sized against the bevel actually used, not the one asked for.
func _carton_bevel_used() -> float:
	var limit := minf(minf(width, height), depth) * 0.49
	return clampf(carton_bevel, 0.0, limit)
	
func _on_aim_zone_entered(body: Node3D) -> void:
	if Engine.is_editor_hint() or not body is Player:
		return
	_player_on_ring = true
	var v := _vignette()
	if v:
		v.set_ring(true)
	var rig := _camera_rig()
	var goal := get_tree().get_first_node_in_group(&"goal") as Node3D
	print("rig: ", rig, "  goal: ", goal)
	if rig and goal:
		rig.begin_aim(goal, aim_clamp_degrees)


func _on_aim_zone_exited(body: Node3D) -> void:
	if Engine.is_editor_hint() or not body is Player:
		return
	_player_on_ring = false
	var v := _vignette()
	if v:
		v.set_ring(false)
	var rig := _camera_rig()
	if rig:
		rig.end_aim()


## Walks up from the active camera to whichever node owns begin_aim, so this
## works whether the script sits on the Camera3D or on a pivot above it.
func _camera_rig() -> Node:
	var node: Node = get_viewport().get_camera_3d()
	while node != null and not node.has_method("begin_aim"):
		node = node.get_parent()
	return node
# Vignette Helper
func _vignette() -> Node:
	return get_tree().get_first_node_in_group(&"vignette")

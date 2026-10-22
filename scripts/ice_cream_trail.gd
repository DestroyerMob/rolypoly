class_name IceCreamTrail
extends Node3D

## Leaves a permanent trail of creamy blobs on the ground, and melts away over time.
## The ice cream shrinks steadily and dies once it has melted completely.

signal melted_away

static var _blob_cache: Texture2D

@export var stamp_texture: Texture2D
@export var colour := Color(0.99, 0.95, 0.84)
## Blob diameter in world units while the ice cream is full size.
@export_range(0.2, 20.0, 0.1) var stamp_size := 3.0
## Distance travelled between blobs at full size. Shrinks with the ball.
@export_range(0.1, 10.0, 0.1) var spacing := 1.2
## Most blobs kept. Past this the oldest are reused, so raise it for very long levels.
@export_range(100, 20000) var max_stamps := 6000
## No trail while the ball is slower than this.
@export_range(0.0, 20.0, 0.05) var min_speed := 0.75
## How far below the ball's underside still counts as ground.
@export_range(0.0, 5.0, 0.05) var ground_reach := 0.6
## How far each blob floats above the surface, to avoid flicker against it.
@export_range(0.0, 0.5, 0.005) var lift := 0.05

@export_group("Melting")
## Seconds from full size until the ice cream has melted away, if nothing cools it.
@export_range(1.0, 600.0, 1.0) var melt_seconds := 45.0
## Size at the moment it melts away, as a fraction of its starting size.
@export_range(0.05, 1.0, 0.01) var min_scale := 0.35

var _player: Player
var _collider: CollisionShape3D
var _base_scale := Vector3.ONE
var _canvas: MultiMeshInstance3D
var _multimesh: MultiMesh
var _stamped := 0
var _progress := 0.0
var _applied_scale := 1.0
var _dying := false
var _frozen_for := 0.0
var _frost: StandardMaterial3D
var _has_last := false
var _last_point := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_player = get_parent() as Player
	_collider = _player.get_node_or_null("CollisionShape3D") as CollisionShape3D if _player != null else null
	if _player == null or _collider == null:
		push_warning("IceCreamTrail must be a child of a Player.")
		set_physics_process(false)
		return
	_base_scale = _collider.scale
	_rng.randomize()
	_canvas = _create_canvas()
	_multimesh = _canvas.multimesh


func _physics_process(delta: float) -> void:
	if _dying:
		# Melted away: wait for the respawn, then come back at full size.
		if not _player.is_squished:
			_finish_death()
		return
	if not is_instance_valid(_player) or not _player.visible or _player.freeze or _player.is_squished:
		_has_last = false
		return

	if _frozen_for > 0.0:
		_frozen_for -= delta
		if _frozen_for <= 0.0:
			_set_frost(false)
	else:
		_melt(delta / melt_seconds)
	if _dying or _player.linear_velocity.length() < min_speed:
		return

	var origin := _player.global_position
	_ray.from = origin
	_ray.to = origin + Vector3.DOWN * (_player.get_collision_clearance() + ground_reach)
	_ray.exclude = [_player.get_rid()]
	_ray.collision_mask = _player.collision_mask
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty():
		# Airborne: begin a fresh streak on landing.
		_has_last = false
		return

	var point: Vector3 = hit.position
	if _has_last and point.distance_to(_last_point) < maxf(spacing * _applied_scale, 0.15):
		return
	_has_last = true
	_last_point = point
	_stamp(point, hit.normal)


## Brings the ice cream back towards full size. Cooling stations call this.
## `amount` is the fraction of the melt to undo: 1.0 restores it completely, while a
## small amount each physics frame cools it gradually. Does nothing once it has died.
func refresh(amount := 1.0) -> void:
	if amount <= 0.0 or _progress <= 0.0 or _dying:
		return
	_progress = maxf(_progress - amount, 0.0)
	_update_scale()


## Stops the ice cream melting for `seconds`, keeping its current size. Ice pickups call this
## every frame while the ice cream is on them. Calling it again just restarts the timer.
func freeze_melt(seconds: float) -> void:
	if seconds <= 0.0 or _dying:
		return
	if _frozen_for <= 0.0:
		_set_frost(true)
	_frozen_for = seconds


func _set_frost(on: bool) -> void:
	if _frost == null:
		_frost = StandardMaterial3D.new()
		_frost.albedo_color = Color(0.65, 0.88, 1.0, 0.4)
		_frost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_frost.roughness = 0.1
	for node in _collider.find_children("*", "GeometryInstance3D", true, false):
		node.material_overlay = _frost if on else null


func _melt(amount: float) -> void:
	_progress = minf(_progress + amount, 1.0)
	_update_scale()
	if _progress >= 1.0:
		_die()


func _update_scale() -> void:
	var target := lerpf(1.0, min_scale, _progress)
	# Resize in small steps so physics is not rebuilt every frame.
	if absf(target - _applied_scale) >= 0.004 or _progress <= 0.0 or _progress >= 1.0:
		_apply_scale(target)


func _apply_scale(factor: float) -> void:
	_applied_scale = factor
	# The model sits under the collider, so scaling the collider shrinks both together.
	_collider.scale = _base_scale * factor


func _die() -> void:
	_dying = true
	_has_last = false
	melted_away.emit()
	_player.enter_condition(Player.Condition.DEAD)
	# The same squash and respawn the mashers use; it respawns at the player's spawn point.
	_player.squish_and_respawn(0.35, 1.0)


func _finish_death() -> void:
	_dying = false
	_frozen_for = 0.0
	_set_frost(false)
	_player.exit_condition(Player.Condition.DEAD)
	_progress = 0.0
	_apply_scale(1.0)


func _stamp(point: Vector3, normal: Vector3) -> void:
	# The blob tapers as the ice cream shrinks, with a little variety so they do
	# not look stamped from one mould.
	var size := stamp_size * _applied_scale * _rng.randf_range(0.85, 1.15)
	var stretch := _rng.randf_range(0.8, 1.25)
	var placement := _blob_transform(point, normal, size * stretch, size / stretch, _rng.randf() * TAU, lift)

	var capacity := _multimesh.instance_count
	_multimesh.set_instance_transform(_stamped % capacity, placement)
	_stamped += 1
	_multimesh.visible_instance_count = mini(_stamped, capacity)


## A flat blob lying on a surface: its up axis is the surface normal, rotated by
## `yaw` around it, stretched to width x depth, and lifted a touch off the surface.
static func _blob_transform(point: Vector3, normal: Vector3, width: float, depth: float, yaw: float, height: float) -> Transform3D:
	var up := normal.normalized()
	var reference := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
	var x_axis := up.cross(reference).normalized()
	var z_axis := x_axis.cross(up).normalized()
	var basis := Basis(x_axis, up, z_axis).rotated(up, yaw) * Basis.from_scale(Vector3(width, 1.0, depth))
	return Transform3D(basis, point + up * height)


func _create_canvas() -> MultiMeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.material = _make_material()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = plane
	multimesh.instance_count = max_stamps
	multimesh.visible_instance_count = 0
	# Blobs can be anywhere, so never cull the batch away.
	multimesh.custom_aabb = AABB(Vector3.ONE * -50000.0, Vector3.ONE * 100000.0)

	var canvas := MultiMeshInstance3D.new()
	canvas.multimesh = multimesh
	# Blobs stay where they were dropped instead of travelling with the ball.
	canvas.top_level = true
	canvas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(canvas)
	return canvas


func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.albedo_texture = stamp_texture if stamp_texture != null else _make_blob()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.roughness = 0.45
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _make_blob() -> Texture2D:
	if _blob_cache != null:
		return _blob_cache
	const SIZE := 128
	var rng := RandomNumberGenerator.new()
	rng.seed = 7   # fixed, so the blob shape is the same every run
	var phase := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var p := (Vector2((x + 0.5) / SIZE, (y + 0.5) / SIZE) - Vector2(0.5, 0.5)) * 2.0
			var r := p.length()
			var a := p.angle()
			# Wobbly edge, so it reads as melted cream and not a perfect circle.
			var edge := 0.74 + 0.07 * sin(3.0 * a + phase[0]) + 0.05 * sin(5.0 * a + phase[1]) + 0.03 * sin(8.0 * a + phase[2])
			var alpha := clampf((edge - r) / 0.06 + 0.5, 0.0, 1.0)
			var shade := 1.0 - 0.07 * smoothstep(0.35, 0.75, r)   # slightly darker rim
			image.set_pixel(x, y, Color(shade, shade, shade, alpha))
	image.generate_mipmaps()
	_blob_cache = ImageTexture.create_from_image(image)
	return _blob_cache

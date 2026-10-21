class_name HitEffects
extends RefCounted


const FLASH_SECONDS := 0.08
const NUMBER_MERGE_MSEC := 150

static var _flash_material: StandardMaterial3D


static func hit(player: Player, amount: int) -> void:
	_flash(player)
	_squash(player)
	if player.in_match:
		_damage_number(player, amount)


static func knockout(player: Player) -> void:
	var parent := player.get_parent()
	if parent == null:
		return
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 40
	burst.lifetime = 0.9
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 8.0
	burst.initial_velocity_max = 18.0
	burst.gravity = Vector3(0, -25, 0)
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.2
	burst.color = _colour_of(player)
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	burst.mesh = mesh
	parent.add_child(burst)
	burst.global_position = player.global_position
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


static func _flash(player: Player) -> void:
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.albedo_color = Color(1, 1, 1, 0.85)
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var meshes := player.collider.find_children("*", "MeshInstance3D", true, false)
	for mesh: MeshInstance3D in meshes:
		mesh.material_overlay = _flash_material
	player.get_tree().create_timer(FLASH_SECONDS, false).timeout.connect(func():
		for mesh: Variant in meshes:
			if is_instance_valid(mesh):
				mesh.material_overlay = null
	)


static func _squash(player: Player) -> void:
	if player.is_squished or not is_instance_valid(player.visual):
		return
	if player.has_meta(&"hit_tween"):
		(player.get_meta(&"hit_tween") as Tween).kill()
	player.visual.scale = player.original_visual_scale * Vector3(1.3, 0.75, 1.3)
	var tween := player.create_tween()
	tween.tween_property(player.visual, "scale", player.original_visual_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	player.set_meta(&"hit_tween", tween)


static func _damage_number(player: Player, amount: int) -> void:
	var previous: Variant = player.get_meta(&"hit_number") if player.has_meta(&"hit_number") else null
	var now := Time.get_ticks_msec()
	var label: Label3D
	if is_instance_valid(previous) and now - int(previous.get_meta(&"started")) < NUMBER_MERGE_MSEC:
		label = previous
		amount += int(label.get_meta(&"amount"))
	else:
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0009
		label.font_size = 64
		label.outline_size = 18
		label.outline_modulate = Color(0.15, 0.05, 0.05)
		label.render_priority = 10
		label.outline_render_priority = 9
		player.get_parent().add_child(label)
		label.global_position = player.global_position + Vector3(randf_range(-0.8, 0.8), 2.2, randf_range(-0.8, 0.8))
		label.set_meta(&"started", now)
		player.set_meta(&"hit_number", label)
	label.set_meta(&"amount", amount)
	label.text = str(amount)
	label.modulate = Color(1, 0.35, 0.25) if amount >= 50 else Color(1, 0.9, 0.35)
	if label.has_meta(&"tween"):
		(label.get_meta(&"tween") as Tween).kill()
	label.scale = Vector3.ONE * 1.4
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "scale", Vector3.ONE, 0.12)
	tween.tween_property(label, "global_position:y", label.global_position.y + 3.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tween.chain().tween_callback(label.queue_free)
	label.set_meta(&"tween", tween)


static func _colour_of(player: Player) -> Color:
	if is_instance_valid(player.visual):
		var material: Material = player.visual.get_active_material(0)
		if material is StandardMaterial3D:
			return material.albedo_color
	return Color(1, 0.85, 0.4)

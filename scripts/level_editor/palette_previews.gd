extends Node
signal preview_ready(id: String, texture: Texture2D)

const Catalog = preload("res://scripts/level_editor/catalog.gd")
const World = preload("res://scripts/level_editor/level_world.gd")
var textures: Dictionary = {}
var _started := false

func generate() -> void:
	if _started or DisplayServer.get_name() == "headless":
		return
	_started = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160, 160)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.5
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	for id in Catalog.ITEMS:
		if Catalog.ITEMS[id].get("legacy", false):
			continue
		var source := Catalog.instantiate(Catalog.record(id))
		World.freeze_for_edit(source)
		viewport.add_child(source)
		var marker := source.get_node_or_null("EditorPreview") as Node3D
		if marker != null:
			marker.show()
		World.freeze_for_edit(source)
		var bounds := World.bounds_of(source)
		var center := bounds.get_center()
		var radius := maxf(bounds.size.length() * 0.5, 0.5)
		camera.size = radius * 2.3
		camera.near = 0.01
		camera.far = radius * 10.0 + 10.0
		camera.position = center + Vector3(1, 0.8, 1.2).normalized() * radius * 3.0
		camera.look_at(center)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var texture := ImageTexture.create_from_image(viewport.get_texture().get_image())
		textures[id] = texture
		preview_ready.emit(id, texture)
		source.free()
		await get_tree().process_frame
	viewport.queue_free()

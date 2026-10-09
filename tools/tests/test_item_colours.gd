extends SceneTree

const Catalog = preload("res://scripts/level_editor/catalog.gd")
const Store = preload("res://scripts/level_editor/level_store.gd")
const World = preload("res://scripts/level_editor/level_world.gd")
const ItemColours = preload("res://scripts/level_editor/item_colours.gd")

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_run.call_deferred()


func placed(id: String, colour: Variant = null) -> Node3D:
	var record := Catalog.record(id)
	if colour != null:
		record.colour = colour
	var node := Catalog.instantiate(record)
	root.add_child(node)
	World.freeze_for_edit(node)
	return node


func surface_material(node: Node, mesh_name: String, material_name: String) -> BaseMaterial3D:
	for mesh: MeshInstance3D in node.find_children(mesh_name, "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			var original := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if original != null and original.resource_name == material_name:
				return material
	return null


func test_specs_match_scenes() -> void:
	for id in ItemColours.SPECS:
		check(Catalog.ITEMS.has(id), "%s has a primary colour but is not in the catalog." % id)
		var node := placed(id)
		check(ItemColours.own_colour(node, id) is Color, "%s: none of its primary colour parts were found." % id)
		node.free()
	for id in ["spawn", "goal"]:
		check(not ItemColours.supports(id), "Hidden level markers must not be recolourable.")
	print("COLOURS specs checked: ", ItemColours.SPECS.size())


func test_blender_texture() -> void:
	var node := placed("blender")
	var reference: Color = ItemColours.own_colour(node, "blender")
	check(reference.r > 0.5 and reference.g < 0.3 and reference.b < 0.3, "The blender's primary colour must be its red, not %s." % reference)
	var original := surface_material(node, "Housing", "blender")
	ItemColours.apply(node, "blender", Color.BLUE)
	var painted := surface_material(node, "Housing", "blender")
	check(painted != original and painted.albedo_color.is_equal_approx(Color.BLUE), "Recolouring must give the blender its own blue copy of the material.")
	check(painted.detail_enabled and painted.detail_albedo == original.albedo_texture and painted.detail_mask != null, "The blender's greys and blacks must be kept by the detail layer.")
	check(original.albedo_color.is_equal_approx(Color.WHITE) and not original.detail_enabled, "The shared blender material must not change.")
	var mask := (painted.detail_mask as Texture2D).get_image()
	if mask.is_compressed():
		mask.decompress()
	var size := Vector2(mask.get_width(), mask.get_height())
	# The red swatch is the top-right cell of the 2 × 3 atlas; the rest is grey or black.
	check(mask.get_pixelv(Vector2i(size * Vector2(0.75, 0.08))).r < 0.1, "The red swatch must take the new colour.")
	for cell in [Vector2(0.25, 0.08), Vector2(0.25, 0.5), Vector2(0.75, 0.5), Vector2(0.25, 0.9), Vector2(0.75, 0.9)]:
		check(mask.get_pixelv(Vector2i(size * cell)).r > 0.9, "Grey and black swatches must keep their colour (%s)." % cell)
	ItemColours.apply(node, "blender", Color.GREEN)
	check(surface_material(node, "Housing", "blender") == painted and painted.albedo_color.is_equal_approx(Color.GREEN), "Changing the colour again must update the same copy.")
	check(ItemColours.own_colour(node, "blender").is_equal_approx(reference), "The reference colour must come from the original material after recolouring.")
	ItemColours.apply(node, "blender", null)
	check(surface_material(node, "Housing", "blender") == original, "Removing the colour must restore the original material.")
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		check(not mesh.has_meta(ItemColours.SOURCES), "Restored meshes must forget their original materials.")
	node.free()


func test_shades_and_shaders() -> void:
	var oven := placed("oven", "#2050c0")
	var enamel := surface_material(oven, "*", "Oven_Deep_Teal_Enamel")
	var shadow := surface_material(oven, "*", "Oven_Deep_Shadow")
	check(enamel.albedo_color.is_equal_approx(Color("#2050c0")), "The oven's enamel must take the picked colour.")
	check(shadow.albedo_color.b > shadow.albedo_color.g and shadow.albedo_color.get_luminance() < enamel.albedo_color.get_luminance(), "The oven's darker enamel must become a darker shade of the picked colour.")
	oven.free()
	var box := placed("box", "#d03030")
	var grid := box.get_node("Mesh").material_override as ShaderMaterial
	check(grid != ProtoPiece.MATERIALS[ProtoPiece.Fn.NEUT], "Platforms must recolour a copy of the shared grid material.")
	check((grid.get_shader_parameter("checker_a") as Color).is_equal_approx(Color("#d03030")), "The platform grid must take the picked colour.")
	check((grid.get_shader_parameter("checker_b") as Color).get_luminance() > Color("#d03030").get_luminance(), "The lighter checker must stay lighter.")
	check(ProtoPiece.MATERIALS[ProtoPiece.Fn.NEUT].get_shader_parameter("checker_a").r < 0.5, "The shared grid material must not change.")
	box.free()
	var pot := placed("pot", "#30c060")
	var body := surface_material(pot.get_node("Model"), "*", "Material.001")
	check(body != null and body.albedo_color.is_equal_approx(Color("#30c060")), "The pot body must take the picked colour.")
	var egg := surface_material(pot.get_node("Floaters"), "*", "Material.001")
	check(egg == null or not egg.albedo_color.is_equal_approx(Color("#30c060")), "The pot's floating food must keep its colour.")
	pot.free()


func test_validation() -> void:
	check(ItemColours.parse("#a1B2c3") is Color, "Hex colours must parse.")
	for bad in ["red", "#12345", "#1234567", "#gggggg", "a1b2c3d", 5, null]:
		check(ItemColours.parse(bad) == null, "%s must not parse as a colour." % [bad])
	var document := Store.new_level()
	var record := Catalog.record("blender")
	record.colour = "#3366ff"
	document.objects.append(record)
	check(Store.validate(document).is_empty(), "A level with a colour must validate.")
	check(Store.validate(JSON.parse_string(JSON.stringify(document))).is_empty(), "Colours must survive a JSON round trip.")
	record.colour = "blue"
	check(not Store.validate(document).is_empty(), "An invalid colour must be rejected.")
	record.erase("colour")
	document.objects[0].colour = "#3366ff"
	check(not Store.validate(document).is_empty(), "A colour on an object without a primary colour must be rejected.")


func test_player_choice() -> void:
	var document := Store.new_level()
	check(Catalog.player_of(document) == "onion", "New levels must play as the onion.")
	document.erase("player")
	check(Store.validate(document).is_empty() and Catalog.player_of(document) == "onion", "Levels saved before the player choice must still load as the onion.")
	document.player = "dragon"
	check(not Store.validate(document).is_empty(), "An unknown character must be rejected.")
	document.player = 3
	check(not Store.validate(document).is_empty(), "A character must be named by its id.")
	document.player = "egg"
	check(Store.validate(document).is_empty(), "A known character must validate.")
	var world := World.new()
	root.add_child(world)
	world.build(document, false)
	var player := world.rig.current_player
	check(player.scene_file_path == Catalog.PLAYERS.egg.scene.resource_path, "The level must be played as its chosen character.")
	check(not world.rig.allow_character_swap, "Custom levels must not let the player swap characters.")
	var swap := InputEventAction.new()
	swap.action = "swap_character_3"
	swap.pressed = true
	world.rig._unhandled_input(swap)
	check(world.rig.current_player == player, "The swap keys must not change the character.")
	world.free()
	for id in Catalog.PLAYERS:
		var preview := World.character_preview(id)
		check(preview.get_child_count() > 0 and preview.position.y > 0.0, "%s must have a visible start-marker preview." % id)
		preview.free()


func test_editor_flow() -> void:
	var editor := preload("res://scenes/level_builder.tscn").instantiate() as LevelBuilder
	root.add_child(editor)
	await process_frame
	editor.document = Store.new_level()
	editor.document.objects.append(Catalog.record("blender", Vector3(0, 80, 0)))
	editor._rebuild_world()
	var index: int = editor.document.objects.size() - 1
	var start: Node = editor.world.objects[0].get_node_or_null("EditorPreview/Character")
	check(start != null and start.get_child_count() > 0, "The start marker must show the level's character while editing.")
	editor._player_chosen(1)
	check(editor.document.player == editor.player_choice.get_item_metadata(1) and editor.dirty, "Choosing a character must store it on the level.")
	editor._undo()
	check(Catalog.player_of(editor.document) == "onion" and editor.player_choice.get_item_metadata(editor.player_choice.selected) == "onion", "Undo must restore the character and the toolbar choice.")
	editor.selected = index
	editor._refresh_inspector()
	await process_frame
	var picker := editor.property_section.find_child("PrimaryColour", true, false) as ColorPickerButton
	check(picker != null and picker.color.r > 0.5 and picker.color.b < 0.3, "Selecting a blender must show its red primary colour.")
	check(not editor._colour_reset.visible, "An unchanged colour must not show a reset button.")
	var undo_size := editor.undo_stack.size()
	editor._colour_started()
	editor._colour_changed(Color("#40a0ff"))
	editor._colour_changed(Color("#2040ff"))
	editor._colour_committed()
	var data: Dictionary = editor.document.objects[index]
	check(data.get("colour") == "#2040ff", "Picking a colour must store it on the object.")
	check(editor.undo_stack.size() == undo_size + 1, "One colour pick must be one undo step, however far the picker was dragged.")
	check(surface_material(editor.world.objects[index], "Housing", "blender").albedo_color.is_equal_approx(Color("#2040ff")), "The placed blender must change colour immediately.")
	check(editor._colour_reset.visible, "A changed colour must show its reset button.")
	editor._colour_started()
	editor._colour_changed(picker.color)
	editor._colour_committed()
	check(not editor.document.objects[index].has("colour"), "Picking the original colour must remove the override.")
	editor._undo()
	check(editor.document.objects[index].get("colour") == "#2040ff", "Undo must bring back the previous colour.")
	editor.selected = index
	editor._duplicate_selected()
	check(editor.document.objects[editor.selected].get("colour") == "#2040ff", "Duplicating an object must copy its colour.")
	check(surface_material(editor.world.objects[editor.selected], "Housing", "blender").albedo_color.is_equal_approx(Color("#2040ff")), "The rebuilt world must use the saved colour.")
	editor._refresh_inspector()
	editor._reset_colour()
	check(not editor.document.objects[editor.selected].has("colour"), "Reset must remove the colour.")
	check(surface_material(editor.world.objects[editor.selected], "Housing", "blender").albedo_color.is_equal_approx(Color.WHITE), "Reset must restore the blender's own material.")
	editor.selected = 0
	editor._refresh_inspector()
	check(not editor.property_section.visible, "The start marker has no properties or colour.")
	editor.free()


func _run() -> void:
	test_specs_match_scenes()
	test_blender_texture()
	test_shades_and_shaders()
	test_validation()
	test_player_choice()
	await test_editor_flow()
	print("Item colour tests: %d failure(s)." % failures)
	quit(1 if failures > 0 else 0)

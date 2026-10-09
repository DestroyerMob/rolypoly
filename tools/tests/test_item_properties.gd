extends SceneTree

const Catalog = preload("res://scripts/level_editor/catalog.gd")
const Store = preload("res://scripts/level_editor/level_store.gd")
const ItemProperties = preload("res://scripts/level_editor/item_properties.gd")

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_run.call_deferred()


func has_property(object: Object, name: String) -> bool:
	for property in object.get_property_list():
		if property.name == name:
			return true
	return false


func test_specs_match_scenes() -> void:
	var total := 0
	for id in ItemProperties.SPECS:
		check(Catalog.ITEMS.has(id), "%s has editable properties but is not in the catalog." % id)
		var fresh := Catalog.instantiate(Catalog.record(id))
		var gadget := ItemProperties.gadget_scene_of(fresh)
		for spec in ItemProperties.specs(id):
			total += 1
			var source: Object = gadget if spec.on == "gadget" else fresh
			check(source != null and has_property(source, spec.name), "%s: %s is not a property of the object." % [id, spec.name])
			if source == null or not has_property(source, spec.name):
				continue
			var value: Variant = source.get(spec.name)
			match spec.type:
				"bool":
					check(value is bool, "%s: %s must be a bool." % [id, spec.name])
				"enum":
					check(spec.options.any(func(option): return option[1] == int(value)), "%s: %s default %s is not a listed option." % [id, spec.name, value])
				_:
					check(float(value) >= spec.min - 0.0001 and float(value) <= spec.max + 0.0001, "%s: %s default %s is outside %s..%s." % [id, spec.name, value, spec.min, spec.max])
		if gadget != null:
			gadget.free()
		fresh.free()
	print("PROPS specs checked: ", total)


func test_apply_and_validate() -> void:
	var values := {"force_strength": 75.0, "rotation_duration": 2.5}
	check(ItemProperties.validate("blender", values).is_empty(), "Valid blender properties must pass validation.")
	check(not ItemProperties.validate("blender", {"nope": 1}).is_empty(), "Unknown properties must be rejected.")
	check(not ItemProperties.validate("blender", {"force_strength": 9999.0}).is_empty(), "Out-of-range values must be rejected.")
	check(not ItemProperties.validate("blender", {"force_strength": "10"}).is_empty(), "Non-numeric values must be rejected.")
	check(not ItemProperties.validate("oven", {"start_burners_on": 1}).is_empty(), "Flags must be booleans.")
	check(not ItemProperties.validate("roller", {"starting_direction": 5}).is_empty(), "Enum values must be listed options.")
	check(not ItemProperties.validate("blender", [1]).is_empty(), "Properties must be a dictionary.")
	var record := Catalog.record("blender")
	record.properties = values
	var node := Catalog.instantiate(record)
	check(is_equal_approx(node.force_strength, 75.0) and is_equal_approx(node.rotation_duration, 2.5), "Saved properties must be applied to the object.")
	node.free()
	var document := Store.new_level()
	document.objects.append(record)
	check(Store.validate(document).is_empty(), "A level carrying properties must validate.")
	var parsed: Variant = JSON.parse_string(JSON.stringify(document))
	check(Store.validate(parsed).is_empty(), "Properties must survive a JSON round trip.")
	var bad := document.duplicate(true)
	bad.objects[bad.objects.size() - 1].properties = {"force_strength": 1e9}
	check(not Store.validate(bad).is_empty(), "A level with an out-of-range property must be rejected.")
	var gun_record := Catalog.record("shotgun")
	gun_record.properties = {"pellets": 3.0, "fire_interval": 0.5, "automatic": true}
	var plate := Catalog.instantiate(gun_record)
	check(plate.gadget_overrides == {"pellets": 3, "fire_interval": 0.5, "automatic": true}, "Gun properties must be stored as gadget overrides.")
	plate.free()


func test_gadget_overrides() -> void:
	var rig := PlayerRig.new()
	var player := load("res://packed_scenes/player_onion.tscn").instantiate() as Player
	rig.add_child(player)
	var mount := GadgetMount.new()
	mount.player_rig = rig
	rig.add_child(mount)
	root.add_child(rig)
	await process_frame
	var scene := load("res://scenes/props/m4a1.tscn") as PackedScene
	mount.equip(scene, {"fire_interval": 0.4, "pellets": 4})
	var first: Node = mount._gadget
	check(is_equal_approx(first.fire_interval, 0.4) and first.pellets == 4, "Overrides must be applied to the equipped gadget.")
	mount.equip(scene, {"fire_interval": 0.4, "pellets": 4})
	check(mount._gadget == first, "Collecting the same pickup again must keep the equipped gadget.")
	mount.equip(scene, {"fire_interval": 0.9})
	check(mount._gadget != first and is_equal_approx(mount._gadget.fire_interval, 0.9) and mount._gadget.pellets == 1, "A pickup with different settings must replace the gadget.")
	mount.equip(scene)
	check(is_equal_approx(mount._gadget.fire_interval, 0.09), "Equipping without overrides must use the scene's own values.")
	rig.free()


func test_editor_flow() -> void:
	var editor := preload("res://scenes/level_builder.tscn").instantiate() as LevelBuilder
	root.add_child(editor)
	await process_frame
	editor.document = Store.new_level()
	editor.document.objects.append(Catalog.record("blender", Vector3(0, 80, 0)))
	editor._rebuild_world()
	editor.selected = editor.document.objects.size() - 1
	editor._refresh_inspector()
	await process_frame
	check(editor.property_section.visible and editor._property_resets.size() == 4, "Selecting a blender must list its four properties.")
	var strength := ItemProperties.spec_named("blender", "force_strength")
	check(not editor._property_resets["force_strength"].visible, "An unchanged property must not show a reset button.")
	editor._property_changed(60.0, strength)
	var data: Dictionary = editor.document.objects[editor.selected]
	check(data.get("properties", {}).get("force_strength") == 60.0, "Changing a property must store it on the object.")
	check(editor._property_resets["force_strength"].visible, "A changed property must show its reset button.")
	check(editor.dirty and editor.undo_stack.size() >= 1, "A property change must mark the level dirty and be undoable.")
	editor._property_changed(10.0, strength)
	check(not data.has("properties"), "Setting a property back to its default must remove the override.")
	editor._property_changed(60.0, strength)
	editor._reset_property(strength)
	check(not editor.document.objects[editor.selected].has("properties"), "Reset must remove the override.")
	editor._property_changed(60.0, strength)
	editor._undo()
	check(not editor.document.objects[editor.document.objects.size() - 1].has("properties"), "Undo must restore the previous properties.")
	editor.selected = editor.document.objects.size() - 1
	editor.document.objects[editor.selected].properties = {"force_strength": 42.0}
	editor._duplicate_selected()
	check(editor.document.objects[editor.selected].get("properties", {}).get("force_strength") == 42.0, "Duplicating an object must copy its properties.")
	editor._rebuild_world()
	var blender: Node = editor.world.objects[editor.selected]
	check(is_equal_approx(blender.force_strength, 42.0), "The built world must use the saved property.")
	editor.selected = 0
	editor._refresh_inspector()
	check(not editor.property_section.visible, "Objects without properties must hide the section.")
	editor.free()


func _run() -> void:
	test_specs_match_scenes()
	test_apply_and_validate()
	await test_gadget_overrides()
	await test_editor_flow()
	print("Item property tests: %d failure(s)." % failures)
	quit(1 if failures > 0 else 0)

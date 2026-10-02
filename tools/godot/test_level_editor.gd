extends SceneTree

const Catalog = preload("res://scripts/level_editor/catalog.gd")
const Store = preload("res://scripts/level_editor/level_store.gd")
var editor: LevelBuilder
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func check_level_deletion() -> void:
	# Run the real store implementation against disposable workspace fixtures.
	# Leave the player's user:// saves untouched.
	var directory := "res://.godot/test_level_deletion_%d" % Time.get_ticks_usec()
	var test_store := GDScript.new()
	test_store.source_code = FileAccess.get_file_as_string("res://scripts/level_editor/level_store.gd").replace('const DIRECTORY := "user://levels"', 'const DIRECTORY := "%s"' % directory)
	check(test_store.reload() == OK, "The isolated level store must compile.")
	var saved: Dictionary = test_store.save_level(Store.new_level(), "delete.json")
	check(not saved.has("error"), "The deletion fixture must save successfully.")
	var kept: Dictionary = test_store.save_level(Store.new_level(), "keep.json")
	check(not kept.has("error"), "The neighboring level must save successfully.")
	var invalid: Dictionary = test_store.delete_level("../keep.json")
	check(invalid.has("error") and FileAccess.file_exists(directory.path_join("keep.json")), "Deletion must reject filenames outside the save folder.")
	var removed: Dictionary = test_store.delete_level("delete.json")
	check(not removed.has("error") and not FileAccess.file_exists(directory.path_join("delete.json")), "Deletion must remove the saved file from disk.")
	check(FileAccess.file_exists(directory.path_join("keep.json")) and test_store.list_levels().size() == 1, "Deleting one level must preserve neighboring levels and update the listing.")
	var missing: Dictionary = test_store.delete_level("delete.json")
	check(missing.has("error"), "A failed deletion must report an error.")
	var malformed := FileAccess.open(directory.path_join("broken.json"), FileAccess.WRITE)
	malformed.store_string("invalid JSON")
	malformed.close()
	var broken: Dictionary = test_store.delete_level("broken.json")
	check(not broken.has("error"), "Unavailable or malformed saved levels must also be deletable.")
	test_store.delete_level("keep.json")
	DirAccess.remove_absolute(directory)
	check(editor.browser._delete_button.disabled, "Delete must start disabled without a selected level.")
	editor.browser._entries = [{"filename": "../outside.json", "name": "Invalid", "error": "Invalid level filename."}]
	editor.browser._list.add_item("Invalid")
	editor.browser._list.select(0)
	editor.browser._select(0)
	check(not editor.browser._delete_button.disabled, "Selecting a saved level must enable Delete, including unavailable levels.")
	editor.browser._delete()
	check(editor.browser._entries.size() == 1 and editor.browser._message.text == "Invalid level filename.", "The browser must retain the selected level and show the error when deletion fails.")
	editor.browser._entries.clear()
	editor.browser._list.clear()
	editor.browser._delete_button.disabled = true
	editor.filename = "open.json"
	editor.dirty = false
	editor._saved_level_deleted("other.json")
	check(editor.filename == "open.json" and not editor.dirty, "Deleting another save must not alter the current layout's save state.")
	editor._saved_level_deleted("open.json")
	check(editor.filename.is_empty() and editor.dirty, "Deleting the current save must mark the open layout as unsaved.")

func drag_handle(axis: int, cancel := false, full_turns := false) -> void:
	editor._update_transform_gizmo()
	var handle: Button = editor.transform_gizmo._handles[axis]
	var point := handle.position + handle.size * 0.5
	var direction: Vector2 = editor.transform_gizmo._directions[axis]
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	check(editor.transform_gizmo.dragging, "Pressing a transform handle must begin a drag.")
	var motion := InputEventMouseMotion.new()
	motion.position = point + direction * 50.0
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	if full_turns:
		var center: Vector2 = editor.transform_gizmo._center
		for step in range(1, 11):
			motion = InputEventMouseMotion.new()
			motion.position = center + (point - center).rotated(deg_to_rad(step * 45.0))
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(motion)
			await process_frame
	else:
		Input.parse_input_event(motion)
		await process_frame
	check(editor.transform_gizmo.visible, "Handles must remain visible during the drag.")
	if cancel:
		var escape := InputEventKey.new()
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = true
		Input.parse_input_event(escape)
		await process_frame
	var release := InputEventMouseButton.new()
	release.position = motion.position
	release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	await process_frame
	check(not editor.transform_gizmo.dragging, "Mouse release outside a handle must finish the drag.")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	editor = preload("res://scenes/level_builder.tscn").instantiate()
	root.add_child(editor)
	check_level_deletion()
	editor.document = Store.new_level()
	editor.document.objects = [Catalog.record("counter", Vector3(0, 80, 0)), Catalog.record("ramp", Vector3(16, 80, 0))]
	editor._rebuild_world()
	editor._refresh_inspector()
	editor.camera.position = Vector3(0, 105, 45)
	editor.camera.look_at(Vector3(0, 80, 0))
	await physics_frame
	await process_frame
	check(not editor.placing, "The editor must start ready to select.")
	check(editor.palette.max_columns == 3, "The palette must use a model grid.")
	for index in editor.palette.item_count:
		var id: String = editor.palette.get_item_metadata(index)
		check(editor.palette.get_item_tooltip(index) == Catalog.ITEMS[id].label, "Every model needs its name tooltip.")
	editor._choose_palette(editor.palette_ids.find("ramp"))
	editor._mouse_position = editor.camera.unproject_position(Vector3(0, 80, 0))
	editor._world_click()
	check(editor.selected == 0 and not editor.placing, "Clicking an existing object while placing must select it.")
	check(editor.document.objects.size() == 2, "Selection must not place an extra object.")
	check(not editor.selection_actions[0].disabled, "Delete must be enabled after world selection.")
	check(editor.transform_gizmo.mode == editor.GizmoMode.MOVE, "A new selection must start with move handles.")
	# Axis drags use world coordinates, even when the selected object is rotated.
	editor.document.objects[0].rotation = [0.0, 45.0, 0.0]
	Catalog.apply_transform(editor.world.objects[0], editor.document.objects[0])
	for axis in 3:
		var before := Catalog.vector(editor.document.objects[0].position)
		var steps := editor.undo_stack.size()
		await drag_handle(axis)
		var after := Catalog.vector(editor.document.objects[0].position)
		check(after[axis] > before[axis], "Dragging a move handle must increase the chosen world axis.")
		for other in 3:
			if other != axis:
				check(is_equal_approx(after[other], before[other]), "Moving one axis must preserve the other coordinates.")
		check(editor.undo_stack.size() == steps + 1, "A move drag must create one undo entry.")
		check(editor.selected == 0, "Moving must preserve selection.")
		check(is_equal_approx(editor.transform_fields[axis].value, after[axis]), "Dragging must update the position inspector.")
		editor._undo()
		check(Catalog.vector(editor.document.objects[0].position).is_equal_approx(before), "Undo must restore the position.")
		editor._redo()
		check(Catalog.vector(editor.document.objects[0].position).is_equal_approx(after), "Redo must restore the movement.")
		editor._undo()
		editor._select_existing(1)
	var ground_before := Catalog.vector(editor.document.objects[0].position)
	await drag_handle(3)
	var ground_after := Catalog.vector(editor.document.objects[0].position)
	check(not ground_after.is_equal_approx(ground_before), "The XZ handle must move across the ground plane.")
	check(is_equal_approx(ground_after.y, ground_before.y), "The XZ handle must preserve height.")
	editor._undo()
	editor._select_existing(1)
	var cancel_steps := editor.undo_stack.size()
	await drag_handle(1, true)
	check(Catalog.vector(editor.document.objects[0].position).is_equal_approx(ground_before), "Escape must restore the position.")
	check(editor.undo_stack.size() == cancel_steps and editor.selected == 0, "Cancelling movement must preserve history and selection.")
	# Off-grid positions should not jump on untouched axes; snap the displacement.
	editor.document.objects[0].position = [0.37, 80.2, 0.45]
	Catalog.apply_transform(editor.world.objects[0], editor.document.objects[0])
	editor.snap_field.value = 1.0
	editor._transform_drag_started()
	editor._position_drag_changed(Vector3(1.6, 0, 0))
	check(Catalog.vector(editor.document.objects[0].position).is_equal_approx(Vector3(2.37, 80.2, 0.45)), "Movement must snap displacement without changing off-grid coordinates.")
	editor._transform_drag_finished(true)
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	await process_frame
	editor._transform_drag_started()
	editor._position_drag_changed(Vector3(0.15, 0, 0))
	check(Catalog.vector(editor.document.objects[0].position).is_equal_approx(Vector3(0.52, 80.2, 0.45)), "Shift must disable movement snapping.")
	editor._transform_drag_finished(true)
	shift.pressed = false
	Input.parse_input_event(shift)
	# A handle viewed directly end-on must still allow movement via its fallback.
	var center: Vector3 = editor.world.objects[0].global_transform * editor.World.bounds_of(editor.world.objects[0]).get_center()
	editor.camera.position = center + Vector3(0, 0, 45)
	editor.camera.look_at(center)
	var end_on_before := Catalog.vector(editor.document.objects[0].position)
	await drag_handle(2)
	check(float(editor.document.objects[0].position[2]) > end_on_before.z, "An end-on axis must remain draggable.")
	editor._undo()
	editor._select_existing(1)
	editor.camera.position = Vector3(0, 105, 45)
	editor.camera.look_at(Vector3(0, 80, 0))
	editor._set_transform_tool(editor.GizmoMode.SCALE)
	check(editor.selected == 0 and editor.transform_gizmo.mode == editor.GizmoMode.SCALE, "Switching to Scale must preserve selection.")
	# Exercise the same GUI/input route as a mouse drag, including release outside.
	editor._update_transform_gizmo()
	check(editor.transform_gizmo.visible, "A visible selection must show scale handles.")
	var handle: Button = editor.transform_gizmo._handles[0]
	var handle_position := handle.position + handle.size * 0.5
	var press := InputEventMouseButton.new()
	press.position = handle_position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	check(editor.transform_gizmo.dragging, "Pressing a scale handle must begin a drag.")
	var motion := InputEventMouseMotion.new()
	motion.position = handle_position + editor.transform_gizmo._direction * 50.0
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await process_frame
	check(float(editor.document.objects[0].scale[0]) > 1.0, "Mouse motion must resize the selection.")
	check(editor.transform_gizmo.visible, "Handles must remain visible during the drag.")
	var release := InputEventMouseButton.new()
	release.position = motion.position
	release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	await process_frame
	check(not editor.transform_gizmo.dragging, "Mouse release outside a handle must finish the drag.")
	editor._undo()
	editor._select_existing(1)
	var history_size := editor.undo_stack.size()
	editor._transform_drag_started()
	editor._scale_changed(2.0, 0)
	editor._scale_changed(3.0, 0)
	editor._transform_drag_finished(false)
	check(Catalog.vector(editor.document.objects[0].scale).is_equal_approx(Vector3(3, 1, 1)), "X scaling must preserve Y and Z.")
	check(editor.undo_stack.size() == history_size + 1, "One scale gesture must create one undo entry.")
	editor._undo()
	check(Catalog.vector(editor.document.objects[0].scale).is_equal_approx(Vector3.ONE), "Undo must restore the original scale.")
	editor._redo()
	check(Catalog.vector(editor.document.objects[0].scale).is_equal_approx(Vector3(3, 1, 1)), "Redo must restore the scaled object.")
	editor._select_existing(1)
	history_size = editor.undo_stack.size()
	editor._transform_drag_started()
	editor._scale_changed(2.0, 3)
	editor._transform_drag_finished(true)
	check(Catalog.vector(editor.document.objects[0].scale).is_equal_approx(Vector3(3, 1, 1)), "Escape must cancel the scale gesture.")
	check(editor.undo_stack.size() == history_size, "Cancelled scaling must not add undo entries.")
	editor._transform_drag_started()
	editor._scale_changed(10000.0, 3)
	editor._transform_drag_finished(false)
	check(Store.validate(editor.document).is_empty(), "Uniform scaling must respect save limits.")
	check(is_equal_approx(float(editor.document.objects[0].scale[0]) / float(editor.document.objects[0].scale[1]), 3.0), "Uniform scaling must preserve proportions at the limit.")
	var rotate_key := InputEventKey.new()
	rotate_key.physical_keycode = KEY_R
	rotate_key.pressed = true
	var rotation_before := Catalog.vector(editor.document.objects[0].rotation)
	Input.parse_input_event(rotate_key)
	await process_frame
	check(editor.selected == 0 and editor.transform_gizmo.mode == editor.GizmoMode.ROTATE, "R must switch to Rotate while preserving selection.")
	check(Catalog.vector(editor.document.objects[0].rotation).is_equal_approx(rotation_before), "Switching tools must not change the rotation.")
	check(not editor.transform_gizmo._handles[3].visible, "Rotation must only expose the three axis handles.")
	for axis in 3:
		var before := Catalog.vector(editor.document.objects[0].rotation)
		var position := Catalog.vector(editor.document.objects[0].position)
		var scale := Catalog.vector(editor.document.objects[0].scale)
		var steps := editor.undo_stack.size()
		await drag_handle(axis)
		var after := Catalog.vector(editor.document.objects[0].rotation)
		check(not is_equal_approx(after[axis], before[axis]), "Dragging a rotation ring must change its chosen axis.")
		for other in 3:
			if other != axis:
				check(is_equal_approx(after[other], before[other]), "Rotation must preserve the other angle components.")
		check(Catalog.vector(editor.document.objects[0].position).is_equal_approx(position), "Rotation must preserve the object's pivot position.")
		check(Catalog.vector(editor.document.objects[0].scale).is_equal_approx(scale), "Rotation must preserve scale.")
		check(editor.selected == 0 and editor.undo_stack.size() == steps + 1, "A rotation drag must preserve selection and create one undo entry.")
		check(is_equal_approx(editor.transform_fields[axis + 3].value, after[axis]), "Rotation must update the angle inspector.")
		editor._undo()
		check(Catalog.vector(editor.document.objects[0].rotation).is_equal_approx(before), "Undo must restore the rotation.")
		editor._redo()
		check(Catalog.vector(editor.document.objects[0].rotation).is_equal_approx(after), "Redo must restore the rotation drag.")
		editor._undo()
		editor._select_existing(1)
	var rotation_steps := editor.undo_stack.size()
	await drag_handle(1, true)
	check(Catalog.vector(editor.document.objects[0].rotation).is_equal_approx(rotation_before), "Escape must cancel the rotation.")
	check(editor.selected == 0 and editor.undo_stack.size() == rotation_steps, "Cancelled rotation must preserve history and selection.")
	await drag_handle(2, false, true)
	check(is_equal_approx(editor.transform_gizmo._rotation_degrees, 450.0), "Rotation must accumulate smoothly across multiple full turns.")
	check(is_equal_approx(float(editor.document.objects[0].rotation[2]), wrapf(rotation_before.z + 450.0, -180, 180)), "Rotation must normalize wrapped angles.")
	check(Store.validate(editor.document).is_empty(), "Rotated objects must remain valid to save.")
	editor._undo()
	editor._select_existing(1)
	editor.document.objects[0].rotation = [7.0, 22.0, -13.0]
	Catalog.apply_transform(editor.world.objects[0], editor.document.objects[0])
	editor._transform_drag_started()
	editor._rotation_drag_changed(8.5, 0)
	check(Catalog.vector(editor.document.objects[0].rotation).is_equal_approx(Vector3(22, 22, -13)), "Rotation must snap the angle displacement without jumping off-grid starting angles.")
	editor._transform_drag_finished(true)
	var precision := InputEventKey.new()
	precision.physical_keycode = KEY_SHIFT
	precision.pressed = true
	Input.parse_input_event(precision)
	await process_frame
	editor._transform_drag_started()
	editor._rotation_drag_changed(1.25, 2)
	check(Catalog.vector(editor.document.objects[0].rotation).is_equal_approx(Vector3(7, 22, -11.75)), "Shift must allow precise rotation without snapping.")
	editor._transform_drag_finished(true)
	precision.pressed = false
	Input.parse_input_event(precision)
	var step_key := InputEventKey.new()
	step_key.physical_keycode = KEY_BRACKETRIGHT
	step_key.pressed = true
	Input.parse_input_event(step_key)
	await process_frame
	check(is_equal_approx(float(editor.document.objects[0].rotation[1]), 37.0), "The bracket shortcut must keep 15-degree rotation steps available.")
	editor._undo()
	editor._select_existing(1)
	var delete := InputEventKey.new()
	delete.physical_keycode = KEY_DELETE
	delete.pressed = true
	Input.parse_input_event(delete)
	await process_frame
	check(editor.document.objects.size() == 1 and editor.selected == -1, "Delete key must remove the selected object.")
	check(not editor.selection_box.visible and not editor.transform_gizmo.visible, "Deletion must clear the selection visuals.")
	editor._undo()
	check(editor.document.objects.size() == 2, "Undo must restore deleted objects.")
	# A render-enabled run also checks every generated thumbnail and saves the UI.
	if DisplayServer.get_name() != "headless":
		for frame in 300:
			if editor.previews.textures.size() == editor.palette_ids.size():
				break
			await process_frame
		check(editor.previews.textures.size() == editor.palette_ids.size(), "All catalog models must render a thumbnail.")
		for texture in editor.previews.textures.values():
			check(not texture.get_image().is_invisible(), "Model thumbnails must contain visible pixels.")
		editor.document = Store.new_level()
		editor._rebuild_world()
		editor._select_existing(2)
		editor._focus_selected()
		editor._set_transform_tool(editor.GizmoMode.ROTATE)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/level-editor-check.png")
	print("Level editor checks: ", "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size())
	editor.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

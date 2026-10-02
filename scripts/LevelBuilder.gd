class_name LevelBuilder
extends Node3D

const Catalog = preload("res://scripts/level_editor/catalog.gd")
const Store = preload("res://scripts/level_editor/level_store.gd")
const World = preload("res://scripts/level_editor/level_world.gd")
const EditorTheme = preload("res://scripts/level_editor/editor_theme.gd")
const Browser = preload("res://scripts/level_editor/level_browser.gd")
const Previews = preload("res://scripts/level_editor/palette_previews.gd")
const TransformGizmo = preload("res://scripts/level_editor/transform_gizmo.gd")
const GizmoMode = TransformGizmo.Mode

@export var start_in_editor := true

@onready var camera: Camera3D = $EditorCamera
var document: Dictionary
var filename := ""
var build_mode := true
var dirty := false
var world: Node3D
var selected := -1
var placing := false
var moving := false
var palette_id := "counter"
var placement: Dictionary = Catalog.record("counter")
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var ghost: Node3D
var selection_box: MeshInstance3D
var grid: MeshInstance3D
var _mouse_position := Vector2.ZERO
var _rebuilding_ui := false
var _paused := false
var _completed := false
var _load_error := ""
var _editor_camera_transform: Transform3D

var hud: CanvasLayer
var editor_ui: Control
var play_ui: Control
var status: Label
var name_field: LineEdit
var category: OptionButton
var search: LineEdit
var palette: ItemList
var palette_ids: Array[String] = []
var snap_field: SpinBox
var height_field: SpinBox
var surface_toggle: CheckBox
var object_list: OptionButton
var save_state: Label
var place_button: Button
var select_button: Button
var selection_actions: Array[Button] = []
var history_actions: Array[Button] = []
var selection_hint: Label
var selection_label: Label
var transform_fields: Array[SpinBox] = []
var play_title: Label
var browser: Window
var confirm: ConfirmationDialog
var pause_panel: PanelContainer
var pause_title: Label
var previews: Node
var transform_gizmo: Control
var move_handle_button: Button
var scale_handle_button: Button
var rotate_handle_button: Button
var _transform_before: Dictionary = {}
var _scale_start := Vector3.ONE
var _position_start := Vector3.ZERO
var _rotation_start := Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var launch: Dictionary = get_tree().get_meta("custom_level_launch", {})
	if get_tree().has_meta("custom_level_launch"):
		get_tree().remove_meta("custom_level_launch")
	# The standalone player can also open a local course from a desktop shortcut.
	if launch.is_empty():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--custom-level="):
				var requested := argument.trim_prefix("--custom-level=")
				var loaded := Store.read_level(requested)
				_load_error = loaded.get("error", "")
				if _load_error.is_empty():
					_load_error = Store.playable_error(loaded.document) if not start_in_editor else ""
					launch = {"document": loaded.document, "filename": requested, "editing": start_in_editor or not _load_error.is_empty()}
				else:
					launch = {"editing": true}
	document = Store.normalize(launch.get("document", Store.new_level()))
	filename = launch.get("filename", "")
	build_mode = launch.get("editing", start_in_editor)
	dirty = filename.is_empty()
	previews = Previews.new()
	add_child(previews)
	_create_ui()
	previews.preview_ready.connect(_preview_ready)
	_create_grid()
	_editor_camera_transform = camera.transform
	_rebuild_world()
	_update_mode_ui()
	if build_mode:
		previews.generate.call_deferred()
		_make_ghost()
		_status(_load_error if not _load_error.is_empty() else "Click an object to select it. Choose Move, Rotate or Scale and drag its handles. Delete removes it.")

func _create_ui() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var theme := EditorTheme.create()
	editor_ui = Control.new()
	editor_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor_ui.theme = theme
	editor_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(editor_ui)

	var top := _panel(editor_ui, Control.PRESET_TOP_WIDE, Vector4(16, 16, -16, 120))
	var toolbar := HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar.add_theme_constant_override("separation", 16)
	top.add_child(toolbar)
	var branding := VBoxContainer.new()
	branding.custom_minimum_size.x = 185
	branding.add_theme_constant_override("separation", 2)
	toolbar.add_child(branding)
	_label(branding, "LEVEL EDITOR", 23)
	_muted(branding, "Kitchen workshop")
	var title_group := VBoxContainer.new()
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_group.custom_minimum_size.x = 220
	title_group.add_theme_constant_override("separation", 3)
	toolbar.add_child(title_group)
	name_field = LineEdit.new()
	name_field.text = document.name
	name_field.placeholder_text = "Name your level"
	name_field.max_length = 80
	name_field.name = "LevelName"
	name_field.text_changed.connect(func(value: String):
		document.name = value
		dirty = true
	)
	title_group.add_child(name_field)
	save_state = _muted(title_group, "Unsaved changes")
	_button(toolbar, "My levels", func(): _guard_unsaved(browser.show_levels))
	_button(toolbar, "Save copy", _save.bind(true))
	_button(toolbar, "Save", _save.bind(false))
	EditorTheme.primary(_button(toolbar, "Play level  ⇥", _play))
	_button(toolbar, "Menu", _menu)

	var left := _panel(editor_ui, Control.PRESET_LEFT_WIDE, Vector4(16, 134, 350, -114))
	var column := VBoxContainer.new()
	left.add_child(column)
	_label(column, "Object library", 24)
	_muted(column, "Add pieces to the shared kitchen.")
	search = LineEdit.new()
	search.placeholder_text = "Search objects…"
	search.clear_button_enabled = true
	column.add_child(search)
	search.text_changed.connect(func(_value: String): _fill_palette())
	category = OptionButton.new()
	category.custom_minimum_size.y = 42
	for title in ["All", "Surfaces", "Kitchen", "Obstacles", "Powerups", "Level"]:
		category.add_item(title)
	column.add_child(category)
	category.item_selected.connect(func(_index: int): _fill_palette())
	palette = ItemList.new()
	palette.name = "ModelPalette"
	palette.max_columns = 3
	palette.fixed_column_width = 80
	palette.fixed_icon_size = Vector2i(72, 72)
	palette.icon_mode = ItemList.ICON_MODE_TOP
	palette.add_theme_constant_override("h_separation", 4)
	palette.add_theme_constant_override("v_separation", 8)
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette.custom_minimum_size.y = 100
	column.add_child(palette)
	palette.item_selected.connect(_choose_palette)
	var modes := HBoxContainer.new()
	column.add_child(modes)
	place_button = _button(modes, "Place", _set_tool.bind(true))
	select_button = _button(modes, "Select  V", _set_tool.bind(false))
	for button in [place_button, select_button]:
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_separator(column)
	_label(column, "Placement", 21)
	snap_field = _number(column, "Grid snap", 0.25, 32, 0.25, 8)
	snap_field.tooltip_text = "8 units for counter tiles; 1 or less for equipment."
	height_field = _number(column, "Height / offset", -1000, 1000, 0.25, 0)
	height_field.value_changed.connect(func(_value: float): grid.position.y = height_field.value)
	surface_toggle = CheckBox.new()
	surface_toggle.text = "Snap to kitchen surfaces"
	surface_toggle.button_pressed = true
	column.add_child(surface_toggle)
	surface_toggle.toggled.connect(func(enabled: bool): grid.visible = build_mode and not enabled)
	_muted(column, "Click a placed object to select it.\nShift+click to place on an object.\n[ / ] rotates by 15°.")

	var right := _panel(editor_ui, Control.PRESET_RIGHT_WIDE, Vector4(-388, 134, -16, -114))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var inspector := VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 16)
	scroll.add_child(inspector)
	_label(inspector, "Inspector", 24)
	object_list = OptionButton.new()
	object_list.fit_to_longest_item = false
	object_list.custom_minimum_size.y = 42
	inspector.add_child(object_list)
	object_list.item_selected.connect(_select_existing)
	selection_label = _label(inspector, "", 21)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_hint = _muted(inspector, "")
	var handle_tools := HBoxContainer.new()
	inspector.add_child(handle_tools)
	move_handle_button = _button(handle_tools, "Move  G", _set_transform_tool.bind(GizmoMode.MOVE))
	rotate_handle_button = _button(handle_tools, "Rotate  R", _set_transform_tool.bind(GizmoMode.ROTATE))
	scale_handle_button = _button(handle_tools, "Scale  T", _set_transform_tool.bind(GizmoMode.SCALE))
	for button in [move_handle_button, rotate_handle_button, scale_handle_button]:
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var object_actions := HBoxContainer.new()
	inspector.add_child(object_actions)
	var delete_action := _button(object_actions, "Delete", _delete_selected)
	delete_action.tooltip_text = "Delete / Backspace removes the selection. Ctrl / Cmd + Z restores it."
	delete_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_actions.append(delete_action)
	var duplicate_action := _button(object_actions, "Duplicate", _duplicate_selected)
	duplicate_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_actions.append(duplicate_action)
	_separator(inspector)
	for section in ["Position", "Rotation · degrees", "Scale"]:
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 8)
		inspector.add_child(group)
		_label(group, section, 18)
		var axes := HBoxContainer.new()
		axes.add_theme_constant_override("separation", 8)
		group.add_child(axes)
		for axis in ["X", "Y", "Z"]:
			var index := transform_fields.size()
			var axis_group := VBoxContainer.new()
			axis_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			axis_group.add_theme_constant_override("separation", 4)
			axes.add_child(axis_group)
			var label := _label(axis_group, axis, 16)
			label.add_theme_color_override("font_color", [Color("f69fa4"), Color("91e5c1"), Color("9abcf4")][index % 3])
			var field := SpinBox.new()
			field.min_value = 0.05 if index >= 6 else -10000
			field.max_value = 100 if index >= 6 else 10000
			field.step = 0.05 if index >= 6 else 0.25
			field.value = 1 if index >= 6 else 0
			field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			field.custom_minimum_size = Vector2(96, 42)
			field.get_line_edit().add_theme_font_size_override("font_size", 16)
			axis_group.add_child(field)
			transform_fields.append(field)
			field.value_changed.connect(_transform_changed.bind(index))
	_separator(inspector)
	for pair in [["Focus  F", "Reposition  M"], ["Undo", "Redo"]]:
		var row := HBoxContainer.new()
		inspector.add_child(row)
		for title in pair:
			var actions := {"Focus  F": _focus_selected, "Reposition  M": _move_selected,
				"Duplicate": _duplicate_selected, "Undo": _undo, "Redo": _redo}
			var button := _button(row, title, actions[title])
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if title in ["Undo", "Redo"]:
				history_actions.append(button)
			else:
				selection_actions.append(button)
	_muted(inspector, "Start and finish markers are only\nvisible while editing.")

	var bottom := _panel(editor_ui, Control.PRESET_BOTTOM_WIDE, Vector4(16, -100, -16, -16))
	var footer := HBoxContainer.new()
	bottom.add_child(footer)
	status = _label(footer, "", 18)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var shortcuts := _muted(footer, "RMB + WASD  Fly    Q / E  Height    ⇥  Play\nCtrl / Cmd + S  Save    Ctrl / Cmd + Z  Undo")
	shortcuts.custom_minimum_size.x = 480
	transform_gizmo = TransformGizmo.new()
	transform_gizmo.name = "TransformHandles"
	editor_ui.add_child(transform_gizmo)
	transform_gizmo.drag_started.connect(_transform_drag_started)
	transform_gizmo.scale_changed.connect(_scale_changed)
	transform_gizmo.position_changed.connect(_position_drag_changed)
	transform_gizmo.rotation_changed.connect(_rotation_drag_changed)
	transform_gizmo.drag_finished.connect(_transform_drag_finished)

	play_ui = Control.new()
	play_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_ui.theme = theme
	play_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(play_ui)
	play_title = _label(play_ui, "", 22)
	play_title.position = Vector2(24, 20)
	var crosshair := _label(play_ui, "+", 22)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel = _panel(play_ui, Control.PRESET_CENTER, Vector4(-230, -240, 230, 240))
	var pause_buttons := VBoxContainer.new()
	pause_buttons.add_theme_constant_override("separation", 14)
	pause_panel.add_child(pause_buttons)
	pause_title = _label(pause_buttons, "Paused", 30)
	_muted(pause_buttons, "Return to editing or try the course again.")
	EditorTheme.primary(_button(pause_buttons, "Resume", _resume))
	_button(pause_buttons, "Restart level", _restart)
	_button(pause_buttons, "Edit this level", _edit)
	_button(pause_buttons, "My levels", func(): _guard_unsaved(browser.show_levels))
	_button(pause_buttons, "Main menu", _menu)

	browser = Browser.new()
	add_child(browser)
	browser.hide()
	browser.chosen.connect(_load_document)
	browser.deleted.connect(_saved_level_deleted)
	confirm = ConfirmationDialog.new()
	confirm.theme = theme
	confirm.title = "Unsaved changes"
	confirm.dialog_text = "Leave this layout without saving your changes?"
	confirm.ok_button_text = "Discard changes"
	add_child(confirm)
	_fill_palette()
	_refresh_inspector()

func _panel(parent: Node, preset: int, offsets: Vector4) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	return panel

func _muted(parent: Node, text: String) -> Label:
	var label := _label(parent, text, 16)
	label.add_theme_color_override("font_color", EditorTheme.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _separator(parent: Node) -> void:
	parent.add_child(HSeparator.new())

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func(): action.call_deferred())
	parent.add_child(button)
	return button

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _number(parent: Node, title: String, minimum: float, maximum: float, step: float, value: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row, title, 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	field.custom_minimum_size.x = 130
	row.add_child(field)
	return field

func _fill_palette() -> void:
	palette.clear()
	palette_ids.clear()
	var filter := category.get_item_text(category.selected)
	for id in Catalog.ITEMS:
		var item: Dictionary = Catalog.ITEMS[id]
		if item.get("legacy", false):
			continue
		if filter != "All" and item.category != filter:
			continue
		if not search.text.is_empty() and not item.label.to_lower().contains(search.text.to_lower()):
			continue
		palette_ids.append(id)
		var index := palette.add_icon_item(previews.textures.get(id))
		palette.set_item_tooltip(index, item.label)
		palette.set_item_metadata(index, id)
		if id == palette_id:
			palette.select(palette_ids.size() - 1)

func _preview_ready(id: String, texture: Texture2D) -> void:
	var index := palette_ids.find(id)
	if index >= 0:
		palette.set_item_icon(index, texture)

func _choose_palette(index: int) -> void:
	palette_id = palette_ids[index]
	placement = Catalog.record(palette_id)
	selected = -1
	moving = false
	placing = true
	snap_field.value = 8.0 if palette_id == "counter" else 1.0
	_make_ghost()
	_refresh_inspector()
	_update_selection_box()
	_status("Placing %s. Click to add; click an existing object to select it. Shift+click to stack." % Catalog.ITEMS[palette_id].label)

func _set_tool(place: bool) -> void:
	placing = place
	moving = false
	selected = -1
	_make_ghost()
	_refresh_inspector()
	_update_selection_box()
	_status("Click to place %s." % Catalog.ITEMS[palette_id].label if placing else "Click an object to select it.")

func _rebuild_world() -> void:
	get_tree().paused = false
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = World.new()
	world.name = "CustomLevel"
	add_child(world)
	world.build(document, build_mode)
	world.completed.connect(_finish)
	if build_mode:
		camera.make_current()
	_update_selection_box()

func _make_ghost() -> void:
	if is_instance_valid(ghost):
		ghost.free()
	ghost = Node3D.new()
	add_child(ghost)
	if not placing and not moving:
		return
	var data: Dictionary = document.objects[selected] if moving and selected >= 0 else placement
	var source := Catalog.instantiate(Catalog.record(data.id))
	source.process_mode = Node.PROCESS_MODE_DISABLED
	var marker_preview := source.get_node_or_null("EditorPreview") as Node3D
	if marker_preview != null:
		marker_preview.show()
	add_child(source)
	World.freeze_for_edit(source)
	var tint := StandardMaterial3D.new()
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.albedo_color = Color(0.25, 0.95, 0.8, 0.4)
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var nodes: Array[Node] = [source]
	nodes.append_array(source.find_children("*", "MeshInstance3D", true, false))
	for node in nodes:
		if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
			var visual := MeshInstance3D.new()
			visual.mesh = node.mesh
			visual.transform = source.global_transform.affine_inverse() * node.global_transform
			visual.material_override = tint
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ghost.add_child(visual)
	source.free()
	Catalog.apply_transform(ghost, data)
	ghost.hide()

func _create_grid() -> void:
	grid = MeshInstance3D.new()
	var lines := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.7, 0.8, 0.9, 0.25)
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for coordinate in range(-640, 641, 8):
		lines.surface_add_vertex(Vector3(coordinate, 0.03, -1140))
		lines.surface_add_vertex(Vector3(coordinate, 0.03, 140))
		lines.surface_add_vertex(Vector3(-640, 0.03, coordinate - 500))
		lines.surface_add_vertex(Vector3(640, 0.03, coordinate - 500))
	lines.surface_end()
	grid.mesh = lines
	add_child(grid)
	selection_box = MeshInstance3D.new()
	var box := BoxMesh.new()
	selection_box.mesh = box
	var tint := StandardMaterial3D.new()
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.albedo_color = Color(1, 0.7, 0.2, 0.16)
	selection_box.material_override = tint
	selection_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(selection_box)
	selection_box.hide()

func _update_selection_box() -> void:
	if not is_instance_valid(selection_box):
		return
	selection_box.hide()
	if not build_mode or selected < 0 or selected >= world.objects.size():
		transform_gizmo.hide()
		return
	var node: Node3D = world.objects[selected]
	var bounds := World.bounds_of(node)
	(selection_box.mesh as BoxMesh).size = bounds.size.max(Vector3.ONE * 0.2) + Vector3.ONE * 0.06
	selection_box.transform = node.transform * Transform3D(Basis.IDENTITY, bounds.get_center())
	selection_box.show()
	_update_transform_gizmo()

func _update_transform_gizmo() -> void:
	if not build_mode or selected < 0 or moving or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		transform_gizmo.hide()
		return
	var node: Node3D = world.objects[selected]
	var size := get_viewport().get_visible_rect().size
	var canvas_rect := Rect2(Vector2(366, 134), Vector2(maxf(size.x - 770, 0), maxf(size.y - 248, 0)))
	transform_gizmo.update_target(camera, node, World.bounds_of(node), canvas_rect)

func _transform_drag_started() -> void:
	_transform_before = document.duplicate(true)
	_scale_start = Catalog.vector(document.objects[selected].scale)
	_position_start = Catalog.vector(document.objects[selected].position)
	_rotation_start = Catalog.vector(document.objects[selected].rotation)

func _set_transform_tool(tool: int) -> void:
	transform_gizmo.set_mode(tool)
	if selected >= 0:
		moving = false
		placing = false
		_make_ghost()
	_refresh_inspector()
	_update_selection_box()
	_status(["Drag X / Y / Z to move along an axis, or XZ to move across the ground plane.", "Drag X / Y / Z around its ring to rotate. Angles snap by 15°; hold Shift for precision.", "Drag X / Y / Z to scale an axis, or ↗ to scale all axes."][tool])

func _rotation_drag_changed(degrees: float, axis: int) -> void:
	var amount := degrees if Input.is_physical_key_pressed(KEY_SHIFT) else snappedf(degrees, 15.0)
	var value := _rotation_start
	if not is_zero_approx(amount):
		value[axis] = wrapf(value[axis] + amount, -180.0, 180.0)
	document.objects[selected].rotation = [value.x, value.y, value.z]
	Catalog.apply_transform(world.objects[selected], document.objects[selected])
	_update_selection_box()
	for index in 3:
		transform_fields[index + 3].set_value_no_signal(value[index])

func _position_drag_changed(offset: Vector3) -> void:
	var value := _position_start
	for axis in 3:
		# Snap the displacement, so clicking or dragging another axis never jumps
		# an object's existing off-grid coordinates.
		if not is_zero_approx(offset[axis]):
			var amount := offset[axis] if Input.is_physical_key_pressed(KEY_SHIFT) else snappedf(offset[axis], snap_field.value)
			value[axis] = clampf(_position_start[axis] + amount, -10000, 10000)
	document.objects[selected].position = [value.x, value.y, value.z]
	Catalog.apply_transform(world.objects[selected], document.objects[selected])
	_update_selection_box()
	for axis in 3:
		transform_fields[axis].set_value_no_signal(value[axis])

func _scale_changed(factor: float, axis: int) -> void:
	var value := _scale_start
	if axis == 3:
		factor = clampf(factor, 0.05 / minf(value.x, minf(value.y, value.z)), 100.0 / maxf(value.x, maxf(value.y, value.z)))
		value *= factor
	else:
		value[axis] = clampf(value[axis] * factor, 0.05, 100.0)
	document.objects[selected].scale = [value.x, value.y, value.z]
	Catalog.apply_transform(world.objects[selected], document.objects[selected])
	_update_selection_box()
	for index in 3:
		transform_fields[index + 6].set_value_no_signal(value[index])

func _transform_drag_finished(cancelled: bool) -> void:
	if cancelled:
		document = _transform_before
		Catalog.apply_transform(world.objects[selected], document.objects[selected])
	elif not Catalog.vector(document.objects[selected].scale).is_equal_approx(_scale_start) or not Catalog.vector(document.objects[selected].position).is_equal_approx(_position_start) or not Catalog.vector(document.objects[selected].rotation).is_equal_approx(_rotation_start):
		_remember(_transform_before)
	_transform_before = {}
	_refresh_inspector()
	_update_selection_box()

func _process(delta: float) -> void:
	history_actions[0].disabled = undo_stack.is_empty()
	history_actions[1].disabled = redo_stack.is_empty()
	save_state.text = ("Unsaved changes" if dirty else "All changes saved") + "  ·  %d objects" % document.objects.size()
	if not build_mode:
		return
	_update_transform_gizmo()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var movement := Input.get_vector("left", "right", "forward", "backward")
		var vertical := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
		var direction := camera.basis * Vector3(movement.x, 0, movement.y) + Vector3.UP * vertical
		var speed := 280.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 80.0
		camera.position += direction.limit_length() * speed * delta

func _physics_process(_delta: float) -> void:
	if not build_mode or not is_instance_valid(ghost):
		return
	ghost.hide()
	if (not placing and not moving) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or _over_ui():
		return
	if placing and not Input.is_physical_key_pressed(KEY_SHIFT) and _pick_index() >= 0:
		return
	var point: Variant = _placement_point()
	if point == null:
		return
	ghost.position = point
	ghost.show()

func _over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null or browser.visible or confirm.visible

func _ray(mask: int) -> Dictionary:
	var mouse := _mouse_position
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(mouse) * 3000, mask)
	if moving and selected >= 0:
		var node: Node = world.objects[selected]
		var exclusions: Array[RID] = []
		if node is CollisionObject3D:
			exclusions.append(node.get_rid())
		for child in node.find_children("*", "CollisionObject3D", true, false):
			exclusions.append(child.get_rid())
		query.exclude = exclusions
	return get_world_3d().direct_space_state.intersect_ray(query)

func _placement_point() -> Variant:
	var point: Variant = null
	if surface_toggle.button_pressed:
		var hit := _ray(0xfffff)
		if not hit.is_empty() and hit.normal.y > 0.1:
			point = hit.position + Vector3.UP * height_field.value
	if point == null:
		var mouse := _mouse_position
		point = Plane(Vector3.UP, height_field.value).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if point == null:
		return null
	var result: Vector3 = point
	result.x = snappedf(result.x, snap_field.value)
	result.z = snappedf(result.z, snap_field.value)
	return result

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse_position = event.position
	if transform_gizmo.dragging:
		transform_gizmo.handle_drag_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and not browser.visible and not confirm.visible:
		var typing := get_viewport().gui_get_focus_owner() is LineEdit
		if event.physical_keycode == KEY_TAB and not typing:
			if build_mode:
				_play.call_deferred()
			else:
				_edit.call_deferred()
			get_viewport().set_input_as_handled()
			return
		if build_mode and (event.ctrl_pressed or event.meta_pressed) and event.physical_keycode == KEY_S:
			_save.call_deferred(false)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if browser.visible or confirm.visible:
			return
		if build_mode:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_set_tool(false)
		else:
			if _paused and not _completed:
				_resume()
			else:
				_pause(false)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed and build_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if browser.visible or confirm.visible:
		return
	if not build_mode:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			var focus := get_viewport().gui_get_focus_owner()
			if focus != null:
				focus.release_focus()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_world_click(event.shift_pressed)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			camera.position += camera.basis.z * (-3 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 3)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.5, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		var command: bool = event.ctrl_pressed or event.meta_pressed
		if command:
			match event.physical_keycode:
				KEY_S: _save(false)
				KEY_Z:
					if event.shift_pressed:
						_redo()
					else:
						_undo()
				KEY_Y: _redo()
		else:
			match event.physical_keycode:
				KEY_V: _set_tool(false)
				KEY_G: _set_transform_tool(GizmoMode.MOVE)
				KEY_R: _set_transform_tool(GizmoMode.ROTATE)
				KEY_T: _set_transform_tool(GizmoMode.SCALE)
				KEY_M: _move_selected()
				KEY_F: _focus_selected()
				KEY_DELETE, KEY_BACKSPACE: _delete_selected()
				KEY_BRACKETLEFT: _rotate(-15)
				KEY_BRACKETRIGHT: _rotate(15)
	get_viewport().set_input_as_handled()

func _pick_index() -> int:
	var hit := _ray(0xfffff)
	if not hit.is_empty():
		var node: Node = hit.collider
		while node != null and node != world:
			if node.has_meta("level_index"):
				return node.get_meta("level_index")
			node = node.get_parent()
	return -1

func _world_click(force_place := false) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	if not moving and not (placing and force_place):
		var index := _pick_index()
		if index >= 0 or not placing:
			_select_existing(index + 1)
			if index >= 0:
				_status("Selected %s. Choose Move, Rotate or Scale and drag its handles. Delete removes it." % Catalog.ITEMS[document.objects[index].id].label)
			return
	if placing or moving:
		var point: Variant = _placement_point()
		if point == null:
			return
		if not moving and document.objects.size() >= Store.MAX_OBJECTS:
			_status("The level already contains %d objects." % Store.MAX_OBJECTS)
			return
		if not moving:
			for existing in document.objects:
				if existing.id == placement.id and Catalog.vector(existing.position).is_equal_approx(point) and existing.rotation == placement.rotation and existing.scale == placement.scale:
					_status("That object is already placed here.")
					return
		_remember()
		var data: Dictionary = document.objects[selected] if moving else placement.duplicate(true)
		data.position = [point.x, point.y, point.z]
		if not moving:
			if data.id == "spawn":
				for i in range(document.objects.size() - 1, -1, -1):
					if document.objects[i].id == "spawn":
						document.objects.remove_at(i)
			document.objects.append(data)
			selected = document.objects.size() - 1
			placing = false
			_make_ghost()
		else:
			moving = false
			_make_ghost()
		_rebuild_world()
		_refresh_inspector()
		_status("Placed %s. Drag its handles to move, rotate or scale; Delete to remove. Choose a model or Place to add another." % Catalog.ITEMS[data.id].label)

func _refresh_inspector() -> void:
	_rebuilding_ui = true
	place_button.set_pressed_no_signal(placing)
	select_button.set_pressed_no_signal(not placing)
	move_handle_button.set_pressed_no_signal(transform_gizmo.mode == GizmoMode.MOVE)
	rotate_handle_button.set_pressed_no_signal(transform_gizmo.mode == GizmoMode.ROTATE)
	scale_handle_button.set_pressed_no_signal(transform_gizmo.mode == GizmoMode.SCALE)
	for button in selection_actions:
		button.disabled = selected < 0
	object_list.clear()
	object_list.add_item("Choose a placed object…")
	for i in document.objects.size():
		object_list.add_item("%d · %s" % [i + 1, Catalog.ITEMS[document.objects[i].id].label])
	object_list.select(selected + 1)
	var data: Dictionary = document.objects[selected] if selected >= 0 else placement
	selection_label.text = Catalog.ITEMS[data.id].label
	selection_hint.text = ["Drag X / Y / Z to move, XZ for the ground plane.\nShift disables grid snap.", "Drag X / Y / Z around its ring to rotate.\n15° snap; Shift for precise angles.", "Drag X / Y / Z or ↗ handles to scale."][transform_gizmo.mode] if selected >= 0 else ("Placement preview · click to add" if placing else "Click a placed object to select it.")
	if data.id == "goal":
		selection_hint.text += "\nScale X, Y and Z to resize the trigger box. Hidden during play."
	elif data.id == "spawn":
		selection_hint.text += "\nThe player starts here. Hidden during play."
	for index in transform_fields.size():
		var key: String = ["position", "rotation", "scale"][index / 3]
		transform_fields[index].set_value_no_signal(data[key][index % 3])
		transform_fields[index].editable = selected >= 0 or index >= 3
	_rebuilding_ui = false

func _transform_changed(value: float, index: int) -> void:
	if _rebuilding_ui:
		return
	var data: Dictionary = document.objects[selected] if selected >= 0 else placement
	if selected >= 0:
		_remember()
	var key: String = ["position", "rotation", "scale"][index / 3]
	data[key][index % 3] = value
	if selected >= 0:
		Catalog.apply_transform(world.objects[selected], data)
		_update_selection_box()
	if is_instance_valid(ghost) and (placing or moving):
		Catalog.apply_transform(ghost, data)

func _rotate(amount: float) -> void:
	var data: Dictionary = document.objects[selected] if selected >= 0 else placement
	_transform_changed(wrapf(float(data.rotation[1]) + amount, -180, 180), 4)
	_refresh_inspector()

func _select_existing(index: int) -> void:
	if _rebuilding_ui:
		return
	selected = index - 1
	placing = false
	moving = false
	_make_ghost()
	_refresh_inspector()
	_update_selection_box()

func _focus_selected() -> void:
	if selected < 0:
		_status("Select a placed object first.")
		return
	var node: Node3D = world.objects[selected]
	var bounds: AABB = node.global_transform * World.bounds_of(node)
	var center := bounds.get_center()
	var distance := maxf(bounds.size.length() * 1.3, 12.0)
	camera.position = center + Vector3(0.5, 0.65, 0.8).normalized() * distance
	camera.look_at(center)

func _move_selected() -> void:
	if selected < 0:
		_status("Select an object first.")
		return
	moving = true
	placing = false
	transform_gizmo.hide()
	_make_ghost()
	_status("Click to move the selected object. Escape cancels.")

func _duplicate_selected() -> void:
	if selected < 0 or document.objects.size() >= Store.MAX_OBJECTS:
		return
	if document.objects[selected].id == "spawn":
		_status("There is one Player start per level. Move it instead.")
		return
	_remember()
	var copy: Dictionary = document.objects[selected].duplicate(true)
	copy.position[0] += snap_field.value
	document.objects.append(copy)
	selected = document.objects.size() - 1
	moving = false
	_make_ghost()
	_rebuild_world()
	_refresh_inspector()

func _delete_selected() -> void:
	if selected < 0:
		return
	_remember()
	var label: String = Catalog.ITEMS[document.objects[selected].id].label
	document.objects.remove_at(selected)
	selected = -1
	moving = false
	_make_ghost()
	_rebuild_world()
	_refresh_inspector()
	_status("Deleted %s. Ctrl / Cmd + Z to undo." % label)

func _remember(before: Dictionary = {}) -> void:
	undo_stack.append((document if before.is_empty() else before).duplicate(true))
	if undo_stack.size() > 100:
		undo_stack.pop_front()
	redo_stack.clear()
	dirty = true

func _undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(document.duplicate(true))
	document = undo_stack.pop_back()
	_after_history()

func _redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(document.duplicate(true))
	document = redo_stack.pop_back()
	_after_history()

func _after_history() -> void:
	dirty = true
	selected = -1
	moving = false
	name_field.text = document.name
	_rebuild_world()
	_make_ghost()
	_refresh_inspector()

func _save(copy: bool) -> void:
	var result := Store.save_level(document, "" if copy else filename)
	if result.has("error"):
		_status(result.error)
		return
	filename = result.filename
	dirty = false
	var problem := Store.playable_error(document)
	_status("Saved “%s”. %s" % [document.name, "Available in My levels." if problem.is_empty() else "Draft: " + problem])

func _load_document(next: Dictionary, next_filename: String, editing: bool) -> void:
	browser.hide()
	document = Store.normalize(next)
	filename = next_filename
	dirty = filename.is_empty()
	undo_stack.clear()
	redo_stack.clear()
	selected = -1
	moving = false
	placing = true
	_paused = false
	_completed = false
	build_mode = editing
	name_field.text = document.name
	$KitchenBase.reset()
	_rebuild_world()
	_update_mode_ui()
	_make_ghost()
	ghost.visible = false
	_refresh_inspector()

func _saved_level_deleted(deleted_filename: String) -> void:
	if filename == deleted_filename:
		filename = ""
		dirty = true
		_status("The saved level was deleted. This open layout is now unsaved.")
	_status("Loaded “%s”." % document.name)

func _play() -> void:
	var problem := Store.playable_error(document)
	if not problem.is_empty():
		_status(problem)
		return
	_editor_camera_transform = camera.transform
	build_mode = false
	selected = -1
	_paused = false
	_completed = false
	$KitchenBase.reset()
	_rebuild_world()
	_update_mode_ui()

func _edit() -> void:
	build_mode = true
	previews.generate.call_deferred()
	_paused = false
	_completed = false
	camera.transform = _editor_camera_transform
	$KitchenBase.reset()
	_rebuild_world()
	_update_mode_ui()
	_make_ghost()
	_refresh_inspector()
	_status("Back in the editor. The original layout has been restored.")

func _restart() -> void:
	_paused = false
	_completed = false
	$KitchenBase.reset()
	_rebuild_world()
	_update_mode_ui()

func _update_mode_ui() -> void:
	$KitchenBase.process_mode = Node.PROCESS_MODE_DISABLED if build_mode else Node.PROCESS_MODE_PAUSABLE
	editor_ui.visible = build_mode
	play_ui.visible = not build_mode
	pause_panel.hide()
	grid.visible = build_mode and not surface_toggle.button_pressed
	if is_instance_valid(ghost):
		ghost.hide()
	play_title.text = "%s\nWASD: roll · Space: jump · 1–5: character · Click: equipment\nR: respawn · Esc: pause · Tab: edit" % document.name
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if build_mode else Input.MOUSE_MODE_CAPTURED

func _finish() -> void:
	if build_mode:
		return
	_completed = true
	_pause(true)

func _pause(won: bool) -> void:
	_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_title.text = "Level complete!" if won or _completed else "Paused"
	pause_panel.show()

func _resume() -> void:
	if _completed:
		_restart()
		return
	_paused = false
	get_tree().paused = false
	pause_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _guard_unsaved(action: Callable) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not dirty:
		action.call()
		return
	for connection in confirm.confirmed.get_connections():
		confirm.confirmed.disconnect(connection.callable)
	confirm.confirmed.connect(action, CONNECT_ONE_SHOT)
	confirm.popup_centered()

func _menu() -> void:
	_guard_unsaved(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu_alternative.tscn")
	)

func _status(message: String) -> void:
	status.text = message

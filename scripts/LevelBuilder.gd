class_name LevelBuilder
extends Node3D

const Catalog = preload("res://scripts/level_editor/catalog.gd")
const Store = preload("res://scripts/level_editor/level_store.gd")
const World = preload("res://scripts/level_editor/level_world.gd")
const Browser = preload("res://scripts/level_editor/level_browser.gd")

@export var start_in_editor := true

@onready var camera: Camera3D = $EditorCamera
var document: Dictionary
var filename := ""
var build_mode := true
var dirty := false
var world: Node3D
var selected := -1
var placing := true
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
var selection_label: Label
var transform_fields: Array[SpinBox] = []
var play_title: Label
var browser: Window
var confirm: ConfirmationDialog
var pause_panel: PanelContainer
var pause_title: Label

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
	document = launch.get("document", Store.new_level()).duplicate(true)
	filename = launch.get("filename", "")
	build_mode = launch.get("editing", start_in_editor)
	dirty = filename.is_empty()
	_create_ui()
	_create_grid()
	_editor_camera_transform = camera.transform
	_rebuild_world()
	_update_mode_ui()
	if build_mode:
		_make_ghost()
		_status(_load_error if not _load_error.is_empty() else "Choose an object, then click the world to place it. Right mouse + WASD to fly.")

func _create_ui() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	editor_ui = Control.new()
	editor_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var editor_theme := Theme.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.075, 0.09, 0.11, 0.98)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	editor_theme.set_stylebox("panel", "PanelContainer", panel_style)
	editor_ui.theme = editor_theme
	editor_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(editor_ui)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 58
	editor_ui.add_child(top)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	top.add_child(toolbar)
	name_field = LineEdit.new()
	name_field.text = document.name
	name_field.placeholder_text = "Level name"
	name_field.max_length = 80
	name_field.custom_minimum_size.x = 270
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.text_changed.connect(func(value: String):
		document.name = value
		dirty = true
	)
	toolbar.add_child(name_field)
	_button(toolbar, "Save", _save.bind(false))
	_button(toolbar, "Save copy", _save.bind(true))
	_button(toolbar, "My levels", func(): _guard_unsaved(browser.show_levels))
	_button(toolbar, "Play  [Tab]", _play)
	_button(toolbar, "Menu", _menu)

	var left := PanelContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_top = 68
	left.offset_bottom = -90
	left.offset_left = 12
	left.offset_right = 300
	editor_ui.add_child(left)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	left.add_child(column)
	_label(column, "OBJECTS", 22)
	search = LineEdit.new()
	search.placeholder_text = "Search objects…"
	column.add_child(search)
	search.text_changed.connect(func(_value: String): _fill_palette())
	category = OptionButton.new()
	for title in ["All", "Surfaces", "Kitchen", "Obstacles", "Powerups", "Level"]:
		category.add_item(title)
	column.add_child(category)
	category.item_selected.connect(func(_index: int): _fill_palette())
	palette = ItemList.new()
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(palette)
	palette.item_selected.connect(_choose_palette)
	var modes := HBoxContainer.new()
	column.add_child(modes)
	_button(modes, "Place", _set_tool.bind(true))
	_button(modes, "Select  [V]", _set_tool.bind(false))
	_label(column, "Placement", 18)
	snap_field = _number(column, "Grid snap", 0.25, 32, 0.25, 8)
	snap_field.tooltip_text = "Use 8 for counter tiles; 0.25 or 1 for precise equipment placement."
	height_field = _number(column, "Plane / lift Y", -1000, 1000, 0.25, 0)
	height_field.value_changed.connect(func(_value: float): grid.position.y = height_field.value)
	surface_toggle = CheckBox.new()
	surface_toggle.text = "Place on surfaces + lift"
	surface_toggle.button_pressed = true
	column.add_child(surface_toggle)
	_label(column, "Unchecked: place on the height plane.\nR / Shift+R: rotate by 15°", 15)

	var right := PanelContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_top = 68
	right.offset_bottom = -90
	right.offset_left = -295
	right.offset_right = -12
	editor_ui.add_child(right)
	var scroll := ScrollContainer.new()
	right.add_child(scroll)
	var inspector := VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 8)
	scroll.add_child(inspector)
	object_list = OptionButton.new()
	object_list.fit_to_longest_item = false
	inspector.add_child(object_list)
	object_list.item_selected.connect(_select_existing)
	selection_label = _label(inspector, "Placing: Counter tile", 18)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for section in ["Position", "Rotation (degrees)", "Scale"]:
		_label(inspector, section, 18)
		for axis in ["X", "Y", "Z"]:
			var index := transform_fields.size()
			var field := _number(inspector, axis, 0.05 if index >= 6 else -10000.0,
				100.0 if index >= 6 else 10000.0, 0.05 if index >= 6 else 0.25, 1 if index >= 6 else 0)
			transform_fields.append(field)
			field.value_changed.connect(_transform_changed.bind(index))
	_button(inspector, "Focus selected  [F]", _focus_selected)
	_button(inspector, "Move with mouse  [M]", _move_selected)
	_button(inspector, "Duplicate", _duplicate_selected)
	_button(inspector, "Delete  [Delete]", _delete_selected)
	var history_row := HBoxContainer.new()
	inspector.add_child(history_row)
	_button(history_row, "Undo", _undo)
	_button(history_row, "Redo", _redo)
	_label(inspector, "Select an object to edit its transform.\nStart and finish are in Level.\nSaves without them remain drafts.", 15)

	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -78
	editor_ui.add_child(bottom)
	var footer := VBoxContainer.new()
	bottom.add_child(footer)
	status = _label(footer, "", 18)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(footer, "Right mouse: look • WASD: fly • Q/E: down/up • Shift: faster • Wheel: zoom • Ctrl/Cmd+S: save • Ctrl/Cmd+Z: undo", 16)

	play_ui = Control.new()
	play_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_ui.theme = editor_theme
	play_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(play_ui)
	play_title = _label(play_ui, "", 24)
	play_title.position = Vector2(24, 18)
	var crosshair := _label(play_ui, "+", 22)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -210
	pause_panel.offset_right = 210
	pause_panel.offset_top = -190
	pause_panel.offset_bottom = 190
	play_ui.add_child(pause_panel)
	var pause_buttons := VBoxContainer.new()
	pause_buttons.add_theme_constant_override("separation", 12)
	pause_panel.add_child(pause_buttons)
	pause_title = _label(pause_buttons, "Paused", 28)
	_button(pause_buttons, "Resume", _resume)
	_button(pause_buttons, "Restart level", _restart)
	_button(pause_buttons, "Edit this level", _edit)
	_button(pause_buttons, "My levels", func(): _guard_unsaved(browser.show_levels))
	_button(pause_buttons, "Main menu", _menu)

	browser = Browser.new()
	add_child(browser)
	browser.hide()
	browser.chosen.connect(_load_document)
	confirm = ConfirmationDialog.new()
	confirm.title = "Unsaved changes"
	confirm.dialog_text = "Leave this layout without saving your changes?"
	confirm.ok_button_text = "Discard changes"
	add_child(confirm)
	_fill_palette()
	_refresh_inspector()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		if filter != "All" and item.category != filter:
			continue
		if not search.text.is_empty() and not item.label.to_lower().contains(search.text.to_lower()):
			continue
		palette_ids.append(id)
		palette.add_item(item.label)
		if id == palette_id:
			palette.select(palette_ids.size() - 1)

func _choose_palette(index: int) -> void:
	palette_id = palette_ids[index]
	placement = Catalog.record(palette_id)
	selected = -1
	moving = false
	placing = true
	snap_field.value = 8.0 if palette_id == "counter" else 1.0
	_make_ghost()
	_refresh_inspector()
	_status("Placing %s. Click the world to place; V to select existing objects." % Catalog.ITEMS[palette_id].label)

func _set_tool(place: bool) -> void:
	placing = place
	moving = false
	selected = -1
	_make_ghost()
	_refresh_inspector()
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
	for coordinate in range(-160, 161, 8):
		lines.surface_add_vertex(Vector3(coordinate, 0.03, -160))
		lines.surface_add_vertex(Vector3(coordinate, 0.03, 160))
		lines.surface_add_vertex(Vector3(-160, 0.03, coordinate))
		lines.surface_add_vertex(Vector3(160, 0.03, coordinate))
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
		return
	var node: Node3D = world.objects[selected]
	var bounds := World.bounds_of(node)
	(selection_box.mesh as BoxMesh).size = bounds.size.max(Vector3.ONE * 0.2) + Vector3.ONE * 0.06
	selection_box.transform = node.transform * Transform3D(Basis.IDENTITY, bounds.get_center())
	selection_box.show()

func _process(delta: float) -> void:
	if not build_mode:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var movement := Input.get_vector("left", "right", "forward", "backward")
		var vertical := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
		var direction := camera.basis * Vector3(movement.x, 0, movement.y) + Vector3.UP * vertical
		var speed := 65.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 25.0
		camera.position += direction.limit_length() * speed * delta

func _physics_process(_delta: float) -> void:
	if not build_mode or not is_instance_valid(ghost):
		return
	ghost.hide()
	if (not placing and not moving) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or _over_ui():
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
		var hit := _ray(World.PICK_LAYER - 1)
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
			_world_click()
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
				KEY_M: _move_selected()
				KEY_F: _focus_selected()
				KEY_DELETE, KEY_BACKSPACE: _delete_selected()
				KEY_R: _rotate(-15 if event.shift_pressed else 15)
	get_viewport().set_input_as_handled()

func _world_click() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
		else:
			moving = false
			_make_ghost()
		_rebuild_world()
		_refresh_inspector()
		_status("Placed %s at (%.2f, %.2f, %.2f)." % [Catalog.ITEMS[data.id].label, point.x, point.y, point.z])
	else:
		var hit := _ray(0xfffff)
		selected = -1
		if not hit.is_empty():
			var node: Node = hit.collider
			while node != null and node != world:
				if node.has_meta("level_index"):
					selected = node.get_meta("level_index")
					break
				node = node.get_parent()
		_refresh_inspector()
		_update_selection_box()

func _refresh_inspector() -> void:
	_rebuilding_ui = true
	object_list.clear()
	object_list.add_item("Choose a placed object…")
	for i in document.objects.size():
		object_list.add_item("%d · %s" % [i + 1, Catalog.ITEMS[document.objects[i].id].label])
	object_list.select(selected + 1)
	var data: Dictionary = document.objects[selected] if selected >= 0 else placement
	selection_label.text = ("Selected: " if selected >= 0 else "Placing: ") + Catalog.ITEMS[data.id].label
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
	document.objects.remove_at(selected)
	selected = -1
	moving = false
	_make_ghost()
	_rebuild_world()
	_refresh_inspector()

func _remember() -> void:
	undo_stack.append(document.duplicate(true))
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
	document = next.duplicate(true)
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
	_rebuild_world()
	_update_mode_ui()
	_make_ghost()
	ghost.visible = false
	_refresh_inspector()
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
	_rebuild_world()
	_update_mode_ui()

func _edit() -> void:
	build_mode = true
	_paused = false
	_completed = false
	camera.transform = _editor_camera_transform
	_rebuild_world()
	_update_mode_ui()
	_make_ghost()
	_refresh_inspector()
	_status("Back in the editor. The original layout has been restored.")

func _restart() -> void:
	_paused = false
	_completed = false
	_rebuild_world()
	_update_mode_ui()

func _update_mode_ui() -> void:
	editor_ui.visible = build_mode
	play_ui.visible = not build_mode
	pause_panel.hide()
	grid.visible = build_mode
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
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)

func _status(message: String) -> void:
	status.text = message

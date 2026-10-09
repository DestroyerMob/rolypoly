extends Control
signal drag_started
signal scale_changed(factor: float, axis: int)
signal position_changed(offset: Vector3)
signal rotation_changed(degrees: float, axis: int)
signal drag_finished(cancelled: bool)

enum Mode { MOVE, ROTATE, SCALE }
var dragging := false
var mode := Mode.MOVE
var _axis := -1
var _origin := Vector2.ZERO
var _direction := Vector2.RIGHT
var _length := 100.0
var _center := Vector2.ZERO
var _handles: Array[Button] = []
var _directions: Array[Vector2] = []
var _camera: Camera3D
var _world_center := Vector3.ZERO
var _drag_plane: Plane
var _plane_origin: Variant = null
var _units_per_pixel := 1.0
var _rotation_vector := Vector2.ZERO
var _rotation_degrees := 0.0
var _ring_radius := 140.0

func set_mode(value: Mode) -> void:
	mode = value
	for axis in _handles.size():
		_handles[axis].text = (["X", "Y", "Z", "XZ"] if mode == Mode.MOVE else ["X", "Y", "Z", "↗"])[axis]
		var tips := ["Drag to scale X", "Drag to scale Y", "Drag to scale Z", "Drag to scale all axes"]
		if mode == Mode.MOVE:
			tips = ["Drag to move along world X", "Drag to move vertically along world Y", "Drag to move along world Z", "Drag to move on the X/Z plane"]
		elif mode == Mode.ROTATE:
			tips = ["Drag around the ring to rotate X", "Drag around the ring to rotate Y", "Drag around the ring to rotate Z", ""]
		_handles[axis].tooltip_text = tips[axis]
		_handles[axis].visible = mode != Mode.ROTATE or axis < 3
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for axis in 4:
		var button := Button.new()
		button.text = ["X", "Y", "Z", "↗"][axis]
		button.tooltip_text = ["Drag to scale X", "Drag to scale Y", "Drag to scale Z", "Drag to scale all axes"][axis]
		button.custom_minimum_size = Vector2(32, 32)
		button.size = Vector2(32, 32)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		add_child(button)
		for state in ["normal", "hover", "pressed"]:
			var style := button.get_theme_stylebox(state).duplicate() as StyleBox
			style.content_margin_left = 4
			style.content_margin_right = 4
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_color", [Color("f69fa4"), Color("91e5c1"), Color("9abcf4"), Color("ffcf75")][axis])
		button.gui_input.connect(_handle_input.bind(axis))
		_handles.append(button)
		_directions.append(Vector2.RIGHT)
	set_mode(mode)
	hide()

func update_target(camera: Camera3D, target: Node3D, bounds: AABB, canvas_rect: Rect2) -> void:
	if dragging and mode != Mode.MOVE:
		return
	var center: Vector3 = target.global_transform * bounds.get_center()
	if mode == Mode.ROTATE:
		center = target.global_position
	_camera = camera
	_world_center = center
	if camera.is_position_behind(center):
		hide()
		return
	_center = camera.unproject_position(center)
	if not canvas_rect.has_point(_center):
		hide()
		return
	show()
	if mode == Mode.ROTATE:
		var clearance := minf(minf(_center.x - canvas_rect.position.x, canvas_rect.end.x - _center.x), minf(_center.y - canvas_rect.position.y, canvas_rect.end.y - _center.y))
		_ring_radius = clampf(clearance - 18.0, 40.0, 140.0)
		for axis in 3:
			var angle := float(axis) * TAU / 3.0 - PI / 6.0
			var radial := Vector2.from_angle(angle)
			var point := _center + radial * _ring_radius * (0.55 + axis * 0.2)
			_handles[axis].position = point.clamp(canvas_rect.position + Vector2.ONE * 18, canvas_rect.end - Vector2.ONE * 18) - Vector2.ONE * 16
			_directions[axis] = radial.orthogonal()
		queue_redraw()
		return
	var world_bounds: AABB = target.global_transform * bounds
	for axis in 3:
		var endpoint := bounds.get_center()
		endpoint[axis] += maxf(bounds.size[axis] * 0.5, 0.5)
		var world_endpoint: Vector3 = target.global_transform * endpoint
		if mode == Mode.MOVE:
			world_endpoint = center
			world_endpoint[axis] += maxf(world_bounds.size[axis] * 0.5, 0.5)
		var projected := camera.unproject_position(world_endpoint)
		var direction := projected - _center
		if direction.length() < 8.0:
			direction = [Vector2.RIGHT, Vector2.UP, Vector2(-1, 0.6)][axis] * 60.0
		_directions[axis] = direction.normalized()
		var point := _center + _directions[axis] * clampf(direction.length() + 28.0, 60.0, 180.0)
		_handles[axis].position = point.clamp(canvas_rect.position + Vector2.ONE * 18, canvas_rect.end - Vector2.ONE * 18) - Vector2.ONE * 16
	_directions[3] = Vector2(1, -1).normalized()
	_handles[3].position = (_center + _directions[3] * 100).clamp(canvas_rect.position + Vector2.ONE * 18, canvas_rect.end - Vector2.ONE * 18) - Vector2.ONE * 16
	queue_redraw()

func _draw() -> void:
	if mode == Mode.ROTATE:
		for axis in 3:
			var color: Color = [Color("f69fa4"), Color("91e5c1"), Color("9abcf4")][axis]
			draw_arc(_center, _ring_radius * (0.55 + axis * 0.2), 0, TAU, 96, color, 2.0, true)
		return
	for axis in _handles.size():
		draw_line(_center, _handles[axis].position + Vector2.ONE * 16, Color(1, 1, 1, 0.65), 2.0, true)

func _handle_input(event: InputEvent, axis: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		_axis = axis
		_origin = _handles[axis].get_global_transform() * event.position
		_direction = (_handles[axis].position + Vector2.ONE * 16 - _center).normalized()
		_length = maxf(_center.distance_to(_origin), 60.0)
		_rotation_vector = _origin - _center
		_rotation_degrees = 0.0
		if mode == Mode.MOVE:
			var normal := Vector3.UP
			if axis < 3:
				var world_axis := Vector3.ZERO
				world_axis[axis] = 1.0
				var view := -_camera.project_ray_normal(_center)
				normal = view - world_axis * view.dot(world_axis)
			_drag_plane = Plane(normal.normalized(), _world_center) if normal.length() > 0.1 else Plane()
			_plane_origin = _plane_point(_origin)
			var pixels := _center.distance_to(_camera.unproject_position(_world_center + _camera.global_basis.x))
			_units_per_pixel = 1.0 / maxf(pixels, 0.01)
		drag_started.emit()
		accept_event()

func _plane_point(mouse: Vector2) -> Variant:
	var direction := _camera.project_ray_normal(mouse)
	if absf(_drag_plane.normal.dot(direction)) < 0.03:
		return null
	return _drag_plane.intersects_ray(_camera.project_ray_origin(mouse), direction)

func handle_drag_input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseMotion:
		var distance: float = (event.position - _origin).dot(_direction)
		if mode == Mode.ROTATE:
			var vector: Vector2 = event.position - _center
			if vector.length() >= 12.0:
				_rotation_degrees += rad_to_deg(_rotation_vector.angle_to(vector))
				_rotation_vector = vector
				rotation_changed.emit(_rotation_degrees, _axis)
		elif mode == Mode.MOVE:
			var point: Variant = _plane_point(event.position)
			var offset := Vector3.ZERO
			if point != null and _plane_origin != null:
				offset = point - _plane_origin
			elif _axis < 3:
				offset[_axis] = distance * _units_per_pixel
			else:
				var mouse_delta: Vector2 = event.position - _origin
				offset = (_camera.global_basis.x * mouse_delta.x - _camera.global_basis.y * mouse_delta.y) * _units_per_pixel
			if _axis < 3:
				var amount := offset[_axis]
				offset = Vector3.ZERO
				offset[_axis] = amount
			else:
				offset.y = 0.0
			position_changed.emit(offset)
		else:
			scale_changed.emit(maxf(0.01, 1.0 + distance / _length), _axis)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		drag_finished.emit(false)
		return
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		dragging = false
		drag_finished.emit(true)
	get_viewport().set_input_as_handled()

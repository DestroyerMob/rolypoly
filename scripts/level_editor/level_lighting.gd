@tool
extends Node3D

const CAPTURE_LAYER := 1 << 17
var _refresh_delay := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prepare_capture.call_deferred(get_parent().get_node_or_null("_Set"))
	request_refresh()

static func prepare_capture(root: Node) -> void:
	if root == null or root is RigidBody3D or root is CharacterBody3D or root is AnimatableBody3D:
		return
	if root.name == &"EditorPreview":
		return
	if root is GeometryInstance3D:
		root.layers |= CAPTURE_LAYER
	for child in root.get_children():
		prepare_capture(child)

func request_refresh() -> void:
	_refresh_delay = 0.4
	set_process(true)

func _process(delta: float) -> void:
	if _refresh_delay < 0.0:
		set_process(false)
		return
	_refresh_delay -= delta
	if _refresh_delay > 0.0:
		return
	for probe: ReflectionProbe in $Reflections.get_children():
		probe.origin_offset = probe.origin_offset
	_refresh_delay = -1.0
	set_process(false)

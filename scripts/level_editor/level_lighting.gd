@tool
extends Node3D

# Keep the camera's regular layer and add a separate layer for static captures.
# Players, moving obstacles, editor markers and placement previews never enter it.
const CAPTURE_LAYER := 1 << 17
var _refresh_delay := -1.0

func _ready() -> void:
	# Level editing disables the kitchen's gameplay scripts, not its lighting.
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
	# Capture once after the room's generated meshes have entered the tree.
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
		# Reapplying the capture origin invalidates the cubemap without moving the
		# probe or enabling continuous captures. Godot spreads UPDATE_ONCE work.
		probe.origin_offset = probe.origin_offset
	_refresh_delay = -1.0
	set_process(false)

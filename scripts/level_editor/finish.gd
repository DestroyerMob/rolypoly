extends Area3D
signal level_completed(player: Player)
var _finished := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_create_outline()

func _on_body_entered(body: Node3D) -> void:
	if body is Player and not _finished:
		_finished = true
		level_completed.emit(body)

func _create_outline() -> void:
	var lines := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.7, 0.3)
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var corners: Array[Vector3] = []
	for x in [-3.0, 3.0]:
		for y in [0.0, 6.0]:
			for z in [-3.0, 3.0]:
				corners.append(Vector3(x, y, z))
	for i in 8:
		for bit in [1, 2, 4]:
			var other: int = i ^ bit
			if i < other:
				lines.surface_add_vertex(corners[i])
				lines.surface_add_vertex(corners[other])
	lines.surface_end()
	var outline := MeshInstance3D.new()
	outline.mesh = lines
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$EditorPreview.add_child(outline)

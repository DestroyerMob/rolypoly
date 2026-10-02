class_name BoilingPot
extends Node3D

## Time inside the pot before an egg counts as cooked.
@export var cook_time := 10.0
## Time inside the pot before a cooked egg tips over into overcooked.
@export var overcook_time := 15.0
@export var lid_visible := false

enum CookState { UNDERCOOKED, COOKED, OVERCOOKED }

const BODY_MESH := ^"Model/Cylinder_006"
const LID_PARTS: Array[NodePath] = [^"Model/Cylinder_009", ^"Model/Cylinder_010"]

@onready var cook_area: Area3D = $CookArea
@onready var walls: StaticBody3D = $Walls

# body -> {elapsed: float, state: CookState}
var _tracked: Dictionary = {}

func _ready() -> void:
	cook_area.body_entered.connect(_on_body_entered)
	cook_area.body_exited.connect(_on_body_exited)
	for path in LID_PARTS:
		var lid_part := get_node_or_null(path) as Node3D
		if lid_part:
			lid_part.visible = lid_visible
	_build_wall_collision()

func _process(delta: float) -> void:
	if _tracked.is_empty():
		return
	for body in _tracked.keys():
		if not is_instance_valid(body):
			_tracked.erase(body)
			continue
		var data: Dictionary = _tracked[body]
		data.elapsed += delta
		var new_state: CookState = data.state

		if data.elapsed >= overcook_time:
			new_state = CookState.OVERCOOKED
		elif data.elapsed >= cook_time:
			new_state = CookState.COOKED

		if new_state != data.state:
			data.state = new_state
			match new_state:
				CookState.COOKED:
					print("cooked")
				CookState.OVERCOOKED:
					print("overcooked")
		_tracked[body] = data

func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	if player.vegetable_type != Player.VegetableType.EGG:
		print("not egg")
		return
	_tracked[body] = {"elapsed": 0.0, "state": CookState.UNDERCOOKED}

func _on_body_exited(body: Node3D) -> void:
	if not _tracked.has(body):
		return
	var data: Dictionary = _tracked[body]
	if data.state == CookState.UNDERCOOKED:
		print("undercooked")
	_tracked.erase(body)

# Baked from the model so the walls match the mesh exactly (same technique as pot.gd).
func _build_wall_collision() -> void:
	var body_mesh := get_node_or_null(BODY_MESH) as MeshInstance3D
	if body_mesh == null or body_mesh.mesh == null:
		push_warning("BoilingPot: body mesh not found, the walls have no collision.")
		return
	var to_pot: Transform3D = ($Model as Node3D).transform * body_mesh.transform
	var faces := body_mesh.mesh.get_faces()
	for i in faces.size():
		faces[i] = to_pot * faces[i]
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.name = "WallShape"
	collision.shape = shape
	walls.add_child(collision)

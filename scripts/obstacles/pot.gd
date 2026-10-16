class_name Pot
extends Node3D

## Emitted the first time a Player drops into the pot.
signal level_completed(player: Player)
## An NPC dropped in. Doesn't end the level.
signal npc_finished(npc: NPC)

## Scene loaded after the win. Leave empty to only emit the signal.
@export_file("*.tscn") var return_scene := "res://scenes/main_menu_alternative.tscn"
@export var finish_delay := 1
@export var lid_visible := false

const BODY_MESH := ^"Model/Cylinder_006"
const LID_PARTS: Array[NodePath] = [^"Model/Cylinder_009", ^"Model/Cylinder_010"]

@onready var goal_area: Area3D = $GoalArea
@onready var walls: StaticBody3D = $Walls

var _finished := false

func _ready() -> void:
	goal_area.body_entered.connect(_on_goal_area_body_entered)
	for path in LID_PARTS:
		var lid_part := get_node_or_null(path) as Node3D
		if lid_part:
			lid_part.visible = lid_visible
	_build_wall_collision()

# Baked from the model so the walls match the mesh exactly, including its non-uniform scale.
func _build_wall_collision() -> void:
	var body_mesh := get_node_or_null(BODY_MESH) as MeshInstance3D
	if body_mesh == null or body_mesh.mesh == null:
		push_warning("Pot: body mesh not found, the walls have no collision.")
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

func _on_goal_area_body_entered(body: Node3D) -> void:
	if body is NPC:
		if not body.has_finished:
			body.reach_finish()
			npc_finished.emit(body)
		return
	var player := body as Player
	if player == null or _finished:
		return
	_finished = true
	player.enter_condition(Player.Condition.WIN)
	player.set_physics_process(false)
	level_completed.emit(player)
	if return_scene.is_empty():
		return
	await get_tree().create_timer(finish_delay).timeout
	get_tree().change_scene_to_file(return_scene)

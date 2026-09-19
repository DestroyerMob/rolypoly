@tool
class_name Face
extends Node3D

#don't cache camera as it can change
@export var offset_distance := 0.14
@export var normal_face: Texture2D = preload("res://assets/face/happy.png")
#@onready var veggie_mommy: Player # Defers default value computation until after the node is in the tree
@onready var veggie_mommy: Player = _resolve_player()

#BUILD DICTIONARY OF conditions and assign to conditions the assets
const FACES := {
	Player.Condition.DIZZY: preload("res://assets/face/dizzy.png"),
	Player.Condition.HURT: preload("res://assets/face/hurt.png"),
	Player.Condition.DEAD: preload("res://assets/face/dead.png"),
	Player.Condition.WIN: preload("res://assets/face/win.png"),
}

func _ready():
	if veggie_mommy == null:
		return
	veggie_mommy.condition_changed.connect(_on_condition_changed)

func _on_condition_changed(new_condition) -> void:
	if new_condition == Player.Condition.NORMAL:
		$Face_Decal.texture_albedo = normal_face
	else:
		$Face_Decal.texture_albedo = FACES[new_condition]
	#self.top_level = true
	
func _resolve_player() -> Player: #return the player 
	var node: Node = self #ensure the type can hold all possible node types
	while node != null:
		node = node.get_parent()
		if node is Player:
			return node
	#no nodes are players
	return null

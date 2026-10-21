extends Node3D

## Level-editor cereal box: a ProtoCerealBox stood on its base, so it rests on
## whatever it's placed on like the other props do.

@export var title := ProtoCerealBox.Title.LOOPIES


func _ready() -> void:
	var box := ProtoCerealBox.new()
	box.name = "CerealBox"
	box.title = title
	add_child(box)
	box.position.y = -preload("res://scripts/level_editor/level_world.gd").bounds_of(box).position.y

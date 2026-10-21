extends Node3D


@export var title := ProtoCerealBox.Title.LOOPIES:
	set(value):
		title = value
		if is_node_ready():
			$CerealBox.title = title


func _ready() -> void:
	var box := ProtoCerealBox.new()
	box.name = "CerealBox"
	box.title = title
	add_child(box)
	box.position.y = -preload("res://scripts/level_editor/level_world.gd").bounds_of(box).position.y

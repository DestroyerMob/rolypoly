class_name IrohKitchenDistinctOven
extends StaticBody3D

signal burners_changed(enabled: bool)
signal doors_changed(opened: bool)

@export_category("Burners")
@export var start_burners_on := false
@export_range(0.5, 6.0, 0.1) var flame_speed := 2.4

@export_category("Doors")
@export var start_doors_open := false
@export_range(45.0, 105.0, 1.0) var door_open_angle_degrees := 82.0
@export_range(0.15, 2.0, 0.05) var door_animation_duration := 0.65

@onready var flames: Node3D = $Flames
@onready var model_root: Node3D = $Model/DistinctOven_Root
@onready var interaction_prompt: Label3D = $InteractionPrompt
@onready var interaction_area: Area3D = $InteractionArea

var burners_on := false
var doors_open := false
var _left_door_pivot: Node3D
var _right_door_pivot: Node3D
var _door_tween: Tween
var _flame_time := 0.0
var _players_in_range: Array[Node3D] = []


func _ready() -> void:
	_left_door_pivot = _create_door_pivot("Left", -3.76)
	_right_door_pivot = _create_door_pivot("Right", 3.76)
	interaction_area.body_entered.connect(_on_interaction_body_entered)
	interaction_area.body_exited.connect(_on_interaction_body_exited)
	interaction_prompt.visible = false
	set_burners_enabled(start_burners_on)
	set_doors_open(start_doors_open, true)


func _unhandled_input(event: InputEvent) -> void:
	if _players_in_range.is_empty():
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(&"interact_fire"):
		toggle_burners()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"interact_door"):
		toggle_doors()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not burners_on:
		return
	_flame_time += delta * flame_speed
	var index := 0
	for child in flames.get_children():
		if child is Node3D and child.name.begins_with("BurnerFlame"):
			var pulse := 0.92 + sin(_flame_time + index * 1.37) * 0.10
			child.scale = Vector3(1.0 / pulse, pulse, 1.0 / pulse)
			child.rotation.y = sin(_flame_time * 0.7 + index) * 0.12
			index += 1


func toggle_burners() -> void:
	set_burners_enabled(not burners_on)


func set_burners_enabled(enabled: bool) -> void:
	burners_on = enabled
	flames.visible = enabled
	set_process(enabled)
	if not enabled:
		_flame_time = 0.0
		for child in flames.get_children():
			if child is Node3D and child.name.begins_with("BurnerFlame"):
				child.scale = Vector3.ONE
	_update_interaction_prompt()
	burners_changed.emit(enabled)


func toggle_doors() -> void:
	set_doors_open(not doors_open)


func set_doors_open(opened: bool, immediate := false) -> void:
	doors_open = opened
	if _door_tween:
		_door_tween.kill()

	var left_target := deg_to_rad(-door_open_angle_degrees if opened else 0.0)
	var right_target := deg_to_rad(door_open_angle_degrees if opened else 0.0)
	if immediate:
		_left_door_pivot.rotation.y = left_target
		_right_door_pivot.rotation.y = right_target
	else:
		_door_tween = create_tween().set_parallel(true)
		_door_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_door_tween.tween_property(_left_door_pivot, "rotation:y", left_target, door_animation_duration)
		_door_tween.tween_property(_right_door_pivot, "rotation:y", right_target, door_animation_duration)
	_update_interaction_prompt()
	doors_changed.emit(opened)


func _on_interaction_body_entered(body: Node3D) -> void:
	if body is IrohKitchenPlayer and not _players_in_range.has(body):
		_players_in_range.append(body)
		interaction_prompt.visible = true
		_update_interaction_prompt()


func _on_interaction_body_exited(body: Node3D) -> void:
	_players_in_range.erase(body)
	interaction_prompt.visible = not _players_in_range.is_empty()


func _update_interaction_prompt() -> void:
	if not is_node_ready():
		return
	#interaction_prompt.text = "[F] FIRE: %s     [E] DOORS: %s" % [
		#"ON" if burners_on else "OFF",
		#"OPEN" if doors_open else "CLOSED",
	#]


func _create_door_pivot(side: String, hinge_x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = side + "DoorPivot"
	model_root.add_child(pivot)
	# Model coordinates are converted from Blender Z-up to Godot Y-up.
	pivot.position = Vector3(hinge_x, 2.03, 1.715)

	var prefix := "DistinctOven_" + side
	for child in model_root.get_children():
		if child != pivot and child is Node3D and child.name.begins_with(prefix):
			child.reparent(pivot, true)
	return pivot

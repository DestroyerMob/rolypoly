class_name GadgetMount
extends Node3D

@export var player_rig: PlayerRig
@export var camera: Camera3D
@export var side_distance := 4.0
@export var height := 0.8
@export var model_offset := Vector3(0, -0.55, 0)

var _equipped_scene: PackedScene
var _gadget: Node3D


func _ready() -> void:
	player_rig.player_swapped.connect(func(_player: Player): _update_attachment())


func equip(scene: PackedScene) -> void:
	if scene == null:
		return
	if scene == _equipped_scene and is_instance_valid(_gadget):
		if _gadget.has_method("refresh_equipment"):
			_gadget.refresh_equipment()
		return
	unequip()
	_gadget = scene.instantiate() as Node3D
	add_child(_gadget)
	_equipped_scene = scene
	_update_attachment()


func unequip(expected_gadget: Node3D = null) -> void:
	if expected_gadget != null and expected_gadget != _gadget:
		return
	if is_instance_valid(_gadget):
		if is_instance_valid(player_rig) and is_instance_valid(player_rig.current_player):
			if player_rig.current_player.gadget == _gadget:
				player_rig.current_player.gadget = null
		remove_child(_gadget)
		_gadget.queue_free()
	_gadget = null
	_equipped_scene = null


func _process(_delta: float) -> void:
	_update_attachment()


func _physics_process(_delta: float) -> void:
	_update_attachment()


func _update_attachment() -> void:
	if not is_instance_valid(_gadget):
		return
	visible = is_instance_valid(player_rig) and is_instance_valid(camera)
	if not visible:
		return
	visible = is_instance_valid(player_rig.current_player)
	if not visible:
		return
	player_rig.current_player.gadget = _gadget
	var aim := camera.global_basis.orthonormalized()
	var right := Vector3(aim.x.x, 0, aim.x.z).normalized()
	global_transform = Transform3D(aim, player_rig.current_player.global_position
		+ right * side_distance + Vector3.UP * height)
	_gadget.position = model_offset
	if _gadget.has_method("update_attachment"):
		_gadget.update_attachment(player_rig.current_player, self)

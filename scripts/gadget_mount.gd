class_name GadgetMount
extends Node3D

@export var player_rig: PlayerRig
## Fixed wearer (e.g. an NPC). When unset, follows player_rig.current_player.
@export var player: Player
@export var camera: Camera3D
@export var side_distance := 4.0
@export var height := 0.8
@export var model_offset := Vector3(0, -0.55, 0)

var _equipped_scene: PackedScene
var _equipped_overrides: Dictionary = {}
var _gadget: Node3D


func _ready() -> void:
	if is_instance_valid(player_rig):
		player_rig.player_swapped.connect(func(_player: Player): _update_attachment())


func get_wearer() -> Player:
	if is_instance_valid(player):
		return player
	if is_instance_valid(player_rig) and is_instance_valid(player_rig.current_player):
		return player_rig.current_player
	return null


func equip(scene: PackedScene, overrides: Dictionary = {}) -> void:
	if scene == null:
		return
	if scene == _equipped_scene and overrides == _equipped_overrides and is_instance_valid(_gadget):
		if _gadget.has_method("refresh_equipment"):
			_gadget.refresh_equipment()
		return
	unequip()
	_gadget = scene.instantiate() as Node3D
	for property_name in overrides:
		_gadget.set(property_name, overrides[property_name])
	add_child(_gadget)
	_equipped_scene = scene
	_equipped_overrides = overrides.duplicate()
	_update_attachment()


func unequip(expected_gadget: Node3D = null) -> void:
	if expected_gadget != null and expected_gadget != _gadget:
		return
	if is_instance_valid(_gadget):
		var wearer := get_wearer()
		if wearer != null and wearer.gadget == _gadget:
			wearer.gadget = null
		remove_child(_gadget)
		_gadget.queue_free()
	_gadget = null
	_equipped_scene = null
	_equipped_overrides = {}


func _process(_delta: float) -> void:
	_update_attachment()


func _physics_process(_delta: float) -> void:
	_update_attachment()


func _update_attachment() -> void:
	if not is_instance_valid(_gadget):
		return
	var wearer := get_wearer()
	visible = wearer != null and (is_instance_valid(camera) or is_instance_valid(player))
	if not visible:
		return
	wearer.gadget = _gadget
	var aim := camera.global_basis.orthonormalized() if is_instance_valid(camera) else Basis.IDENTITY
	var right := Vector3(aim.x.x, 0, aim.x.z).normalized()
	global_transform = Transform3D(aim, wearer.global_position
		+ right * side_distance + Vector3.UP * height)
	_gadget.position = model_offset
	if _gadget.has_method("update_attachment"):
		_gadget.update_attachment(wearer, self)

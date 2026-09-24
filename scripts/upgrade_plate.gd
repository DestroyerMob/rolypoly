extends Node3D

@export var gadget_scene: PackedScene
@export var gadget_mount: GadgetMount
@export var preview_scale := 0.3


func _ready() -> void:
	if gadget_scene != null:
		var preview := gadget_scene.instantiate() as Node3D
		$UpgradeNode.add_child(preview)
		preview.scale = Vector3.ONE * preview_scale
	$PickupArea.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not is_instance_valid(gadget_mount) or not is_instance_valid(gadget_mount.player_rig):
		return
	if body == gadget_mount.player_rig.current_player:
		gadget_mount.equip(gadget_scene)

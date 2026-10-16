extends Node3D

@export var gadget_scene: PackedScene
@export var preview_scene: PackedScene
@export var gadget_mount: GadgetMount
@export var gadget_overrides: Dictionary = {}
@export var preview_scale := 0.3
@export var preview_spin_degrees := 18.0


func _ready() -> void:
	var display_scene := preview_scene if preview_scene != null else gadget_scene
	if display_scene != null:
		var preview := display_scene.instantiate() as Node3D
		$UpgradeNode.add_child(preview)
		preview.scale = Vector3.ONE * preview_scale
	$PickupArea.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	$UpgradeNode.rotate_y(deg_to_rad(preview_spin_degrees) * delta)


func _on_body_entered(body: Node3D) -> void:
	if body is NPC:
		body.gadget_mount.equip.call_deferred(gadget_scene, gadget_overrides)
		return
	if not is_instance_valid(gadget_mount) or not is_instance_valid(gadget_mount.player_rig):
		return
	if body == gadget_mount.player_rig.current_player:
		gadget_mount.equip.call_deferred(gadget_scene, gadget_overrides)

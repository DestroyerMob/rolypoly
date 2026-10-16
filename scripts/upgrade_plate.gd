extends Node3D

@export var gadget_scene: PackedScene
@export var preview_scene: PackedScene
@export var gadget_mount: GadgetMount
@export var gadget_overrides: Dictionary = {}
## Players that melt (the ice cream) have their melting held while they are on the
## pickup, and for this many seconds after they leave, instead of being given the
## gadget. 0 gives everyone the gadget.
@export_range(0.0, 120.0, 0.05) var melt_freeze_seconds := 0.0
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


func _physics_process(_delta: float) -> void:
	if melt_freeze_seconds <= 0.0 or not is_instance_valid(gadget_mount) or not is_instance_valid(gadget_mount.player_rig):
		return
	var player := gadget_mount.player_rig.current_player
	if is_instance_valid(player) and $PickupArea.overlaps_body(player):
		_freeze_melt(player)


func _on_body_entered(body: Node3D) -> void:
	if not is_instance_valid(gadget_mount) or not is_instance_valid(gadget_mount.player_rig):
		return
	if body == gadget_mount.player_rig.current_player:
		if melt_freeze_seconds > 0.0 and _freeze_melt(body):
			return
		gadget_mount.equip.call_deferred(gadget_scene, gadget_overrides)


func _freeze_melt(body: Node3D) -> bool:
	for child in body.get_children():
		if child.has_method(&"freeze_melt"):
			child.freeze_melt(melt_freeze_seconds)
			return true
	return false

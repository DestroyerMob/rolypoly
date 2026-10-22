class_name PlayerRig
extends Node #Do not change this to Node3D, player_rig is an abstract concept and should not be moveable in the scene.

const CHARACTERS := {
	"swap_character_1": preload("res://packed_scenes/player_onion.tscn"),#Onion
	"swap_character_2": preload("res://packed_scenes/player_egg.tscn"),#Egg
	"swap_character_3": preload("res://packed_scenes/player_tomato.tscn"),#Tomato
	"swap_character_4": preload("res://packed_scenes/player_ice_cream.tscn"),
	"swap_character_5": preload("res://packed_scenes/player_lollypop.tscn"),
}

@export var allow_character_swap := true

## Fire after pressing swap so the camera and other things can retarget 
signal player_swapped(new_player: Player)

var current_player: Player 

func _enter_tree() -> void:
	print("PlayerRig _enter_tree, children: ", get_children())
	for child in get_children():
		if child is Player:
			current_player = child
			print("  found player: ", child.name)
			return
	print("  NO PLAYER FOUND")
	
func _unhandled_input(event):
	if not allow_character_swap:
		return
	for input_action in CHARACTERS:
			if event.is_action_pressed(input_action):
				swap_to(CHARACTERS[input_action])
				return
					
func swap_to(scene: PackedScene) -> void:
	if not is_instance_valid(current_player):
		return
	var player_to_load: Player = scene.instantiate()
	#Job 1 :Store Old Physics 
	var old_player_global_transform : Transform3D = current_player.global_transform
	var old_player_linear_velocity : Vector3 = current_player.linear_velocity
	var old_player_angular_velocity : Vector3 = current_player.angular_velocity
	var target := old_player_global_transform
	if current_player.on_ground:
		var old_clearance := current_player.get_collision_clearance(target.basis)
		var new_clearance := player_to_load.get_collision_clearance(target.basis)
		target.origin.y += maxf(0.0, new_clearance - old_clearance) + 0.05
	var collision := player_to_load.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = target * collision.transform
	query.collision_mask = player_to_load.collision_mask
	query.exclude = [current_player.get_rid()]
	if not current_player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		player_to_load.free()
		return
	player_to_load.transform = current_player.transform * old_player_global_transform.affine_inverse() * target
	var old_spawn_position := current_player.spawn_position
	var old_spawn_clearance := current_player.spawn_clearance
	
	#Job 2 : Destroy current player right now not at the end of current frame
	var old_player: Player = current_player
	current_player = null
	remove_child(old_player)
	
	#Job 2.5: Queue release of old_player from Memory at end of Frame
	old_player.queue_free()
	
	#Job 3: Instantiate the new player
	add_child(player_to_load)
	
	#Job 4: Put the old_state into the state of the new player 
	player_to_load.angular_velocity = old_player_angular_velocity
	player_to_load.linear_velocity = old_player_linear_velocity
	player_to_load.spawn_position = old_spawn_position + Vector3.UP * (player_to_load.spawn_clearance - old_spawn_clearance)
	
	#Job 4.5: Assign player_to_load to current_player
	current_player = player_to_load
	
	#Job5: Emit Signal for camera
	player_swapped.emit(current_player)
	
	

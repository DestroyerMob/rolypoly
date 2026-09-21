extends Node


const CHARACTERS := {
	"swap_character_1": preload("res://packed_scenes/player_onion.tscn"),#Onion
	"swap_character_2": preload("res://packed_scenes/player_egg.tscn"),#Egg
	"swap_character_3": preload("res://packed_scenes/player_tomato.tscn"),#Tomato
	"swap_character_4": preload("res://packed_scenes/player_boiled_egg.tscn"),#Boiled Egg
	#"swap_character_4": "res://packed_scenes/player_boiled_egg.tscn",#Boiled Egg
}

@onready var player := Player


var old_player_global_transform : Transform3D = self.get_child(0).global_transform
var old_player_linear_velocity : Vector3 = <>
var old_player_angular_velocity : Vector3 = <>

func _ready()

func _unhandled_input(event):
	for input_action in CHARACTERS:
			if event.is_action_pressed(input_action):
				var player_to_load: Player = CHARACTERS[input_action].instantiate()
				add_child(player_to_load)
				return

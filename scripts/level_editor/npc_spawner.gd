extends Marker3D

## Level-editor marker that puts one NPC into the level when it's played.
## The properties here are copied onto the NPC; health and handling come from
## the character, the same as for the player.

## Order matches the Character choice in item_properties.gd.
const CHARACTERS := ["onion", "egg", "tomato", "ice_cream", "lollipop"]
## Order matches the Starts with choice in item_properties.gd.
const WEAPONS := ["", "res://scenes/props/walther_p88.tscn", "res://scenes/props/m4a1.tscn", "res://scenes/props/shotgun.tscn"]

@export var character := 0
@export var mode := NPC.Mode.WANDER
@export var max_speed := 6.0
@export var wander_radius := 6.0
@export var fight_range := 30.0
@export var aim_error := 1.0
@export var reaction_time := 0.0
## Fighting NPCs don't look for pickups, so give them a gun here.
@export var weapon := 0


func character_key() -> String:
	return CHARACTERS[clampi(character, 0, CHARACTERS.size() - 1)]


## `scene` is the character's player scene, looked up from character_key().
func spawn(scene: PackedScene) -> NPC:
	var body: Player = scene.instantiate()
	var stats := {}
	for property in body.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			stats[property.name] = body.get(property.name)
	body.set_script(NPC)
	var npc := body as NPC
	for property_name in stats:
		npc.set(property_name, stats[property_name])
	npc.name = character_key().to_pascal_case()
	npc.mode = mode
	npc.max_speed = max_speed
	npc.wander_radius = wander_radius
	npc.fight_range = fight_range
	npc.aim_error = aim_error
	npc.reaction_time = reaction_time
	if mode == NPC.Mode.GOAL:
		npc.goal = get_tree().get_first_node_in_group(&"finish") as Node3D
	npc.position = global_position + Vector3.UP * 2.2
	add_sibling(npc, true)
	npc.respawn(global_position + Vector3.UP * npc.spawn_clearance)
	if weapon > 0 and weapon < WEAPONS.size():
		npc.gadget_mount.equip(load(WEAPONS[weapon]))
	return npc

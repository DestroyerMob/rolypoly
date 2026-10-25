extends Marker3D


const CHARACTERS := ["onion", "egg", "tomato", "ice_cream", "lollipop"]
const WEAPONS := ["", "res://scenes/props/walther_p88.tscn", "res://scenes/props/m4a1.tscn", "res://scenes/props/shotgun.tscn"]

@export var character := 0
@export var mode := NPC.Mode.WANDER
@export var max_speed := 6.0
@export var wander_radius := 6.0
@export var fight_range := 30.0
@export var aim_error := 1.0
@export var reaction_time := 0.0
@export var weapon := 0


func character_key() -> String:
	return CHARACTERS[clampi(character, 0, CHARACTERS.size() - 1)]


## `size` is the level's character size; the NPC is scaled up like the player.
func spawn(scene: PackedScene, size := 1.0) -> NPC:
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
	load("res://scripts/level_editor/catalog.gd").size_player(npc, size)
	npc.position = global_position + Vector3.UP * 2.2 * size
	add_sibling(npc, true)
	npc.respawn(global_position + Vector3.UP * npc.spawn_clearance)
	if weapon > 0 and weapon < WEAPONS.size():
		npc.gadget_mount.equip(load(WEAPONS[weapon]))
	return npc

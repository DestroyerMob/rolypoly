extends RefCounted

const ItemProperties = preload("res://scripts/level_editor/item_properties.gd")
const ItemColours = preload("res://scripts/level_editor/item_colours.gd")

## How much bigger than the player scenes characters are in a level that doesn't set its
## own character size. The kitchen is built at 100 units to a metre, so a character
## about 1 unit in radius looks like a marble. 3 makes it about the size of a tennis ball.
const PLAYER_SIZE := 3.0

## The characters a level can be played as. A level plays as one of these for its
## whole run; swapping characters is turned off in custom levels.
const DEFAULT_PLAYER := "onion"
const PLAYERS := {
	"onion": {"label": "Onion", "scene": preload("res://packed_scenes/player_onion.tscn")},
	"egg": {"label": "Egg", "scene": preload("res://packed_scenes/player_egg.tscn")},
	"tomato": {"label": "Tomato", "scene": preload("res://packed_scenes/player_tomato.tscn")},
	"ice_cream": {"label": "Ice cream", "scene": preload("res://packed_scenes/player_ice_cream.tscn")},
	"lollipop": {"label": "Lollipop", "scene": preload("res://packed_scenes/player_lollypop.tscn")},
}

const ITEMS := {
	"counter": {"label": "Counter tile (8 × 8)", "category": "Surfaces", "scene": preload("res://scenes/level_editor/counter_tile.tscn")},
	"box": {"label": "Platform", "category": "Surfaces", "scene": preload("res://scenes/prototyping/proto_box.tscn")},
	"ramp": {"label": "Ramp", "category": "Surfaces", "scene": preload("res://scenes/prototyping/proto_ramp.tscn")},
	"half_pipe": {"label": "Half pipe", "category": "Surfaces", "scene": preload("res://scenes/prototyping/proto_half_pipe.tscn")},
	"cylinder": {"label": "Round platform", "category": "Surfaces", "scene": preload("res://scenes/prototyping/proto_cylinder.tscn")},
	"kitchen": {"label": "Kitchen interior", "category": "Kitchen", "legacy": true, "scene": preload("res://scenes/level_editor/kitchen_interior.tscn")},
	"oven": {"label": "Oven", "category": "Kitchen", "scene": preload("res://scenes/props/distinct_oven.tscn")},
	"grill": {"label": "Hot iron grill", "category": "Kitchen", "scene": preload("res://scenes/obstacles/iron_grill.tscn")},
	"lighter": {"label": "Lighter", "category": "Kitchen", "scene": preload("res://scenes/props/lighter.tscn")},
	"spoon": {"label": "Wooden spoon", "category": "Kitchen", "scene": preload("res://scenes/props/wooden_spoon.tscn")},
	"cardboard": {"label": "Cardboard box", "category": "Kitchen", "scene": preload("res://scenes/props/cardboard_box.tscn")},
	"bottle": {"label": "Wine bottle", "category": "Kitchen", "scene": preload("res://scenes/props/winebottle.tscn")},
	"cookbook": {"label": "Cookbook", "category": "Kitchen", "scene": preload("res://scenes/props/cookbook.tscn")},
	"cereal_box": {"label": "Standing cereal box", "category": "Kitchen", "scene": preload("res://scenes/props/cereal_box.tscn")},
	"roller": {"label": "Moving rolling pin", "category": "Obstacles", "scene": preload("res://scenes/obstacles/rolling_pin.tscn")},
	"spinner": {"label": "Spinning rolling pin", "category": "Obstacles", "scene": preload("res://scenes/obstacles/rolling_pin_spinner.tscn")},
	"log": {"label": "Rolling pin log", "category": "Obstacles", "scene": preload("res://scenes/obstacles/rolling_pin_log.tscn")},
	"masher": {"label": "Masher", "category": "Obstacles", "scene": preload("res://scenes/obstacles/masher.tscn")},
	"knife": {"label": "Chopping knife", "category": "Obstacles", "scene": preload("res://scenes/obstacles/knife.tscn")},
	"blender": {"label": "Blender", "category": "Obstacles", "scene": preload("res://scenes/obstacles/blender.tscn")},
	"ladle": {"label": "Swinging ladle", "category": "Obstacles", "scene": preload("res://scenes/obstacles/ladle.tscn")},
	"ladle_vertical": {"label": "Vertical ladle", "category": "Obstacles", "scene": preload("res://scenes/obstacles/ladle_vertical.tscn")},
	"funnel": {"label": "Funnel", "category": "Obstacles", "scene": preload("res://scenes/obstacles/funnel.tscn")},
	"funnel_long": {"label": "Long funnel", "category": "Obstacles", "scene": preload("res://scenes/obstacles/funnel_long.tscn")},
	"corkscrew": {"label": "Corkscrew", "category": "Obstacles", "scene": preload("res://scenes/obstacles/corkscrew.tscn")},
	"grater": {"label": "Cheese grater", "category": "Obstacles", "scene": preload("res://scenes/obstacles/cheese_grater.tscn")},
	"scale": {"label": "Electronic scale", "category": "Obstacles", "scene": preload("res://scenes/obstacles/scale.tscn")},
	"dicer": {"label": "Moving dicer", "category": "Obstacles", "scene": preload("res://scenes/props/corexy.tscn")},
	"umbrella": {"label": "Umbrella pickup", "category": "Powerups", "scene": preload("res://scenes/props/umbrella_upgrade.tscn")},
	"cream": {"label": "Whipped cream pickup", "category": "Powerups", "scene": preload("res://scenes/props/whipped_cream_upgrade.tscn")},
	"ice": {"label": "Ice cube pickup", "category": "Powerups", "scene": preload("res://scenes/props/ice_cube_upgrade.tscn")},
	"sprinkles": {"label": "Sprinkles pickup", "category": "Powerups", "scene": preload("res://scenes/props/sprinkles_pickup.tscn")},
	"nuts": {"label": "Nuts pickup", "category": "Powerups", "scene": preload("res://scenes/props/nuts_pickup.tscn")},
	"gravity": {"label": "Gravity gun pickup", "category": "Powerups", "scene": preload("res://scenes/props/upgrade_plate.tscn")},
	"m4a1": {"label": "M4A1 pickup", "category": "Powerups", "scene": preload("res://scenes/props/m4a1_upgrade.tscn")},
	"shotgun": {"label": "Shotgun pickup", "category": "Powerups", "scene": preload("res://scenes/props/shotgun_upgrade.tscn")},
	"pistol": {"label": "Walther P88 pickup", "category": "Powerups", "scene": preload("res://scenes/props/walther_p88_upgrade.tscn")},
	"produce": {"label": "Loose egg (gravity gun)", "category": "Kitchen", "scene": preload("res://packed_scenes/not_a_player_egg.tscn")},
	"spawn": {"label": "Player start", "category": "Level", "scene": preload("res://scenes/level_editor/start.tscn")},
	"goal": {"label": "Finish area", "category": "Level", "scene": preload("res://scenes/level_editor/finish.tscn")},
	"watcher": {"label": "Event watcher", "category": "Logic", "scene": preload("res://scenes/level_editor/event_watcher.tscn")},
	"npc": {"label": "NPC spawner", "category": "Level", "scene": preload("res://scenes/level_editor/npc_spawner.tscn")},
	"pot": {"label": "Pot", "category": "Kitchen", "scene": preload("res://scenes/obstacles/pot.tscn")},
	"bowl": {"label": "Red bowl", "category": "Kitchen", "scene": preload("res://scenes/props/Bowls/RedBowl.tscn")},
	"onion": {"label": "Loose onion", "category": "Kitchen", "scene": preload("res://packed_scenes/not_a_player_onion.tscn")},
	"book": {"label": "Book", "category": "Kitchen", "scene": preload("res://scenes/props/book.tscn")},
	"cereal": {"label": "Cereal", "category": "Kitchen", "scene": preload("res://scenes/props/cereal.tscn")},
	"funnel_exit": {"label": "Funnel exit", "category": "Level", "scene": preload("res://scenes/props/funnel_exit.tscn")},
}

## Scales a character up by `factor` while keeping it feeling the same to play: through
## its size_factor, forces, jump and gravity grow with it, so it rolls, jumps and falls like
## the original, only bigger. Call this before the player enters the tree.
static func size_player(player: Player, factor := PLAYER_SIZE) -> void:
	var collider := player.get_node("CollisionShape3D") as CollisionShape3D
	collider.scale *= factor
	player.size_factor *= factor
	player.spawn_clearance *= factor
	var trail := player.get_node_or_null("Trail")
	if trail != null and "stamp_size" in trail:
		for property in ["stamp_size", "spacing", "ground_reach", "min_speed"]:
			trail.set(property, trail.get(property) * factor)
const DEFAULT_MODE := "race"
const MODES := {"race": "Race to the finish", "ffa": "Free for all"}

static func player_of(document: Dictionary) -> String:
	return document.get("player", DEFAULT_PLAYER)

static func mode_of(document: Dictionary) -> String:
	return document.get("mode", DEFAULT_MODE)

## The range a level's character size can be set to. Level 1 plays at 5.
const CHARACTER_SIZES := Vector2(0.5, 10.0)

## How many times the player scenes' size the player and NPCs are in this level.
static func character_size_of(document: Dictionary) -> float:
	return float(document.get("character_size", PLAYER_SIZE))

static func record(id: String, position := Vector3.ZERO) -> Dictionary:
	return {"id": id, "position": [position.x, position.y, position.z],
		"rotation": [0.0, 0.0, 0.0], "scale": [1.0, 1.0, 1.0]}

static func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

static func apply_transform(node: Node3D, data: Dictionary) -> void:
	node.position = vector(data.position)
	node.rotation_degrees = vector(data.rotation)
	node.scale = vector(data.scale)

static func instantiate(data: Dictionary, mount: GadgetMount = null) -> Node3D:
	var node: Node3D = ITEMS[data.id].scene.instantiate()
	apply_transform(node, data)
	if ITEMS[data.id].category == "Powerups":
		node.set("gadget_mount", mount)
	if data.id == "gravity":
		node.set("gadget_scene", preload("res://scenes/props/gravity_gun.tscn"))
		node.set("preview_scale", 1.0)
	if data.id == "pot":
		node.set("return_scene", "")
		node.get_node("GoalArea").monitoring = false
	if data.has("properties"):
		ItemProperties.apply(node, data.id, data.properties)
	if data.has("colour"):
		ItemColours.apply(node, data.id, ItemColours.parse(data.colour))
	return node

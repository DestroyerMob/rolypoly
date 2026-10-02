extends RefCounted

# Stable IDs are stored in saves; only this catalog can resolve them to scenes.
const ITEMS := {
	"counter": {"label": "Counter tile (8 × 8)", "category": "Surfaces", "scene": preload("res://scenes/level_editor/counter_tile.tscn")},
	"box": {"label": "Platform", "category": "Surfaces", "scene": preload("res://scenes/prototyping/proto_box.tscn")},
	"ramp": {"label": "Ramp", "category": "Surfaces", "scene": preload("res://scenes/prototyping/proto_ramp.tscn")},
	"half_pipe": {"label": "Half pipe", "category": "Surfaces", "scene": preload("res://scenes/prototyping/proto_half_pipe.tscn")},
	"cylinder": {"label": "Round platform", "category": "Surfaces", "scene": preload("res://scenes/prototyping/proto_cylinder.tscn")},
	"kitchen": {"label": "Kitchen interior", "category": "Kitchen", "scene": preload("res://scenes/prototyping/kitchen_set.tscn")},
	"oven": {"label": "Oven", "category": "Kitchen", "scene": preload("res://scenes/props/distinct_oven.tscn")},
	"grill": {"label": "Hot iron grill", "category": "Kitchen", "scene": preload("res://scenes/obstacles/iron_grill.tscn")},
	"lighter": {"label": "Lighter", "category": "Kitchen", "scene": preload("res://scenes/props/lighter.tscn")},
	"spoon": {"label": "Wooden spoon", "category": "Kitchen", "scene": preload("res://scenes/props/wooden_spoon.tscn")},
	"cardboard": {"label": "Cardboard box", "category": "Kitchen", "scene": preload("res://scenes/props/cardboard_box.tscn")},
	"bottle": {"label": "Wine bottle", "category": "Kitchen", "scene": preload("res://scenes/props/winebottle.tscn")},
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
	"gravity": {"label": "Gravity gun pickup", "category": "Powerups", "scene": preload("res://scenes/props/upgrade_plate.tscn")},
	"produce": {"label": "Loose egg (gravity gun)", "category": "Kitchen", "scene": preload("res://packed_scenes/not_a_player_egg.tscn")},
	"spawn": {"label": "Player start", "category": "Level", "scene": preload("res://scenes/level_editor/start.tscn")},
	"goal": {"label": "Finish flag", "category": "Level", "scene": preload("res://scenes/level_editor/finish.tscn")},
	"pot": {"label": "Finish pot", "category": "Level", "scene": preload("res://scenes/obstacles/pot.tscn")},
}

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
	return node

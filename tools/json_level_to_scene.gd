extends SceneTree

## Turns a level saved by the level creator into a normal .tscn you can open and edit.
##
##   godot --headless --path . --script tools/json_level_to_scene.gd -- <level.json> <output.tscn>
##
## <level.json> is a file name inside user://levels, or any full path to a level file.
## <output.tscn> is a res:// path, e.g. res://scenes/levels/tutorial_1.tscn.
## The scene holds the kitchen, every placed object (still instances of their own scenes),
## a death zone, and a player rig with camera, set up like the level creator's play mode.

const Catalog = preload("res://scripts/level_editor/catalog.gd")
const LevelStore = preload("res://scripts/level_editor/level_store.gd")
const KITCHEN := preload("res://scenes/level_editor/empty_kitchen.tscn")
const DEATH_ZONE := preload("res://scenes/death_zone.tscn")
const RIG_SCRIPT := "res://scenes/player_rig.gd"
const PIVOT_SCRIPT := "res://scenes/prototyping/camera_pivot.gd"
const MOUNT_SCRIPT := "res://scripts/gadget_mount.gd"
const LEVEL_COMPLETE := preload("res://scenes/level_complete.tscn")
const FINISH_GOAL_SCRIPT := "res://scripts/star_goals/star_goal_finish.gd"
const TOPPINGS_GOAL_SCRIPT := "res://scripts/star_goals/star_goal_toppings.gd"
## The Player node's scale, as in the hand-built levels. Force, jump and gravity follow it.
const PLAYER_SCALE := 5.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: --script tools/json_level_to_scene.gd -- <level.json> <output.tscn>")
		quit(1)
		return
	quit(_convert(args[0], args[1]))


func _convert(source: String, output: String) -> int:
	var document := _read(source)
	if document.is_empty():
		return 1
	var problem := LevelStore.playable_error(document)
	if not problem.is_empty():
		push_error(problem)
		return 1

	var root := Node3D.new()
	root.name = String(document.name).to_pascal_case().replace(" ", "")
	if root.name.is_empty():
		root.name = "Level"

	root.add_child(KITCHEN.instantiate())
	var rig := _add_player_rig(root, document)
	var mount := rig.get_node("GadgetMount") as GadgetMount

	var complete := LEVEL_COMPLETE.instantiate()
	complete.set("level_title", document.name)
	complete.set("start_hidden", true)
	root.add_child(complete)
	root.move_child(complete, 0)

	var goals := Node.new()
	goals.name = "StarGoals"
	root.add_child(goals)
	root.move_child(goals, 1)
	var finish_goal := Node.new()
	if Catalog.player_of(document) == "ice_cream":
		# The ice cream is scored on the toppings it finishes with: 1, 3 and 5 for each star.
		finish_goal.name = "ToppingsGoal"
		finish_goal.set_script(load(TOPPINGS_GOAL_SCRIPT))
		finish_goal.set("description", "Collect toppings: 1 for one star, 3 for two, 5 for three")
	else:
		finish_goal.name = "FinishGoal"
		finish_goal.set_script(load(FINISH_GOAL_SCRIPT))
		finish_goal.set("description", "Finish the level")
		finish_goal.set("stars_worth", 3)
	goals.add_child(finish_goal)

	var objects := Node3D.new()
	objects.name = "Objects"
	root.add_child(objects)
	var lowest := 0.0
	for index in document.objects.size():
		var entry: Dictionary = document.objects[index]
		var node := Catalog.instantiate(entry, mount)
		node.name = "%s_%d" % [String(entry.id).to_pascal_case(), index + 1]
		objects.add_child(node)
		lowest = minf(lowest, node.position.y)
		if entry.id == "goal":
			node.connect("level_completed", Callable(complete, "show_on_finish"), CONNECT_PERSIST)

	var death := DEATH_ZONE.instantiate() as Node3D
	# The death zone scene connects its own signal; saving that again would connect it twice.
	var area := death as Area3D
	for connection in area.body_entered.get_connections():
		area.body_entered.disconnect(connection.callable)
	death.position.y = lowest - 30.0
	root.add_child(death)

	_claim(root, root)
	var packed := PackedScene.new()
	var result := packed.pack(root)
	if result != OK:
		push_error("Could not pack the scene: %s" % error_string(result))
		return 1
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	result = ResourceSaver.save(packed, output)
	if result != OK:
		push_error("Could not save %s: %s" % [output, error_string(result)])
		return 1
	print("Saved %d objects to %s" % [document.objects.size(), output])
	root.free()
	return 0


func _read(source: String) -> Dictionary:
	var filename := source.get_file()
	var path := source if source.is_absolute_path() else LevelStore.DIRECTORY.path_join(filename)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % path)
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		push_error("Not valid JSON: %s" % parser.get_error_message())
		return {}
	var problem := LevelStore.validate(parser.data)
	if not problem.is_empty():
		push_error(problem)
		return {}
	return LevelStore.normalize(parser.data)


## A player on the start marker with an orbit camera and gadget mount, as in play mode.
func _add_player_rig(root: Node3D, document: Dictionary) -> Node:
	var start := Vector3.ZERO
	for entry in document.objects:
		if entry.id == "spawn":
			start = Catalog.vector(entry.position)

	var rig: Node = load(RIG_SCRIPT).new()
	rig.name = "PlayerRig"
	rig.set("allow_character_swap", false)
	var player: Player = Catalog.PLAYERS[Catalog.player_of(document)].scene.instantiate()
	var size := Catalog.character_size_of(document)
	Catalog.size_player(player, size)
	player.position = start + Vector3.UP * 2.2 * size
	rig.add_child(player)

	var pivot: Node3D = load(PIVOT_SCRIPT).new()
	pivot.name = "CameraPivot"
	pivot.position = player.position
	pivot.set("player_rig", rig)
	pivot.set("follow_offset", Vector3(0, 1.5, 0) * size)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 20.0 + 5.0 * size
	arm.margin = 0.5 * size
	pivot.add_child(arm)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.far = 3000
	camera.current = true
	arm.add_child(camera)
	rig.add_child(pivot)

	var mount: Node3D = load(MOUNT_SCRIPT).new()
	mount.name = "GadgetMount"
	mount.set("player_rig", rig)
	mount.set("camera", camera)
	rig.add_child(mount)

	root.add_child(rig)
	# Keep the scaled collider and stats as edits to the player instance when saving.
	root.set_editable_instance(player, true)
	return rig


## Give every node the scene should save an owner. Instanced scenes keep their contents
## as part of the instance, so only plain nodes are searched further.
func _claim(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			_claim(child, root)

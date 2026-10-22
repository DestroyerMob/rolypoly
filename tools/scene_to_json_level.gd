extends SceneTree

## Turns the objects in a level scene back into a level creator save, so the level can be
## opened and edited in the level editor.
##
##   godot --headless --path . --script tools/scene_to_json_level.gd -- <scene.tscn> [file.json] [Level name]
##
## <scene.tscn> is a res:// path. [file.json] is the save to write in user://levels; leave it out
## to make a new save, or give an existing name to replace that save. It reads the children of
## the scene's Objects node (or the scene's top-level nodes if there is no Objects node). Only the
## level creator's own items are carried over: other nodes there, such as a prop that is not in the
## creator's catalog, are listed as skipped. Star goals, the level complete card and the player's
## size live outside Objects and are left out. Event watcher links are not carried over.

const Catalog = preload("res://scripts/level_editor/catalog.gd")
const LevelStore = preload("res://scripts/level_editor/level_store.gd")
const ItemProperties = preload("res://scripts/level_editor/item_properties.gd")
const ItemColours = preload("res://scripts/level_editor/item_colours.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or args.size() > 3:
		push_error("Usage: --script tools/scene_to_json_level.gd -- <scene.tscn> [file.json] [Level name]")
		quit(1)
		return
	quit(_convert(args[0], args[1] if args.size() > 1 else "", args[2] if args.size() > 2 else ""))


func _convert(scene_path: String, filename: String, level_name: String) -> int:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load %s" % scene_path)
		return 1
	var root := packed.instantiate()

	var ids := {}
	for id: String in Catalog.ITEMS:
		if not Catalog.ITEMS[id].get("legacy", false):
			ids[Catalog.ITEMS[id].scene.resource_path] = id

	var holder: Node = root.get_node_or_null("Objects")
	var candidates: Array[Node] = []
	if holder != null:
		candidates.assign(holder.get_children())
	else:
		candidates.assign(root.get_children().filter(func(node: Node): return node.scene_file_path != Catalog.ITEMS.kitchen.scene.resource_path))

	var objects: Array = []
	var skipped: Array[String] = []
	for node in candidates:
		var id: String = ids.get(node.scene_file_path, "")
		if id.is_empty() or not node is Node3D:
			skipped.append("%s (%s)" % [node.name, node.scene_file_path.get_file() if not node.scene_file_path.is_empty() else node.get_class()])
			continue
		objects.append(_record(node as Node3D, id))

	var document := {
		"version": LevelStore.VERSION,
		"name": level_name if not level_name.is_empty() else String(root.name).capitalize(),
		"player": _player_of(root),
		"objects": objects,
	}
	var problem := LevelStore.validate(document)
	if not problem.is_empty():
		push_error("The level is not valid: %s" % problem)
		return 1
	var result := LevelStore.save_level(document, filename)
	if result.has("error"):
		push_error(result.error)
		return 1
	print("Saved %d objects as %s (player: %s)" % [objects.size(), result.filename, document.player])
	if not skipped.is_empty():
		print("Skipped %d nodes the level creator does not have: %s" % [skipped.size(), ", ".join(skipped)])
	var playable := LevelStore.playable_error(document)
	if not playable.is_empty():
		print("Note: %s" % playable)
	root.free()
	return 0


func _record(node: Node3D, id: String) -> Dictionary:
	var entry := Catalog.record(id, node.position)
	entry.rotation = _rounded(node.rotation_degrees)
	entry.scale = _rounded(node.scale)
	entry.position = _rounded(node.position)

	var fresh: Node = Catalog.ITEMS[id].scene.instantiate()
	var defaults := ItemProperties.read_defaults(id, fresh)
	var overrides: Dictionary = node.get("gadget_overrides") if node.get("gadget_overrides") is Dictionary else {}
	var properties := {}
	for spec in ItemProperties.specs(id):
		var value: Variant = overrides.get(spec.name, defaults.get(spec.name)) if spec.on == "gadget" else node.get(spec.name)
		if value == null or typeof(value) == TYPE_NIL:
			continue
		if not _same(value, defaults.get(spec.name)):
			properties[spec.name] = value
	if not properties.is_empty():
		entry.properties = properties

	if ItemColours.supports(id):
		var own: Variant = ItemColours.own_colour(node, id)
		var original: Variant = ItemColours.own_colour(fresh, id)
		if own is Color and (not original is Color or ItemColours.to_text(own) != ItemColours.to_text(original)):
			entry.colour = ItemColours.to_text(own)
	fresh.free()
	return entry


func _player_of(root: Node) -> String:
	var player := root.get_node_or_null("PlayerRig/Player")
	if player != null:
		for id: String in Catalog.PLAYERS:
			if Catalog.PLAYERS[id].scene.resource_path == player.scene_file_path:
				return id
	return Catalog.DEFAULT_PLAYER


static func _rounded(vector: Vector3) -> Array:
	return [snappedf(vector.x, 0.0001), snappedf(vector.y, 0.0001), snappedf(vector.z, 0.0001)]


static func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b

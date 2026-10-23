extends RefCounted
const Catalog = preload("res://scripts/level_editor/catalog.gd")
const ItemProperties = preload("res://scripts/level_editor/item_properties.gd")
const ItemColours = preload("res://scripts/level_editor/item_colours.gd")
const ItemTriggers = preload("res://scripts/level_editor/item_triggers.gd")
## Saved levels on this computer only. Exported builds save here, since the
## project is read-only there.
const DIRECTORY := "user://levels"
## Saved levels kept in the repo. Run from the Godot editor, levels save here.
const CUSTOM := "res://levels/custom"
const BUNDLED := "res://levels"
const ORDER_FILE := "res://levels/level_order.txt"
const VERSION := 1
const MAX_OBJECTS := 1000
const MAX_UID := 1000000000
const MAX_LEVELS := 16

static func new_level() -> Dictionary:
	return normalize({"version": VERSION, "name": "My kitchen course", "player": Catalog.DEFAULT_PLAYER, "objects": [
		Catalog.record("spawn", Vector3(-45, 0, -475)),
		Catalog.record("goal", Vector3(45, 0, -525)),
	]})

static func normalize(document: Dictionary) -> Dictionary:
	var result := document.duplicate(true)
	result.objects = result.objects.filter(func(entry: Dictionary): return entry.id != "kitchen")
	for entry in result.objects:
		if entry.has("uid"):
			entry.uid = int(entry.uid)
	for entry in result.objects:
		if not entry.has("uid"):
			entry.uid = next_uid(result)
	prune_links(result)
	return result

static func next_uid(document: Dictionary) -> int:
	var highest := 0
	for entry in document.objects:
		highest = maxi(highest, int(entry.get("uid", 0)))
	return highest + 1

static func index_of_uid(document: Dictionary, uid: int) -> int:
	for index in document.objects.size():
		if int(document.objects[index].get("uid", 0)) == uid:
			return index
	return -1

static func prune_links(document: Dictionary) -> void:
	var ids := {}
	for entry in document.objects:
		ids[int(entry.get("uid", 0))] = entry.id
	for entry in document.objects:
		if entry.has("targets"):
			var kept: Array = []
			for target in entry.targets:
				var uid := int(target.uid)
				if ids.has(uid) and not ItemTriggers.action_named(ids[uid], target.action).is_empty():
					kept.append({"uid": uid, "action": target.action, "mode": target.mode})
			if kept.is_empty():
				entry.erase("targets")
			else:
				entry.targets = kept
		if entry.has("source"):
			if ids.get(int(entry.source)) == "scale":
				entry.source = int(entry.source)
			else:
				entry.erase("source")

static func _whole_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= 1 and value <= MAX_UID

static func _validate_links(value: Dictionary) -> String:
	var ids := {}
	for entry in value.objects:
		if entry.has("uid"):
			if not _whole_number(entry.uid):
				return "An object has an invalid id."
			if ids.has(int(entry.uid)):
				return "Two objects share the same id."
			ids[int(entry.uid)] = entry.id
	for entry in value.objects:
		if (entry.has("targets") or entry.has("source")) and entry.id != "watcher":
			return "Only event watchers can link to other objects."
		if entry.has("source") and not _whole_number(entry.source):
			return "An event watcher has an invalid scale link."
		if not entry.has("targets"):
			continue
		if not entry.targets is Array or entry.targets.size() > ItemTriggers.MAX_TARGETS:
			return "An event watcher can have at most %d targets." % ItemTriggers.MAX_TARGETS
		for target in entry.targets:
			if not target is Dictionary or not _whole_number(target.get("uid")) or not target.get("action") is String or not ItemTriggers.mode_valid(target.get("mode")):
				return "An event watcher has an invalid target."
			var uid := int(target.uid)
			if ids.has(uid) and ItemTriggers.action_named(ids[uid], target.action).is_empty():
				return "An event watcher targets an action its object doesn't have."
	return ""

static func validate(value: Variant) -> String:
	if not value is Dictionary:
		return "This file is not a level."
	if value.get("version") != VERSION:
		return "This level uses an unsupported save version."
	if not value.get("name") is String or value.name.strip_edges().is_empty() or value.name.length() > 80:
		return "Give the level a name (1–80 characters)."
	if value.has("player") and not (value.player is String and Catalog.PLAYERS.has(value.player)):
		return "This level uses an unknown player character."
	if value.has("mode") and not (value.mode is String and Catalog.MODES.has(value.mode)):
		return "This level uses an unknown game mode."
	if not value.get("objects") is Array or value.objects.size() > MAX_OBJECTS:
		return "A level can contain at most %d objects." % MAX_OBJECTS
	for entry in value.objects:
		if not entry is Dictionary or not entry.get("id") is String or not Catalog.ITEMS.has(entry.id):
			return "This level contains an unknown object."
		for key in ["position", "rotation", "scale"]:
			var components: Variant = entry.get(key)
			if not components is Array or components.size() != 3:
				return "An object has an invalid transform."
			for component in components:
				if not (component is float or component is int):
					return "An object has an invalid transform."
				if not is_finite(float(component)) or absf(float(component)) > 10000:
					return "An object is outside the supported world bounds."
				if key == "scale" and (component < 0.05 or component > 100):
					return "Object scale must be between 0.05 and 100."
		if entry.has("properties"):
			var problem := ItemProperties.validate(entry.id, entry.properties)
			if not problem.is_empty():
				return problem
		if entry.has("colour"):
			var problem := ItemColours.validate(entry.id, entry.colour)
			if not problem.is_empty():
				return problem
	return _validate_links(value)

static func playable_error(document: Dictionary) -> String:
	var starts := 0
	var finishes := 0
	var npcs := 0
	for entry in document.objects:
		starts += int(entry.id == "spawn")
		finishes += int(entry.id == "goal")
		npcs += int(entry.id == "npc")
	if starts != 1:
		return "Place exactly one Player start before playing."
	if Catalog.mode_of(document) == "ffa":
		return "" if npcs > 0 else "Place at least one NPC spawner to fight in a free for all."
	if finishes == 0:
		return "Place a Finish area before playing."
	if not _finish_can_open(document):
		return "Every Finish area starts closed. Open one at start or have an Event watcher open it."
	return ""

static func _finish_can_open(document: Dictionary) -> bool:
	var opened := {}
	for entry in document.objects:
		for target in entry.get("targets", []):
			if target.action == "enabled" and target.mode != "off":
				opened[int(target.uid)] = true
	for entry in document.objects:
		if entry.id == "goal" and (entry.get("properties", {}).get("enabled", true) or opened.has(int(entry.get("uid", 0)))):
			return true
	return false

static func valid_filename(filename: String) -> bool:
	return filename == filename.get_file() and filename.ends_with(".json") and not filename.begins_with(".")

## Where new and edited saved levels go: the repo when run from the editor.
static func saved_directory() -> String:
	return CUSTOM if can_edit_set() else DIRECTORY

## Where a level is read from: a copy on this computer, else the repo's saved
## levels, else the level list.
static func path_of(filename: String) -> String:
	for directory in [DIRECTORY, CUSTOM, BUNDLED]:
		if FileAccess.file_exists(directory.path_join(filename)):
			return directory.path_join(filename)
	return saved_directory().path_join(filename)

static func is_bundled(filename: String) -> bool:
	return path_of(filename).get_base_dir() == BUNDLED

static func read_level(filename: String) -> Dictionary:
	if not valid_filename(filename):
		return {"error": "Invalid level filename."}
	var file := FileAccess.open(path_of(filename), FileAccess.READ)
	if file == null:
		return {"error": "Could not open the saved level (%s)." % error_string(FileAccess.get_open_error())}
	if file.get_length() > 4 * 1024 * 1024:
		return {"error": "The level file is too large."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"error": "The level file is damaged: %s" % parser.get_error_message()}
	var problem := validate(parser.data)
	if not problem.is_empty():
		return {"error": problem}
	return {"document": normalize(parser.data)}

static func save_level(document: Dictionary, filename: String = "") -> Dictionary:
	var problem := validate(document)
	if not problem.is_empty():
		return {"error": problem}
	if filename.is_empty():
		filename = "level_%s_%s.json" % [str(Time.get_unix_time_from_system()).replace(".", "_"), str(randi())]
	if not valid_filename(filename):
		return {"error": "Invalid level filename."}
	var result := _write_level(BUNDLED if is_bundled(filename) and can_edit_set() else saved_directory(), document, filename)
	if not result.has("error") and can_edit_set():
		_forget_local_copy(filename)
	return result

## Run from the editor, a level saved into the repo replaces this computer's copy.
static func _forget_local_copy(filename: String) -> void:
	if FileAccess.file_exists(DIRECTORY.path_join(filename)):
		DirAccess.remove_absolute(DIRECTORY.path_join(filename))

static func _write_level(directory: String, document: Dictionary, filename: String) -> Dictionary:
	var result := DirAccess.make_dir_recursive_absolute(directory)
	if result != OK:
		return {"error": "Could not create the save folder: %s" % error_string(result)}
	var destination := directory.path_join(filename)
	var temporary := destination + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"error": "Could not write the save: %s" % error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(normalize(document), "\t"))
	file.flush()
	result = file.get_error()
	file.close()
	if result != OK:
		return {"error": "Could not finish writing the save: %s" % error_string(result)}
	result = DirAccess.rename_absolute(temporary, destination)
	if result != OK:
		return {"error": "Could not replace the save: %s" % error_string(result)}
	return {"filename": filename}

## A level list entry can also be a hand-built scene, written in level_order.txt as its
## res:// path (for example res://scenes/levels/movement_tutorial.tscn).
static func is_scene(entry: String) -> bool:
	return entry.begins_with("res://") and entry.ends_with(".tscn")

## The name shown for a level list entry.
static func entry_name(entry: String) -> String:
	if is_scene(entry):
		return entry.get_file().get_basename().capitalize()
	var result := read_level(entry)
	return result.document.name if result.has("document") else result.error

static func level_set() -> Array[String]:
	var order: Array[String] = []
	if not DirAccess.dir_exists_absolute(BUNDLED):
		return order
	var present := Array(DirAccess.get_files_at(BUNDLED)).filter(func(filename: String): return valid_filename(filename))
	if FileAccess.file_exists(ORDER_FILE):
		for line in FileAccess.get_file_as_string(ORDER_FILE).split("\n"):
			var filename := line.strip_edges()
			if (filename in present or is_scene(filename) and ResourceLoader.exists(filename)) and not filename in order:
				order.append(filename)
	present.sort()
	for filename: String in present:
		if not filename in order:
			order.append(filename)
	return order

static func can_edit_set() -> bool:
	return OS.has_feature("editor")

static func add_to_set(filename: String) -> Dictionary:
	if not can_edit_set():
		return {"error": "Run the game from the Godot editor to change the level list."}
	if is_bundled(filename):
		return {"error": "This level is already in the level list."}
	if level_set().size() >= MAX_LEVELS:
		return {"error": "The Play menu supports %d levels. Remove a level from the list before adding another." % MAX_LEVELS}
	var result := read_level(filename)
	if result.has("error"):
		return result
	var problem := playable_error(result.document)
	if not problem.is_empty():
		return {"error": problem + " Finish it before adding it to the level list."}
	var stem: String = result.document.name.to_snake_case().validate_filename().replace(" ", "_")
	stem = stem.lstrip("._") if not stem.lstrip("._").is_empty() else "level"
	var exported := stem + ".json"
	var copy := 2
	while FileAccess.file_exists(BUNDLED.path_join(exported)) or exported != filename and (FileAccess.file_exists(CUSTOM.path_join(exported)) or FileAccess.file_exists(DIRECTORY.path_join(exported))):
		exported = "%s_%d.json" % [stem, copy]
		copy += 1
	var source := path_of(filename)
	DirAccess.make_dir_recursive_absolute(BUNDLED)
	var file := FileAccess.open(BUNDLED.path_join(exported), FileAccess.WRITE)
	if file == null:
		return {"error": "Could not write into the level set: %s" % error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(result.document, "\t"))
	file.close()
	var order := level_set()
	order.erase(exported)
	order.append(exported)
	var written := _write_order(order)
	if not written.is_empty():
		return {"error": written}
	DirAccess.remove_absolute(source)
	_forget_local_copy(filename)
	return {"filename": exported, "number": order.size()}

static func remove_from_set(filename: String) -> Dictionary:
	if not can_edit_set():
		return {"error": "Run the game from the Godot editor to change the level list."}
	if not is_bundled(filename):
		return {"error": "This level isn't in the level list."}
	var result := read_level(filename)
	if result.has("error"):
		return result
	var kept := filename
	var copy := 2
	while FileAccess.file_exists(CUSTOM.path_join(kept)) or FileAccess.file_exists(DIRECTORY.path_join(kept)):
		kept = "%s_%d.json" % [filename.get_basename(), copy]
		copy += 1
	var saved := _write_level(saved_directory(), result.document, kept)
	if saved.has("error"):
		return saved
	var order := level_set()
	order.erase(filename)
	var removed := DirAccess.remove_absolute(BUNDLED.path_join(filename))
	if removed != OK:
		return {"error": "Could not remove the level from levels/: %s" % error_string(removed)}
	var written := _write_order(order)
	return {"error": written} if not written.is_empty() else {"filename": kept}

static func move_in_set(filename: String, offset: int) -> Dictionary:
	if not can_edit_set():
		return {"error": "Run the game from the Godot editor to change the level list."}
	var order := level_set()
	var index := order.find(filename)
	var target := index + offset
	if index < 0 or target < 0 or target >= order.size():
		return {"error": "That level can't move any further."}
	order.remove_at(index)
	order.insert(target, filename)
	var written := _write_order(order)
	return {"error": written} if not written.is_empty() else {"number": target + 1}

static func _write_order(order: Array[String]) -> String:
	var file := FileAccess.open(ORDER_FILE, FileAccess.WRITE)
	if file == null:
		return "Could not write the level order: %s" % error_string(FileAccess.get_open_error())
	file.store_string("\n".join(order) + "\n")
	file.close()
	return ""

static func list_levels() -> Array:
	var levels: Array = []
	var filenames: Array[String] = level_set()
	for directory in [CUSTOM, DIRECTORY]:
		if DirAccess.dir_exists_absolute(directory):
			for filename: String in DirAccess.get_files_at(directory):
				if not filename in filenames:
					filenames.append(filename)
	for filename: String in filenames:
		if not valid_filename(filename):
			continue
		var result := read_level(filename)
		if result.has("error"):
			levels.append({"filename": filename, "name": filename, "error": result.error})
		else:
			levels.append({"filename": filename, "name": result.document.name,
				"error": playable_error(result.document)})
	var in_set := level_set()
	for entry in levels:
		entry.number = in_set.find(entry.filename) + 1
	levels.sort_custom(func(a: Dictionary, b: Dictionary):
		if (a.number > 0) != (b.number > 0) or a.number > 0:
			return a.number > 0 and (b.number == 0 or a.number < b.number)
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	return levels

static func delete_level(filename: String) -> Dictionary:
	if not valid_filename(filename):
		return {"error": "Invalid level filename."}
	if is_bundled(filename):
		return {"error": "This level is in the level list. Remove it from the list first."}
	var result := DirAccess.remove_absolute(path_of(filename))
	if result != OK:
		return {"error": "Could not delete the saved level: %s" % error_string(result)}
	_forget_local_copy(filename)
	return {"filename": filename}

static func launch(tree: SceneTree, document: Dictionary, filename: String, editing: bool) -> Error:
	tree.set_meta("custom_level_launch", {"document": document.duplicate(true), "filename": filename, "editing": editing})
	return tree.change_scene_to_file("res://scenes/level_builder.tscn" if editing else "res://scenes/custom_level.tscn")

extends RefCounted
const Catalog = preload("res://scripts/level_editor/catalog.gd")
const DIRECTORY := "user://levels"
const VERSION := 1
const MAX_OBJECTS := 1000

static func new_level() -> Dictionary:
	var objects: Array = []
	for x in range(-1, 2):
		for z in range(-1, 2):
			objects.append(Catalog.record("counter", Vector3(x * 8, 0, z * 8)))
	objects.append(Catalog.record("spawn", Vector3(0, 0, 8)))
	objects.append(Catalog.record("goal", Vector3(0, 0, -8)))
	return {"version": VERSION, "name": "My kitchen course", "objects": objects}

static func validate(value: Variant) -> String:
	if not value is Dictionary:
		return "This file is not a level."
	if value.get("version") != VERSION:
		return "This level uses an unsupported save version."
	if not value.get("name") is String or value.name.strip_edges().is_empty() or value.name.length() > 80:
		return "Give the level a name (1–80 characters)."
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
	return ""

static func playable_error(document: Dictionary) -> String:
	var starts := 0
	var finishes := 0
	for entry in document.objects:
		starts += int(entry.id == "spawn")
		finishes += int(entry.id in ["goal", "pot"])
	if starts != 1:
		return "Place exactly one Player start before playing."
	if finishes == 0:
		return "Place a Finish flag or Finish pot before playing."
	return ""

static func valid_filename(filename: String) -> bool:
	return filename == filename.get_file() and filename.ends_with(".json") and not filename.begins_with(".")

static func read_level(filename: String) -> Dictionary:
	if not valid_filename(filename):
		return {"error": "Invalid level filename."}
	var file := FileAccess.open(DIRECTORY.path_join(filename), FileAccess.READ)
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
	return {"document": parser.data}

static func save_level(document: Dictionary, filename: String = "") -> Dictionary:
	var problem := validate(document)
	if not problem.is_empty():
		return {"error": problem}
	var result := DirAccess.make_dir_recursive_absolute(DIRECTORY)
	if result != OK:
		return {"error": "Could not create the save folder: %s" % error_string(result)}
	if filename.is_empty():
		filename = "level_%s_%s.json" % [str(Time.get_unix_time_from_system()).replace(".", "_"), str(randi())]
	if not valid_filename(filename):
		return {"error": "Invalid level filename."}
	var destination := DIRECTORY.path_join(filename)
	var temporary := destination + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"error": "Could not write the save: %s" % error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(document, "\t"))
	file.flush()
	result = file.get_error()
	file.close()
	if result != OK:
		return {"error": "Could not finish writing the save: %s" % error_string(result)}
	# Rename only after the complete document is on disk, preserving the old save on write failure.
	result = DirAccess.rename_absolute(temporary, destination)
	if result != OK:
		return {"error": "Could not replace the save: %s" % error_string(result)}
	return {"filename": filename}

static func list_levels() -> Array:
	var levels: Array = []
	if not DirAccess.dir_exists_absolute(DIRECTORY):
		return levels
	for filename in DirAccess.get_files_at(DIRECTORY):
		if not valid_filename(filename):
			continue
		var result := read_level(filename)
		if result.has("error"):
			levels.append({"filename": filename, "name": filename, "error": result.error})
		else:
			levels.append({"filename": filename, "name": result.document.name,
				"error": playable_error(result.document)})
	levels.sort_custom(func(a: Dictionary, b: Dictionary): return a.name.naturalnocasecmp_to(b.name) < 0)
	return levels

static func launch(tree: SceneTree, document: Dictionary, filename: String, editing: bool) -> Error:
	tree.set_meta("custom_level_launch", {"document": document.duplicate(true), "filename": filename, "editing": editing})
	return tree.change_scene_to_file("res://scenes/level_builder.tscn" if editing else "res://scenes/custom_level.tscn")

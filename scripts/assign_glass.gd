@tool
extends EditorScript

## Assigns glass materials to bottles by FINDING the glass surface rather
## than assuming an index, then writing a per-node surface override.
##
## Usage: open the bar scene, focus this script, press Ctrl+Shift+X.
## The script does not save for you. Press Ctrl+S afterwards.

const MAT_DIR := "res://assets/models/props/glass/"

## Substring identifying the GLASS surface by its baked material.
const GLASS_TAG := "M_Glass_Clear"

## Bottle node name -> variant file name. This dictionary is the single
## source of truth for the palette. Edit colours here, not in the scene.
const ASSIGNMENTS := {
	"Bottle_Beer_Tallie":  "MI_Glass_Amber.tres",
	"Bottle_Brandy":       "MI_Glass_Brown_Dark.tres",
	"Bottle_Cognac":       "MI_Glass_Amber.tres",
	"Bottle_Gin":          "MI_Glass_Flint.tres",
	"Bottle_Mix":          "MI_Glass_Aqua.tres",
	"Bottle_Moonshine":    "MI_Glass_Flint.tres",
	"Bottle_Rum":          "MI_Glass_Ink.tres",
	"Bottle_Sparkling":    "MI_Glass_Green_Antique.tres",
	"Bottle_Sphere":       "MI_Glass_Cobalt.tres",
	"Bottle_Spirit":       "MI_Glass_Frost.tres",
	"Bottle_Tanqueray":    "MI_Glass_Green_Georgia.tres",
	"Bottle_Vodka":        "MI_Glass_Flint.tres",
	"Bottle_Whiskey":      "MI_Glass_Amber.tres",
	"Bottle_Beer_Bottle":  "MI_Glass_Amber.tres",
	"Bottle_Cooking_Wine": "MI_Glass_Green_Antique.tres",
	"Bottle_Medicine":     "MI_Glass_Cobalt.tres",
	"Bottle_Oil":          "MI_Glass_Green_Georgia.tres",
	"Bottle_Oil_2":        "MI_Glass_Flint.tres",
}


func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("No scene open.")
		return

	var done := 0
	var missed := 0

	for bottle_name in ASSIGNMENTS:
		var bottle := root.find_child(bottle_name, true, false)
		if bottle == null:
			print("  not in scene: ", bottle_name)
			continue

		var mat_path: String = MAT_DIR + ASSIGNMENTS[bottle_name]
		if not ResourceLoader.exists(mat_path):
			push_error("Material missing: " + mat_path)
			continue
		var mat: Material = load(mat_path)

		for mi in _mesh_instances(bottle):
			var idx := _glass_surface(mi)
			if idx < 0:
				print("  no glass surface found on ", mi.name,
					  " under ", bottle_name)
				missed += 1
				continue

			# A node whose mesh was dragged in directly can have an empty
			# override array that does not match its mesh. Reassigning the
			# mesh forces the node to resize it.
			if mi.get_surface_override_material_count() <= idx:
				mi.mesh = mi.mesh

			if mi.get_surface_override_material_count() <= idx:
				var slots := mi.get_surface_override_material_count()
				push_error("Override array too small on %s: %d slots, need %d. Reassign its mesh by hand." % [mi.name, slots, idx + 1])
				missed += 1
				continue

			mi.set_surface_override_material(idx, mat)
			print("  %-22s surface %d -> %s"
				  % [bottle_name, idx, ASSIGNMENTS[bottle_name]])
			done += 1

	print("-".repeat(50))
	print("assigned %d, could not resolve %d" % [done, missed])
	print("Save the scene to keep these changes.")


func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_mesh_instances(c))
	return out


## Returns the surface index whose baked material is the glass one, or -1.
func _glass_surface(mi: MeshInstance3D) -> int:
	if mi.mesh == null:
		return -1

	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m == null:
			continue
		if m.resource_path.contains(GLASS_TAG) \
		   or m.resource_name.contains(GLASS_TAG):
			return i

	# A single-surface mesh can only be the glass.
	if mi.mesh.get_surface_count() == 1:
		return 0

	return -1
